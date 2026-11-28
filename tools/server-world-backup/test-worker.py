"""Exercise the actual worker with local fixture worlds and a fake RCON server."""
import json
import socket
import socketserver
import struct
import subprocess
import threading
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
WORK = HERE.parents[1] / 'outputs' / 'server-world-backup' / ('fixture-' + str(time.time_ns()))
WORK.mkdir(parents=True)
server_root = WORK / 'server'
world = server_root / 'world'
world.mkdir(parents=True)
(world / 'level.dat').write_bytes(b'NEW WORLD')
(world / 'region').mkdir()
(world / 'region/r.0.0.mca').write_bytes(b'fixture region' * 100)
(world / 'session.lock').write_bytes(b'not backed up')
dest = WORK / 'backup'
(dest / 'world').mkdir(parents=True)
(dest / 'world/level.dat').write_bytes(b'OLD WORLD')
(dest / 'world/old-file').write_bytes(b'stale')
commands = []
saving = True
bad_flush = False


def exact(sock, n):
    data = b''
    while len(data) < n:
        part = sock.recv(n-len(data))
        if not part:
            raise EOFError()
        data += part
    return data


def recv(sock):
    n, = struct.unpack('<i', exact(sock, 4))
    b = exact(sock, n)
    ident, kind = struct.unpack('<ii', b[:8])
    return ident, kind, b[8:-2].decode()


def send(sock, ident, kind, msg):
    b = struct.pack('<ii', ident, kind) + msg.encode() + b'\0\0'
    data = struct.pack('<i', len(b)) + b
    # Exercise ReadExact against fragmented transport.
    for off in range(0, len(data), 7):
        sock.sendall(data[off:off+7])


class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        global saving
        self.request.settimeout(10)
        ident, kind, password = recv(self.request)
        assert kind == 3 and password == 'test:password'
        send(self.request, ident, 2, '')
        ident, kind, cmd = recv(self.request)
        assert kind == 2
        commands.append(cmd)
        if cmd == 'save-off':
            saving = False
            reply = 'Automatic saving is now disabled'
        elif cmd == 'save-on':
            saving = True
            reply = 'Automatic saving is now enabled'
        elif cmd == 'save-all flush':
            reply = 'unexpected failure' if bad_flush else 'Saving the game\nSaved the game'
        else:
            raise AssertionError(cmd)
        send(self.request, ident, 0, reply)


probe = WORK / 'probe.ps1'
probe.write_text('''param([string]$Action)
$n=0;$p=Join-Path $PSScriptRoot 'counter.txt'
if(Test-Path $p){$n=[int](Get-Content $p)}
$n++;[IO.File]::WriteAllText($p,[string]$n)
$id='1:created'
if((Test-Path (Join-Path $PSScriptRoot 'change-identity')) -and $n -ge 2){$id='2:created'}
@{Kind='Alive';Identity=$id;ProcessId=1;Reason='fixture'}|ConvertTo-Json
''')


def run(ok=True, action='Run'):
    (WORK / 'counter.txt').write_text('0')
    r = subprocess.run(['powershell', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass',
                        '-File', str(HERE / 'backup.ps1'), '-ConfigPath', str(WORK / 'config.json'), '-Action', action],
                       capture_output=True, text=True, timeout=80)
    assert (r.returncode == 0) == ok, (r.stdout, r.stderr)
    return r


with socketserver.TCPServer(('127.0.0.1', 0), Handler) as fake:
    threading.Thread(target=fake.serve_forever, daemon=True).start()
    port = fake.server_address[1]
    (server_root / 'server.properties').write_text(f'enable-rcon=true\nrcon.port={port}\nrcon.password=test\\:password\nlevel-name=world\n')
    config = json.loads((HERE / 'config.example.json').read_text())
    config.update(ServerRoot=str(server_root), BackupRoot=str(dest), WatchdogScript=str(probe),
                  RconTimeoutSeconds=3, FreeSpaceReserveBytes=1, UseVss=False)
    (WORK / 'config.json').write_text(json.dumps(config))
    run()
    assert saving and commands == ['save-off', 'save-all flush', 'save-on']
    assert (dest / 'world/level.dat').read_bytes() == b'NEW WORLD'
    assert not (dest / 'world/old-file').exists()
    assert not (dest / 'world/session.lock').exists()
    assert not (dest / 'world.previous').exists()
    summary = json.loads((dest / 'latest.json').read_text())
    assert summary['files'] == 2 and summary['sha256Verified'] and summary['autosaveRestored']
    print('PASS: real robocopy, fragmented RCON, escaped password, flush/restore, SHA256, overwrite, session.lock excluded')
    commands.clear()
    (world / 'level.dat').write_bytes(b'CHANGED WORLD')
    (WORK / 'change-identity').touch()
    run(False)
    assert saving and commands[-1] == 'save-on'
    assert (dest / 'world/level.dat').read_bytes() == b'NEW WORLD'
    assert not (WORK / 'restore-required.json').exists()
    print('PASS: process identity change rejects new copy, preserves previous and restores saving')
    (WORK / 'change-identity').unlink()
    bad_flush = True
    commands.clear()
    run(False)
    assert saving and commands == ['save-off', 'save-all flush', 'save-on']
    assert (dest / 'world/level.dat').read_bytes() == b'NEW WORLD'
    print('PASS: flush failure still restores saving and preserves previous')
    commands.clear()
    run(action='Recover')
    assert commands == []
    (WORK / 'restore-required.json').write_text('{}')
    saving = False
    run(action='Recover')
    assert saving and commands == ['save-on'] and not (WORK / 'restore-required.json').exists()
    print('PASS: recovery only acts on a durable save-on marker, never starts a backup')
    fake.shutdown()
print('Evidence:', WORK)

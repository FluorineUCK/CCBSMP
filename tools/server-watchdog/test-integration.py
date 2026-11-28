"""Real detached Java process tests; uses isolated fixture folders, never Minecraft."""
import json
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = Path(__file__).with_name('watchdog.ps1')
WORK = ROOT / 'outputs' / 'server-watchdog' / ('fixture-' + str(time.time_ns()))
WORK.mkdir(parents=True)
JAVA = Path('C:/Program Files/Java/jdk-21.0.11/bin/java.exe')
CFG = WORK / 'config.json'
STATE = WORK / 'state.json'
created_pids = set()


def ps(command):
    r = subprocess.run(['powershell', '-NoProfile', '-NonInteractive', '-ExecutionPolicy',
                        'Bypass', '-Command', command], capture_output=True, text=True, timeout=40)
    if r.returncode:
        raise RuntimeError(r.stdout + r.stderr)
    return r.stdout


def run(action, ok=True):
    r = subprocess.run(['powershell', '-NoProfile', '-NonInteractive', '-ExecutionPolicy',
                        'Bypass', '-File', str(SCRIPT), '-ConfigPath', str(CFG), '-Action', action],
                       capture_output=True, text=True, timeout=40)
    assert (r.returncode == 0) == ok, (action, r.stdout, r.stderr)
    return r.stdout


def state():
    return json.loads(STATE.read_text(encoding='utf-8-sig'))


def count_starts():
    f = WORK / 'watchdog.jsonl'
    return sum(json.loads(x)['event'] == 'launched' for x in f.read_text().splitlines())


def wait_start(previous):
    deadline = time.monotonic() + 25
    while time.monotonic() < deadline:
        s = state()
        a = s['Attempt']
        if a and a['Identity'] and count_starts() > previous:
            pid = int(a['Identity'].split(':')[0])
            created_pids.add(pid)
            return pid
        time.sleep(.3)
    raise AssertionError('Detached launcher did not start: ' + (WORK / 'watchdog.jsonl').read_text())


def stop_fixture(pid):
    # Check both executable and fixture root before terminating our test process.
    literal = str(WORK).replace("'", "''")
    ps("$p=Get-CimInstance Win32_Process -Filter 'ProcessId=%d'; " % pid +
       "if($p -and $p.Name -eq 'java.exe' -and $p.CommandLine.Contains('%s'))" % literal +
       " {Stop-Process -Id %d -Force -ErrorAction Stop}" % pid)


try:
    (WORK / 'Harness.java').write_text('public class Harness { public static void main(String[] a) throws Exception { Thread.sleep(120000); } }')
    subprocess.run([str(JAVA.with_name('javac.exe')), str(WORK / 'Harness.java')], check=True)
    (WORK / 'jvm.args').write_text('-Xms16m\n-Xmx32m\n')
    (WORK / 'fixture.args').write_text('-cp\n"' + WORK.as_posix() + '"\nHarness\n')
    config = json.loads(SCRIPT.with_name('config.example.json').read_text())
    config.update(ServerRoot=str(WORK), JavaExe=str(JAVA), JvmArgsFile='jvm.args',
                  ForgeArgsFile='fixture.args', GamePort=54983, SuccessSeconds=4,
                  LaunchGraceSeconds=15)
    CFG.write_text(json.dumps(config))
    run('Initialize'); run('Check')
    assert state()['Paused'] and count_starts() == 0
    run('Resume'); run('Check')
    pid = wait_start(0)
    time.sleep(5)
    run('Check')
    assert state()['Attempt'] is None and count_starts() == 1
    run('Check')
    assert count_starts() == 1
    print('PASS: detached process survives checker exit; healthy process is not duplicated; success clears attempt')
    stop_fixture(pid)
    run('Check')
    pid = wait_start(1)
    for failures in (1, 2, 3):
        stop_fixture(pid)
        run('Check')
        assert len(state()['Failures']) == failures
        if failures < 3:
            pid = wait_start(1 + failures)
    assert state()['Latched'] and count_starts() == 4
    run('Check'); run('Resume'); run('Check')
    assert state()['Latched'] and count_starts() == 4
    print('PASS: three actual early process exits latch; later checks and Resume do not unlock')
    run('Pause'); run('Reset'); run('Check')
    assert state()['Paused'] and not state()['Latched'] and count_starts() == 4
    run('Resume'); run('Check'); pid = wait_start(4)
    run('Pause'); stop_fixture(pid); run('Check')
    assert count_starts() == 5
    print('PASS: explicit Reset clears latch; Pause prevents restart during maintenance')
    STATE.write_text('{corrupted')
    run('Check', ok=False)
    assert count_starts() == 5
    print('PASS: corrupted state fails closed')
    (WORK / 'result.txt').write_text('PASS\n')
    print('Evidence:', WORK)
finally:
    for pid in created_pids:
        stop_fixture(pid)

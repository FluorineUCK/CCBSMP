"""Run only in a disposable, pre-staged smoke directory; never uses an existing world."""
import argparse
import pathlib
import subprocess
import time

p = argparse.ArgumentParser()
p.add_argument('--java', required=True)
p.add_argument('--smoke', required=True)
p.add_argument('--libraries', required=True)
a = p.parse_args()
smoke = pathlib.Path(a.smoke).resolve()
log_path = smoke.parent / 'smoke-console.log'
with log_path.open('w', encoding='utf-8') as log:
    process = subprocess.Popen(
        [a.java, '-Xms512m', '-Xmx2g', '-DlibraryDirectory=' + str(pathlib.Path(a.libraries).resolve()), '@args.txt', 'nogui'],
        cwd=smoke, stdout=log, stderr=subprocess.STDOUT, stdin=subprocess.PIPE,
        creationflags=subprocess.CREATE_NO_WINDOW)
    try:
        for _ in range(180):
            time.sleep(1)
            text = log_path.read_text(encoding='utf-8', errors='replace')
            if process.poll() is not None:
                raise RuntimeError(f'Server exited: {process.returncode}; see {log_path}')
            if 'Done (' in text:
                process.stdin.write(b'summon minecraft:zombie 0 0 0\n')
                process.stdin.flush()
                time.sleep(5)
                process.stdin.write(b'stop\n')
                process.stdin.flush()
                process.wait(timeout=60)
                text = log_path.read_text(encoding='utf-8', errors='replace')
                assert 'Patched class: dev/leo/sableplayerragdoll/mob/MobRagdollSourceRecovery' in text
                assert 'Summoned new' in text
                assert process.returncode == 0
                print('PASS: real NeoForge launch, Hotai patched target, zombie summon, clean shutdown')
                break
        else:
            raise RuntimeError('Startup timeout')
    finally:
        if process.poll() is None:
            process.terminate()
            process.wait(timeout=30)

"""Build and regression-test the version-locked patch using local JDK/ASM/Hotai."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess

p = argparse.ArgumentParser()
p.add_argument('--jdk', type=Path, required=True)
p.add_argument('--mod', type=Path, required=True)
p.add_argument('--hotai', type=Path, required=True)
p.add_argument('--asm-dir', type=Path, required=True, help='org/ow2/asm directory containing ASM 9.10.1')
p.add_argument('--out', type=Path, required=True)
a = p.parse_args()
a.out.mkdir(parents=True, exist_ok=True)
cp = os.pathsep.join(str(f.resolve()) for f in [*sorted(a.asm_dir.rglob('*9.10.1.jar')), a.hotai])
source = Path(__file__).resolve().parent
subprocess.run([str(a.jdk/'bin/javac.exe'), '-cp', cp, '-d', str(a.out),
                str(source/'PatchRecovery.java'), str(source/'TestRecovery.java')], check=True)
java = [str(a.jdk/'bin/java.exe'), '-Xverify:all', '-cp', str(a.out.resolve()) + os.pathsep + cp]
red = subprocess.run(java + ['TestRecovery', str(a.mod)], capture_output=True, text=True)
assert red.returncode != 0 and 'clock=1, compounds=1' in red.stderr, red.stdout + red.stderr
print('PASS: original bytecode reproduces redundant clock and compound lookup')
subprocess.run(java + ['PatchRecovery', str(a.mod), str(a.out)], check=True)
subprocess.run(java + ['TestRecovery', str(a.mod), str(a.out/'patched.class')], check=True)
patch = next((a.out/'hotai').rglob('*.badiff'))
record = {'target_mod_id': 'sable_player_ragdoll', 'version': '0.8.1',
          'target_jar_sha256': hashlib.sha256(a.mod.read_bytes()).hexdigest(),
          'patch_sha256': hashlib.sha256(patch.read_bytes()).hexdigest(),
          'side': 'both', 'differential_states': 2880, 'overloads': 2}
(a.out/'build-record.json').write_text(json.dumps(record, indent=2)+'\n')

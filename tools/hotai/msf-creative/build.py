"""Version-locked offline build; does not install into any running instance."""
import argparse
import os
from pathlib import Path
import subprocess
import zipfile

p=argparse.ArgumentParser()
p.add_argument('--jdk',type=Path,required=True)
p.add_argument('--mod',type=Path,required=True)
p.add_argument('--hotai',type=Path,required=True)
p.add_argument('--asm-dir',type=Path,required=True)
p.add_argument('--out',type=Path,required=True)
a=p.parse_args()
a.out.mkdir(parents=True,exist_ok=True)
cp=os.pathsep.join(str(f.resolve()) for f in [*sorted(a.asm_dir.rglob('*9.10.1.jar')),a.hotai])
source=Path(__file__).resolve().parent
subprocess.run([str(a.jdk/'bin/javac.exe'),'-cp',cp,'-d',str(a.out),str(source/'TestSlots.java'),str(source/'PatchSlots.java')],check=True)
java=[str(a.jdk/'bin/java.exe'),'-Xverify:all','-cp',str(a.out.resolve())+os.pathsep+cp]
red=subprocess.run(java+['TestSlots',str(a.mod)],capture_output=True,text=True)
assert red.returncode!=0 and 'server=48, wrappers=46, client including trash=47' in red.stderr,red.stdout+red.stderr
print('PASS: original bytecode reproduces truncated inventory',flush=True)
subprocess.run(java+['PatchSlots',str(a.mod),str(a.out)],check=True)
with zipfile.ZipFile(a.out/'msf-creative-slots-6.8-hotai.zip','w',zipfile.ZIP_DEFLATED) as z:
    for patch in (a.out/'hotai').rglob('*.badiff'):z.write(patch,patch.relative_to(a.out).as_posix())

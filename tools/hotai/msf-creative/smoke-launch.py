import pathlib,json,subprocess,uuid,re
root=pathlib.Path('D:/CCBSMP');game=root/'run/versions/CCBSMP Test';out=root/'outputs/hotai-msf-creative';smoke=out/'smoke';d=json.loads((game/'CCBSMP Preliminary.json').read_text(encoding='utf-8-sig'))
def allowed(rules):
 if not rules:return True
 result=False
 for r in rules:
  osrule=r.get('os',{});match=osrule.get('name','windows')=='windows' and osrule.get('arch','x86_64') in ('x86_64','amd64') and not any(r.get('features',{}).values())
  if match:result=r['action']=='allow'
 return result
libs=[]
for l in d['libraries']:
 if not allowed(l.get('rules',[])):continue
 a=l.get('downloads',{}).get('artifact')
 if a:
  p=root/'run/libraries'/a['path'];assert p.exists(),p;libs.append(str(p))
libs=list(dict.fromkeys(libs))
libs.append(str(game/'CCBSMP Preliminary.jar'))
values={'auth_player_name':'CCBSMPPatchTest','version_name':d['id'],'game_directory':str(smoke),'assets_root':str(root/'run/assets'),'assets_index_name':d['assetIndex']['id'],'auth_uuid':str(uuid.uuid3(uuid.NAMESPACE_DNS,'CCBSMPPatchTest')).replace('-',''),'auth_access_token':'0','clientid':'0','auth_xuid':'0','user_type':'legacy','version_type':'release','natives_directory':str(game/'CCBSMP Preliminary-natives'),'launcher_name':'CCBSMP-patch-smoke','launcher_version':'1','classpath':';'.join(libs),'library_directory':str(root/'run/libraries'),'classpath_separator':';'}
def args(items):
 result=[]
 for x in items:
  if isinstance(x,dict):
   if not allowed(x.get('rules',[])):continue
   x=x['value']
  for s in x if isinstance(x,list) else [x]:
   for k,v in values.items():s=s.replace('${'+k+'}',v)
   assert '${' not in s,s
   result.append(s)
 return result
cmd=[str(pathlib.Path('C:/Program Files/Java/jdk-21.0.11/bin/java.exe')),'-Xms512m','-Xmx6g','-Dmixin.debug.export=true']+args(d['arguments']['jvm'])+[d['mainClass']]+args(d['arguments']['game'])+['--width','960','--height','600']
with (out/'smoke-console.log').open('w',encoding='utf-8') as log:
 p=subprocess.Popen(cmd,cwd=smoke,stdout=log,stderr=subprocess.STDOUT,creationflags=subprocess.CREATE_NO_WINDOW)
 (out/'smoke-session.json').write_text(json.dumps({'pid':p.pid,'game_dir':str(smoke),'original_game_dir':str(game),'world':None},indent=2),encoding='utf-8');print('CLIENT PID',p.pid,flush=True);
 import time
 try:
  for _ in range(150):
   time.sleep(1)
   text=(out/'smoke-console.log').read_text(encoding='utf-8',errors='replace')
   if p.poll() is not None: raise RuntimeError('Client exited before verification: '+str(p.returncode))
   if 'Patched class: net/abraxator/moresnifferflowers/mixins/client/CreativeInventoryScreenMixin' in text:
    time.sleep(15)
    if p.poll() is not None: raise RuntimeError('Client exited after transformation: '+str(p.returncode))
    print('PASS: Hotai transformed target mixin; process alive 15 seconds later. Not a GUI acceptance test.',flush=True)
    break
  else: raise RuntimeError('Target transformation not observed within 150 seconds')
 finally:
  if p.poll() is None:p.terminate();p.wait(timeout=30)

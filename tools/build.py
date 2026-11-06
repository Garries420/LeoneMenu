from pathlib import Path
import argparse, shutil, json, hashlib, subprocess, zipfile
parser=argparse.ArgumentParser()
parser.add_argument('--rar', action='store_true', help='also build the public WinRAR release asset')
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
release=json.loads((root/'release.json').read_text())
version=release['version']
stage=root/'build'/('LeoneMenu-'+version)
assert stage.resolve().is_relative_to((root/'build').resolve())
if stage.exists(): shutil.rmtree(stage)
moon=stage/'moonloader';lib=moon/'lib';assets=moon/'resource'/'Leone Menu'
lib.mkdir(parents=True,exist_ok=True);assets.mkdir(parents=True,exist_ok=True)
source=root/'input'/'lib'/'lib'
for relative in [
    'samp/events.lua','samp/raknet.lua','samp/synchronization.lua',
    'samp/events/core.lua','samp/events/bitstream_io.lua','samp/events/utils.lua','samp/events/handlers.lua','samp/events/extra_types.lua',
    'windows/message.lua','game/keys.lua',
    'fAwesome7.lua','vkeys.lua','effil.lua','libeffil.dll','dkjson.lua','vector3d.lua','sampfuncs.lua']:
    destination=lib/relative;destination.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source/relative,destination)
# Private copy of Sputnik's GUI: patched lifetime/teardown, separate DLL path.
private=lib/'leone'/'upmimgui'
shutil.copytree(root/'vendor/leone/upmimgui',private,dirs_exist_ok=True)
shutil.copy2(source/'upmimgui/cimguidx9.dll',private/'cimguidx9.dll')
shutil.copytree(root/'assets'/'skins',assets/'skins',dirs_exist_ok=True)
shutil.copytree(root/'assets'/'skin-overrides',assets/'skin-overrides',dirs_exist_ok=True)
for name in ['leone-logo.png','tshirt.png']: shutil.copy2(root/'assets'/name,assets/name)
for name in ['modloadedin.mp3','Sniperwarning.mp3']: shutil.copy2(root/'input'/name,assets/name)
(stage/'README.txt').write_text(
    f'Leone Menu V{version}\n\n'
    '1. Close GTA San Andreas.\n'
    '2. Copy the moonloader folder into the main GTA folder where gta_sa.exe is located.\n'
    '3. Merge the folders and choose Replace if Windows asks.\n'
    '4. Start SA-MP and type /leone in chat.\n\n'
    'Built on Sputnik by Kev and Futurestunt. Leone Menu by Garry.\n',
    encoding='utf-8', newline='\n')
# The packaged offline baseline is a resource; runtime saves updated data to config.
shutil.copy2(root/'github-ready'/'alliance-skins.html',assets/'alliance-skins.html')

# Detect an incomplete manual install before requiring any package libraries.
# The independent skins feed must never change the package fingerprint.
required_files={p.relative_to(moon).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in sorted(moon.rglob('*')) if p.is_file() and p!=assets/'alliance-skins.html'}
fingerprint=hashlib.sha256(json.dumps(required_files,sort_keys=True).encode()).hexdigest()
modules=sorted((root/'src').rglob('*.lua'))
text='-- LEONE_MENU_BUNDLE\n-- Leone Menu is built on Sputnik by Kev and Futurestunt. Modified by Garry.\n'
text+="package.preload['upmimgui'] = function() return require('leone.upmimgui') end\n"
for f in modules:
    name='.'.join(f.relative_to(root).with_suffix('').parts)
    text+="\npackage.preload['"+name+"'] = function()\n"+f.read_text(encoding='utf-8')+'\nend\n'
text+="\nlocal package_check = require('src.core.Package')\nlocal ready, mismatch = package_check.check({\n"
for path,digest in required_files.items():
    text+=f'    [{json.dumps(path)}] = "{digest}",\n'
text+=f'}})\nif not ready then\n    package_check.recover("{version}", "{fingerprint}", mismatch)\n    return\nend\n'
text+="return require('src.main')\n"
(moon/'LeoneMenu.lua').write_text(text,encoding='utf-8',newline='\n')
gh=root/'github-ready';shutil.copy2(moon/'LeoneMenu.lua',gh/'LeoneMenu.lua')
manifest={'version':version,'runtime':release['runtime'],'package':fingerprint,
          'url':'https://garries420.github.io/LeoneMenu/LeoneMenu.lua','sha256':hashlib.sha256((moon/'LeoneMenu.lua').read_bytes()).hexdigest()}
(gh/'leone-update.json').write_text(json.dumps(manifest,indent=2)+'\n')
(root/'dist').mkdir(exist_ok=True)
archive=root/'dist'/('LeoneMenu-'+version+'.zip')
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
    for f in sorted(stage.rglob('*')):
        if f.is_file(): z.write(f,f.relative_to(stage))
result={'modules':len(modules),'runtime_files':len(required_files)+2,'zip':str(archive),
        'bytes':archive.stat().st_size,'script_sha256':manifest['sha256']}
if args.rar:
    rar=shutil.which('rar') or r'C:\Program Files\WinRAR\Rar.exe'
    target=root/'dist'/f'Leone Menu V{version}.rar'
    pending=target.with_suffix('.pending.rar')
    pending.unlink(missing_ok=True)
    subprocess.run([rar,'a','-cfg-','-ma5','-m5','-r','-idq',str(pending),'moonloader','README.txt'],cwd=stage,check=True)
    pending.replace(target)
    result['rar']=str(target)
print(json.dumps(result,indent=2))

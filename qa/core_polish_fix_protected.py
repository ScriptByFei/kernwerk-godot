"""Protected start funcs/constants + reactor assets vs HEAD (read-only)."""
from pathlib import Path
import subprocess, re, hashlib, json
project = Path(__file__).resolve().parents[1]
functions = ['_create_start_menu','_start_game','_begin_start_sequence','_tween_menu_away','_finish_start_sequence','_fire_initial_bounce','_enter_playing','_cancel_start_sequence']
current = (project/'scripts/game/game.gd').read_text()
baseline = subprocess.check_output(['git','show','HEAD:scripts/game/game.gd'], cwd=project, text=True)
def body(text, name):
    m = re.search(r'^func '+name+r'\(.*?(?=^func |\Z)', text, re.M|re.S)
    return m.group(0).strip() if m else None
protected = {name: body(current,name)==body(baseline,name) for name in functions}
menu = (project/'scripts/ui/start_menu.gd').read_bytes()
protected['start_menu_file'] = menu == subprocess.check_output(['git','show','HEAD:scripts/ui/start_menu.gd'], cwd=project)
config = (project/'scripts/jump/jump_config.gd').read_text()
baseconfig = subprocess.check_output(['git','show','HEAD:scripts/jump/jump_config.gd'], cwd=project, text=True)
protected['start_constants'] = re.findall(r'^const START_.*$', config, re.M) == re.findall(r'^const START_.*$', baseconfig, re.M)
# Reactor assets unchanged vs HEAD
reactor = {}
for p in (project/'assets/jump/reactor_core').rglob('*'):
    if p.is_file():
        rel = str(p.relative_to(project))
        reactor[rel] = hashlib.sha256(p.read_bytes()).hexdigest() == hashlib.sha256(subprocess.check_output(['git','show',f'HEAD:{rel}'], cwd=project)).hexdigest()
protected['reactor_assets_unchanged'] = all(reactor.values())
print(json.dumps(protected, indent=2))
print('ALL_PROTECTED_PASS' if all(protected.values()) else 'PROTECTED_FAIL')

#!/usr/bin/env python3
"""Install Rove's optional, offline MLX vision runtime and pinned model."""
import argparse, json, os, pathlib, shutil, subprocess, sys

MODEL = 'mlx-community/Qwen3.5-4B-MLX-4bit'
REVISION = '32f3e8ecf65426fc3306969496342d504bfa13f3'
RUNTIME = 'mlx-vlm==0.7.11'
parser = argparse.ArgumentParser()
parser.add_argument('--root', type=pathlib.Path, default=pathlib.Path.home()/'Library/Application Support/Rove/Vision')
parser.add_argument('--python', default='3.12')
parser.add_argument('--dry-run', action='store_true')
args = parser.parse_args()
root = args.root.expanduser().resolve()
free = shutil.disk_usage(root if root.exists() else root.parent if root.parent.exists() else pathlib.Path.home()).free
print(json.dumps({'model':MODEL,'revision':REVISION,'runtime':RUNTIME,'root':str(root),'free_GiB':round(free/2**30,2)}), flush=True)
if args.dry_run: sys.exit(0)
if free < 8*2**30: sys.exit('Need at least 8 GiB free before installation, including a reserve.')
uv = shutil.which('uv')
if not uv: sys.exit('Install uv before running this setup.')
root.mkdir(parents=True, exist_ok=True)
venv = root/'venv'
cache = root/'installer-cache'
env = os.environ.copy()
env.update(UV_CACHE_DIR=str(cache), HF_HUB_DISABLE_XET='1', HF_XET_CHUNK_CACHE_SIZE_BYTES='0')
if not (venv/'bin/python').exists():
    subprocess.run([uv,'venv','--python',args.python,str(venv)],env=env,check=True)
python = str(venv/'bin/python')
locked=pathlib.Path(__file__).with_name('requirements.lock')
packages=['-r',str(locked)] if locked.exists() else [RUNTIME]
subprocess.run([uv,'pip','install','--python',python]+packages,env=env,check=True)
if shutil.disk_usage(root).free < 7*2**30:
    sys.exit('Runtime installed, but model download needs more room to preserve free space.')
model = root/'Qwen3.5-4B-MLX-4bit'
script = '''
from huggingface_hub import snapshot_download
import sys
snapshot_download(repo_id=sys.argv[1],revision=sys.argv[2],local_dir=sys.argv[3],max_workers=2,
 allow_patterns=['*.json','*.safetensors','*.jinja','*.txt','*.model','*.tiktoken'])
'''
subprocess.run([python,'-c',script,MODEL,REVISION,str(model)],env=env,check=True)
subprocess.run([python,'-c','from safetensors import safe_open; import sys; f=safe_open(sys.argv[1],framework="numpy"); print("Verified tensor file:",len(f.keys()),"tensors")',str(model/'model.safetensors')],env=env,check=True)
config={'python':python,'model_path':str(model),'model_id':MODEL,'revision':REVISION,'port':17293}
config_path = pathlib.Path.home()/'Library/Application Support/Rove/local-vision.json'
config_path.parent.mkdir(parents=True,exist_ok=True)
temporary=config_path.with_suffix('.tmp')
temporary.write_text(json.dumps(config,indent=2)+'\n')
temporary.chmod(0o600);temporary.replace(config_path)
print('Local vision installed. Runtime inference will use offline mode and loopback only.',flush=True)
print('Free GiB:',round(shutil.disk_usage(root).free/2**30,2),flush=True)

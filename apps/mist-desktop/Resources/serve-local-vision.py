"""Own one offline MLX server; shut it down when Rove or this wrapper exits."""
import argparse, os, signal, subprocess, sys, threading
p=argparse.ArgumentParser()
p.add_argument('--parent',type=int,required=True)
p.add_argument('--model',required=True)
p.add_argument('--port',type=int,required=True)
p.add_argument('--key',required=True)
p.add_argument('--diagnostics',action='store_true')
a=p.parse_args()
stop=threading.Event()
for sig in [signal.SIGTERM,signal.SIGINT]:signal.signal(sig,lambda *_:stop.set())
entry='import mlx.core as mx; mx.set_cache_limit(256*1024**2); mx.set_memory_limit(8*1024**3); import runpy; runpy.run_module("mlx_vlm.server",run_name="__main__")'
child=subprocess.Popen([sys.executable,'-c',entry,'--model',a.model,'--host','127.0.0.1','--port',str(a.port),'--api-key',a.key],stdin=subprocess.DEVNULL,stdout=None if a.diagnostics else subprocess.DEVNULL,stderr=None if a.diagnostics else subprocess.DEVNULL)
try:
    while child.poll() is None and not stop.wait(.5):
        if os.getppid()!=a.parent:break
finally:
    if child.poll() is None:
        child.terminate()
        try:child.wait(timeout=5)
        except subprocess.TimeoutExpired:child.kill();child.wait()

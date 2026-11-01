#!/usr/bin/env python3
"""Generate three local character-voice auditions; never change Rove's live voice."""
import argparse,json,pathlib,shutil,subprocess
root=pathlib.Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser()
p.add_argument('--output',type=pathlib.Path,required=True)
p.add_argument('--reuse-clean',action='store_true')
a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
ffmpeg=shutil.which('ffmpeg')
if not ffmpeg:raise SystemExit('Local ffmpeg is required for these audition effects.')
clean=a.output/'rove-clean.wav'
if not (a.reuse_clean and clean.exists()):
 subprocess.run([str(root/'build/Rove.app/Contents/MacOS/Rove'),'--voice-audition',str(clean)],check=True)
presets={
 '01-soft-scout':'asetrate=26939,aresample=24000,atempo=0.8909,highpass=f=85,lowpass=f=8500,equalizer=f=280:t=q:w=0.8:g=2,chorus=0.7:0.9:4:0.07:0.6:0.15',
 '02-pocket-robot':'asetrate=30238,aresample=24000,atempo=0.7937,highpass=f=120,lowpass=f=6800,aecho=0.8:0.88:6:0.16,tremolo=f=26:d=0.08',
 '03-tiny-explorer':'asetrate=33941,aresample=24000,atempo=0.7425,highpass=f=150,lowpass=f=7800,vibrato=f=6.2:d=0.025,chorus=0.65:0.9:7:0.12:1.1:0.25'}
for name,filters in presets.items():
 output=a.output/(name+'.wav')
 subprocess.run([ffmpeg,'-hide_banner','-loglevel','error','-y','-i',str(clean),'-af',filters+',loudnorm=I=-18:TP=-2:LRA=7','-ar','24000','-ac','1','-c:a','pcm_s16le',str(output)],check=True)
 print(output)
(a.output/'presets.json').write_text(json.dumps(presets,indent=2)+'\n')

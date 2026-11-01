#!/usr/bin/env python3
"""Reuse Casting Room Scout geometry in the native Metal renderer.
Requires Khronos glslangValidator and spirv-cross on PATH.
"""
import json, pathlib, re, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
s = (root/'Resources/scout-shaders.js').read_text()
lib = json.loads(s[s.index('=')+1:].rstrip(';\n '))
body = lib['objects']['scout']['body']
# Keep the original geometry and materials. Replace only the portrait camera,
# add two small front-edge lamps, and preserve linear extended-range output.
body = body.replace('return clamp(pow(max(linear,vec3(0.)),vec3(.45455)),0.,1.);','return max(linear,vec3(0.));')
body = re.sub(r'void scCamera\(.*?\n}\n', '''vec3 worldToScout(vec3 p) {
    // Heading about the screen normal, followed by the physical pickup tilt.
    float heading=U.pose.x+atan(sin(3.14159265-U.pose.x),cos(3.14159265-U.pose.x))*U.pose.w;
    float c=cos(heading),s=sin(heading);
    p=vec3(c*p.x-s*p.z,p.y,s*p.x+c*p.z);
    float a=U.pose.w*1.5707963+U.options.z,cx=cos(a),sx=sin(a);
    return vec3(p.x,cx*p.y-sx*p.z,sx*p.y+cx*p.z);
}
void scCamera(vec2 uv,vec2 orbit,out vec3 ro,out vec3 rd) {
    vec3 ground=vec3(uv.x,-.767,uv.y);
    vec3 eye=U.eye.xyz;
    ro=worldToScout(eye-vec3(0.,U.pose.w*1.05,0.));
    // Rotate the chassis around the rear axle; ray directions get no translation.
    float a=U.options.z,c=cos(a),s=sin(a);
    vec3 pivot=vec3(0.,-.472,-.431);
    ro+=pivot-vec3(pivot.x,c*pivot.y-s*pivot.z,s*pivot.y+c*pivot.z);
    rd=worldToScout(normalize(ground-eye));
}
''',body,flags=re.S)
# The source's kit has real rotating rim bores, hub marks and tire chevrons.
body=body.replace('scKitRoll=scKitOn && mode==7.?angle-.106*sin(angle):0.;','scKitRoll=U.pose.y/(U.viewport.z*.295);')
body=re.sub(r'uniform float (uFinish|uStyle|uRough);','',body)
body=re.sub(r'vec3 galleryMiss\(.*?\n}\n', 'vec3 galleryMiss(vec2 uv,vec3 ro,vec3 rd,float age){objectCoverage=0.;return vec3(0.); }\n',body,flags=re.S)
body=body.replace('min(-c+sqrt(disc),galleryFloorDepth(ro,rd))','-c+sqrt(disc)')
body=re.sub(r'\bpatch\b','groundPatch',body)
roof = """int roofGlyph(int code){
 if(code==65)return 11245;
 if(code==68)return 27502;
 if(code==69)return 31143;
 if(code==72)return 23533;
 if(code==73)return 29847;
 if(code==75)return 23469;
 if(code==76)return 18727;
 if(code==78)return 24573;
 if(code==79)return 31599;
 if(code==82)return 27565;
 if(code==83)return 31183;
 if(code==84)return 29842;
 if(code==89)return 23186;
 return 0;
}
int roofLetter(int index){
 if(U.pose.z<.5){int word[5]=int[5](82,69,65,68,89);return index<5?word[index]:0;}
 if(U.pose.z<1.5){int word[6]=int[6](76,73,83,84,69,78);return word[index];}
 if(U.pose.z<2.5){int word[5]=int[5](84,72,73,78,75);return index<5?word[index]:0;}
 if(U.pose.z<3.5){int word[4]=int[4](84,65,76,75);return index<4?word[index]:0;}
 int word[5]=int[5](69,82,82,79,82);return index<5?word[index]:0;
}
vec3 scRoof(vec3 p){
 vec2 surface=(p.xz-vec2(0.,.20))/vec2(.80,.26)+.5;
 vec2 pixel=vec2(surface.x*26.,(1.-surface.y)*9.);
 ivec2 cell=ivec2(floor(pixel));
 int count=U.pose.z<.5?5:U.pose.z<1.5?6:U.pose.z<2.5?5:U.pose.z<3.5?4:5;
 int x=cell.x-(26-(count*4-1))/2,y=cell.y-2;
 float dotInk=0.;
 if(x>=0&&x<count*4&&y>=0&&y<5&&x%4<3){
   int bit=14-(y*3+x%4);
   dotInk=float((roofGlyph(roofLetter(x/4))>>bit)&1);
 }
 vec2 dotUV=fract(pixel)-.5;
 float aperture=1.-smoothstep(.34,.48,max(abs(dotUV.x),abs(dotUV.y)));
 vec3 glass=vec3(.012,.021,.023);
 vec3 phosphor=vec3(.89,.626,.245);
 return glass+phosphor*dotInk*aperture*1.35;
}
"""
source='''#version 450
layout(location=0) out vec4 outputColor;
layout(set=0,binding=0,std140) uniform NativeUniforms {
 vec4 viewport; // drawable width/height, points per model unit, backing ratio
 vec4 eye;      // eye relative to rover in model units, seconds
 vec4 pose;     // heading, wheel distance, face mode, pickup fraction
 vec4 options;  // state age, HDR headroom, rear-axle wheelie radians, unused
} U;
#define uResolution U.viewport.xy
#define uDriveDistance U.pose.y
#define uEvent U.pose.z
#define uSince U.options.x
#define uTime U.eye.w
#define uFinish 0.
#define uStyle 0.
#define uRough 0.
'''+roof+lib['objects']['scout']['face']+body+'''
void main(){
 // A pixel is a real point on the display, not a rotated portrait quad.
 vec2 pixel=vec2(gl_FragCoord.x,U.viewport.y-gl_FragCoord.y)/U.viewport.w;
 vec2 uv=(pixel-vec2(150.,200.))/U.viewport.z;
 vec3 color=renderBot(uv,U.pose.z,U.options.x,U.eye.w,vec2(0.),vec2(0.));
 float coverage=objectCoverage;
 // Ground-plane contact shadows and light pools use the same physical rays.
 float c=cos(U.pose.x),s=sin(U.pose.x);
 vec2 p=vec2(c*uv.x-s*uv.y,s*uv.x+c*uv.y);
 float shadow=(.26*exp(-dot(p/vec2(.82,.65),p/vec2(.82,.65))))*(1.-.65*U.pose.w);
 for(int x=-1;x<=1;x+=2)for(int z=-1;z<=1;z+=2){
   vec2 d=(p-vec2(float(x)*.69,float(z)*.43))/vec2(.21,.19);
   shadow+=.36*exp(-dot(d,d)*2.)*(1.-U.pose.w)*(z>0?exp(-U.options.z*5.):1.);
 }
 float beam=0.;
 for(int i=-1;i<=1;i+=2){
   vec2 d=p-vec2(float(i)*.46,.60);
   float width=.06+max(0.,d.y)*.31;
   beam+=exp(-pow(d.x/width,2.)*2.)*exp(-max(0.,d.y)*2.)*smoothstep(0.,.06,d.y);
 }
 float lightAlpha=beam*.20*(1.-U.pose.w)*exp(-U.options.z*6.);
 float groundAlpha=clamp(shadow+lightAlpha,0.,.8);
 vec3 groundRGB=vec3(1.4,1.25,.82)*lightAlpha;
 vec3 rgb=color*coverage+groundRGB*(1.-coverage);
 float alpha=coverage+groundAlpha*(1.-coverage);
 // EDR unavailable: retain material detail and use SDR lamps.
 float peak=max(max(rgb.r,rgb.g),rgb.b);
 rgb*=min(1.,U.options.y/max(peak,.0001));
 outputColor=vec4(rgb,alpha);
}
'''
with tempfile.TemporaryDirectory() as tmp:
    frag=pathlib.Path(tmp)/'scout.frag';spv=pathlib.Path(tmp)/'scout.spv'
    frag.write_text(source)
    subprocess.run(['glslangValidator','-V',str(frag),'-o',str(spv)],check=True)
    metal=subprocess.check_output(['spirv-cross',str(spv),'--msl'],text=True)
metal+='''
vertex float4 scout_vertex(uint id [[vertex_id]]) {
 return float4(id==1?3.:-1.,id==2?3.:-1.,0.,1.);
}
'''
(root/'Resources/scout.metal').write_text('// Derived from the selected Casting Room Scout SDF. Regenerate with scripts/compile-scout.py.\n'+'\n'.join(line.rstrip() for line in metal.splitlines())+'\n')
print('Wrote native Scout Metal shader')

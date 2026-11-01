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
body = body.replace('return obj;', '''obj=scAdd(obj,scBox(p-vec3(-.46,.43,.568),vec3(.074,.035,.026),.016),12.);
    obj=scAdd(obj,scBox(p-vec3(.46,.43,.568),vec3(.074,.035,.026),.016),12.);
    return obj;''', 1)
body = body.replace('vec3 linear;','vec3 linear;').replace('if(h.y==3. && n.z>.94)', 'if(h.y==12.) { linear=vec3(4.,3.7,2.8); } else if(h.y==3. && n.z>.94)')
body = body.replace('return clamp(pow(max(linear,vec3(0.)),vec3(.45455)),0.,1.);','return max(linear,vec3(0.));')
body = re.sub(r'void scCamera\(.*?\n}\n', '''vec3 worldToScout(vec3 p) {
    // Heading about the screen normal, followed by the physical pickup tilt.
    float heading=U.pose.x+atan(sin(3.14159265-U.pose.x),cos(3.14159265-U.pose.x))*U.pose.w;
    float c=cos(heading),s=sin(heading);
    p=vec3(c*p.x-s*p.z,p.y,s*p.x+c*p.z);
    float a=U.pose.w*1.5707963,cx=cos(a),sx=sin(a);
    return vec3(p.x,cx*p.y-sx*p.z,sx*p.y+cx*p.z);
}
void scCamera(vec2 uv,vec2 orbit,out vec3 ro,out vec3 rd) {
    vec3 ground=vec3(uv.x,-.767,uv.y);
    vec3 eye=U.eye.xyz;
    ro=worldToScout(eye-vec3(0.,U.pose.w*1.05,0.));
    rd=worldToScout(normalize(ground-eye));
}
''',body,flags=re.S)
body=body.replace('uDriveDistance*.066','(U.pose.y/(U.viewport.z*.295))')
body=re.sub(r'\bpatch\b','groundPatch',body)
source='''#version 450
layout(location=0) out vec4 outputColor;
layout(set=0,binding=0,std140) uniform NativeUniforms {
 vec4 viewport; // drawable width/height, points per model unit, backing ratio
 vec4 eye;      // eye relative to rover in model units, seconds
 vec4 pose;     // heading, wheel distance, face mode, pickup fraction
 vec4 options;  // state age, HDR headroom, unused, unused
} U;
#define uResolution U.viewport.xy
#define uDriveDistance U.pose.y
'''+lib['objects']['scout']['face']+body+'''
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
   shadow+=.36*exp(-dot(d,d)*2.)*(1.-U.pose.w);
 }
 float beam=0.;
 for(int i=-1;i<=1;i+=2){
   vec2 d=p-vec2(float(i)*.46,.60);
   float width=.06+max(0.,d.y)*.31;
   beam+=exp(-pow(d.x/width,2.)*2.)*exp(-max(0.,d.y)*2.)*smoothstep(0.,.06,d.y);
 }
 float lightAlpha=beam*.20*(1.-U.pose.w);
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
(root/'Resources/scout.metal').write_text('// Derived from the selected Casting Room Scout SDF. Regenerate with scripts/compile-scout.py.\n'+metal)
print('Wrote native Scout Metal shader')

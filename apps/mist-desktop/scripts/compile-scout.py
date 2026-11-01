#!/usr/bin/env python3
"""Compile the authored Scout studio geometry, optics and floor effects for native EDR."""
import pathlib,re,subprocess,tempfile
root=pathlib.Path(__file__).resolve().parents[1]
original=(root/'Resources/scout-study-source.glsl').read_text()
body=original[:original.index('// 5 x 7 column masks')]
body=re.sub(r'\bpatch\b','groundPatch',body)
body=re.sub(r'^precision .*?;\n|^uniform .*?;\n','',body,flags=re.M)
body=body.replace('smoothstep(1.78,3.055,max(0.,rear))','smoothstep(.25,1.10,max(0.,rear))')
body=body.replace('scKitRoll=scKitOn && mode==7.?angle-.106*sin(angle):0.;','scKitRoll=U.pose.y/(U.viewport.z*.295);')
body=re.sub(r'float scoutTravel\(float age\)\{.*?\n}', 'float scoutTravel(float age){return max(0.,U.pose.y/U.viewport.z);}',body,flags=re.S)
camera='''vec3 worldToScout(vec3 p) {
 float heading=U.pose.x+atan(sin(3.14159265-U.pose.x),cos(3.14159265-U.pose.x))*U.pose.w;
 float c=cos(heading),s=sin(heading);p=vec3(c*p.x-s*p.z,p.y,s*p.x+c*p.z);
 float a=U.pose.w*1.5707963+U.options.z,cx=cos(a),sx=sin(a);
 return vec3(p.x,cx*p.y-sx*p.z,sx*p.y+cx*p.z);
}
vec3 scoutPoint(vec3 p){
 p=worldToScout(p-vec3(0.,U.pose.w*1.05,0.));
 float a=U.options.z,c=cos(a),s=sin(a);vec3 pivot=vec3(0.,-.472,-.431);
 return p+pivot-vec3(pivot.x,c*pivot.y-s*pivot.z,s*pivot.y+c*pivot.z);
}
void scCamera(vec2 uv,vec2 orbit,out vec3 ro,out vec3 rd){
 vec3 ground=vec3(uv.x,-.767,uv.y);ro=scoutPoint(U.eye.xyz);rd=worldToScout(normalize(ground-U.eye.xyz));
}
'''
body=re.sub(r'void scCamera\(.*?\n}\n',camera,body,flags=re.S)
extra=original[original.index('vec2 studySDF('):original.index('vec3 studyAir(')]
extra+=original[original.index('vec3 studyGlare('):original.index('float faceMode(')]
header='''#version 450
layout(location=0) out vec4 outputColor;
layout(set=0,binding=0,std140) uniform NativeUniforms {
 vec4 viewport; vec4 eye; vec4 pose; vec4 options;
 vec4 outfit; // optics, paint, face, lamp power
 vec4 mechanics; // lamp hinge, shadow enabled, track fade, unused
} U;
#define uResolution U.viewport.xy
#define uEvent U.pose.z
#define uSince U.options.x
#define uTime U.eye.w
#define uFinish U.outfit.z
#define uStyle U.outfit.y
#define uRough U.mechanics.y
#define uLook vec2(0.)
#define uReduce 0.
'''
main='''
void main(){
 vec2 pixel=vec2(gl_FragCoord.x,U.viewport.y-gl_FragCoord.y)/U.viewport.w;
 vec2 uv=(pixel-vec2(150.,200.))/U.viewport.z;
 float style=U.outfit.x;bool kit=style>=3.5;
 kitLift=U.mechanics.x;scKitPose(kit?1.:0.,U.pose.z,U.options.x);
 float power=U.outfit.w*(kit?liftLampGain():1.);if(style<.5)power=0.;
 vec3 ro,rd;scCamera(uv,vec2(0.),ro,rd);
 float along=dot(ro,rd),disc=along*along-dot(ro,ro)+3.24,depth=10000.;vec2 hit=vec2(0.);
 if(disc>0.){
  float t=max(0.,-along-sqrt(disc)),end=-along+sqrt(disc);
  for(int i=0;i<112;i++){
   vec2 probe=studySDF(ro+rd*t,style);
   if(probe.x<.00075){hit=probe;depth=t;break;}
   t+=max(.00042,probe.x*.74);if(t>end)break;
  }
 }
 vec3 color=vec3(0.);float coverage=hit.y>.5?1.:0.;
 if(coverage>0.){
  vec3 p=ro+rd*depth,n=studyNormal(p,style),v=-rd;
  if(hit.y==3.&&n.z>.94)color=scLCD(p+v*((scGlass-p.z)/v.z),v,scKitFaceMode(U.pose.z),U.options.x,vec2(0.));
  else if(hit.y>=110.){
   color=kitDisplaySurface(p,n,v,hit.y,style);
   if(kitDisplayLiveGlass(p,n,hit.y,style))color=kitDisplayGlassRay(ro,rd,style);
  }else if(hit.y>=40.)color=kitPaintFinish(p,n,v,hit.y,liftLampSurface(p,n,v,hit.y,power),uStyle);
  else if(hit.y>=19.5)color=headFinish(p,n,v,hit.y,style,power);
  else color=kitPaintFinish(p,n,v,hit.y,scHousing(p,n,v,hit.y),uStyle)+headBounce(p,n,style,power);
  color+=studyGlare(ro,rd,depth,style,power);
 }
 // Use the source's tire lugs and chassis shadow on a transparent display receiver.
 float c=cos(U.pose.x),s=sin(U.pose.x);
 vec2 floorPoint=vec2(c*uv.x-s*uv.y,s*uv.x+c*uv.y);
 float detail=clamp(U.viewport.z/55.,.1,1.);
 float shade=.45*scoutCastOpacity(floorPoint)*(1.-.35*U.pose.w)*(floorPoint.y>0.?exp(-U.options.z*3.):1.);
 float dust=.83*scoutTreadCoverage(floorPoint,7.,max(1.,U.options.x),detail)*U.mechanics.z;
 float floorAlpha=shade+(1.-shade)*dust;
 vec3 floorRGB=vec3(.003,.005,.008)*shade+vec3(.119,.113,.094)*dust*(1.-shade);
 // Each authored angular beam originates at its real lens, including hinge and chassis tilt.
 vec3 floorLocal=scoutPoint(vec3(uv.x,-.767,uv.y));
 vec3 floorNormal=worldToScout(vec3(0.,1.,0.)),light=vec3(0.);
 if(power>0.)for(int k=0;k<2;k++){
  float side=k==0?-1.:1.;vec3 d=floorLocal-studyLampOrigin(style,side);
  float d2=dot(d,d);vec3 ray=d*inversesqrt(max(.0001,d2));
  vec3 opticRay=kit?liftLampReferenceDirection(ray):ray;
  float e=sfCandela(opticRay,kit?2.:style,side)*max(dot(-ray,floorNormal),0.)/(d2+.055);
  light+=vec3(.245,.250,.258)*e*headTint(style)*power;
 }
 float lightPeak=max(light.r,max(light.g,light.b));
 float lightAlpha=.18*(1.-exp(-lightPeak*.5));
 floorRGB+=light*.055*(1.-floorAlpha);floorAlpha+=lightAlpha*(1.-floorAlpha);
 float edge=min(min(pixel.x,300.-pixel.x),min(pixel.y,380.-pixel.y));
 float fade=smoothstep(0.,18.,edge);floorRGB*=fade;floorAlpha*=fade;
 vec3 rgb=color*coverage+floorRGB*(1.-coverage);
 float alpha=coverage+floorAlpha*(1.-coverage);
 float peak=max(rgb.r,max(rgb.g,rgb.b));rgb*=min(1.,U.options.y/max(peak,.0001));
 outputColor=vec4(rgb,alpha);
}
'''
with tempfile.TemporaryDirectory() as tmp:
 frag=pathlib.Path(tmp)/'scout.frag';spv=pathlib.Path(tmp)/'scout.spv';frag.write_text(header+body+extra+main)
 subprocess.run(['glslangValidator','-V',str(frag),'-o',str(spv)],check=True)
 metal=subprocess.check_output(['spirv-cross',str(spv),'--msl'],text=True)
metal+='\nvertex float4 scout_vertex(uint id [[vertex_id]]) {return float4(id==1?3.:-1.,id==2?3.:-1.,0.,1.);}\n'
(root/'Resources/scout.metal').write_text('// Authored Scout studio, adapted for native EDR. Regenerate with scripts/compile-scout.py.\n'+'\n'.join(x.rstrip() for x in metal.splitlines())+'\n')
print('Compiled full Scout studio optics, roof kits and receiver effects')

// All live portraits share this WebGL context. Render targets carry real RGBA
// silhouettes, never the alpha tags used inside the separate housing caches.
window.CastingGL=(()=>{
  'use strict';
  const lib=window.CAST_SHADER_LIBRARY;
  const vertex='attribute vec2 aPosition; varying vec2 vUV; void main(){vUV=aPosition*.5+.5;gl_Position=vec4(aPosition,0.,1.);}';
  const composite=`precision highp float;varying vec2 vUV;uniform sampler2D uImage;uniform vec2 uFootprint;
    void main(){vec2 p=uFootprint;gl_FragColor=.25*(texture2D(uImage,vUV+p)+texture2D(uImage,vUV-p)+
      texture2D(uImage,vUV+vec2(p.x,-p.y))+texture2D(uImage,vUV+vec2(-p.x,p.y)));}`;
  const controller='precision highp float;uniform sampler2D uMemory;uniform float uEvent,uTime;\n'+lib.state+
    '\nvoid main(){gl_FragColor=advanceBot(texture2D(uMemory,vec2(.5)),uEvent,uTime);}';
  const modes=['idle','listen','think','speak','sleep','tool'];
  const glOptions={alpha:true,premultipliedAlpha:true,antialias:false,depth:false,stencil:false,preserveDrawingBuffer:false,powerPreference:'high-performance'};
  function open(canvas){
    const gl=canvas.getContext('webgl',glOptions)||canvas.getContext('experimental-webgl',glOptions);
    if(!gl)return null;
    const parallel=gl.getExtension('KHR_parallel_shader_compile');
    const maxSize=Math.min(gl.getParameter(gl.MAX_TEXTURE_SIZE),gl.getParameter(gl.MAX_RENDERBUFFER_SIZE));
    gl.disable(gl.BLEND);gl.disable(gl.DEPTH_TEST);gl.disable(gl.SCISSOR_TEST);gl.disable(gl.DITHER);
    gl.clearColor(0,0,0,0);
    const buffer=gl.createBuffer();gl.bindBuffer(gl.ARRAY_BUFFER,buffer);
    gl.bufferData(gl.ARRAY_BUFFER,new Float32Array([-1,-1,3,-1,-1,3]),gl.STATIC_DRAW);
    gl.enableVertexAttribArray(0);gl.vertexAttribPointer(0,2,gl.FLOAT,false,0,0);
    const vs=gl.createShader(gl.VERTEX_SHADER);gl.shaderSource(vs,vertex);gl.compileShader(vs);
    const programs=new Map();let newPrograms=0,inFlight=0;
    function start(key,body){
      const fragment=gl.createShader(gl.FRAGMENT_SHADER),p=gl.createProgram();
      gl.shaderSource(fragment,body);gl.compileShader(fragment);gl.attachShader(p,vs);gl.attachShader(p,fragment);
      gl.bindAttribLocation(p,0,'aPosition');gl.linkProgram(p);
      const item={key,p,fragment,U:null,failed:false};programs.set(key,item);inFlight++;return item;
    }
    function finish(item,force=false){
      if(item.U||item.failed)return item;
      if(!force&&parallel&&!gl.getProgramParameter(item.p,parallel.COMPLETION_STATUS_KHR))return item;
      inFlight--;
      if(!gl.getProgramParameter(item.p,gl.LINK_STATUS)){
        const reason=gl.getShaderInfoLog(item.fragment)||gl.getProgramInfoLog(item.p)||'Program did not link';
        console.warn('Casting Room shader '+item.key+': '+reason);
        gl.deleteShader(item.fragment);gl.deleteProgram(item.p);item.failed=true;return item;
      }
      const U=Object.create(null);
      for(let i=0,len=gl.getProgramParameter(item.p,gl.ACTIVE_UNIFORMS);i<len;i++){
        const uniform=gl.getActiveUniform(item.p,i);if(!uniform)continue;
        U[uniform.name]=gl.getUniformLocation(item.p,uniform.name);
      }
      item.U=U;gl.deleteShader(item.fragment);return item;
    }
    function acquire(key,source){
      let p=programs.get(key);
      if(!p){if(newPrograms>=1||inFlight>=3)return null;p=start(key,source());newPrograms++;}
      return finish(p);
    }
    function begin(){
      newPrograms=0;
      if(inFlight)for(const p of programs.values())if(!p.U&&!p.failed)finish(p);
    }
    const quad=finish(start('composite',composite),true),state=finish(start('state',controller),true);
    if(quad.failed||state.failed)throw Error('The display program could not initialize.');
    function bind(unit,texture){gl.activeTexture(gl.TEXTURE0+unit);gl.bindTexture(gl.TEXTURE_2D,texture);}
    function texture(w,h,linear=false,initial=null){
      const tex=gl.createTexture();bind(0,tex);
      const filter=linear?gl.LINEAR:gl.NEAREST;
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MIN_FILTER,filter);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_MAG_FILTER,filter);
      gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_S,gl.CLAMP_TO_EDGE);gl.texParameteri(gl.TEXTURE_2D,gl.TEXTURE_WRAP_T,gl.CLAMP_TO_EDGE);
      gl.texImage2D(gl.TEXTURE_2D,0,gl.RGBA,w,h,0,gl.RGBA,gl.UNSIGNED_BYTE,initial);return tex;
    }
    function target(w,h,linear=false,initial=null){
      const tex=texture(w,h,linear,initial),fb=gl.createFramebuffer();gl.bindFramebuffer(gl.FRAMEBUFFER,fb);
      gl.framebufferTexture2D(gl.FRAMEBUFFER,gl.COLOR_ATTACHMENT0,gl.TEXTURE_2D,tex,0);
      if(gl.checkFramebufferStatus(gl.FRAMEBUFFER)!==gl.FRAMEBUFFER_COMPLETE){
        gl.deleteTexture(tex);gl.deleteFramebuffer(fb);throw Error('Could not allocate a character render surface.');
      }
      return {tex,fb,w,h};
    }
    function release(t){if(t){gl.deleteTexture(t.tex);gl.deleteFramebuffer(t.fb);}}
    const dummy=texture(1,1,false,new Uint8Array([0,0,0,0]));
    const face=target(64,48),bytes=new Uint8Array(4),memory=[target(1,1,false,bytes),target(1,1,false,bytes)];let read=0;
    function use(p){gl.useProgram(p.p);}
    function f(p,k,v){if(p.U[k]!=null)gl.uniform1f(p.U[k],v);}
    function pair(p,k,a,b){if(p.U[k]!=null)gl.uniform2f(p.U[k],a,b);}
    function sampler(p,k,unit){if(p.U[k]!=null)gl.uniform1i(p.U[k],unit);}
    function surface(t){gl.bindFramebuffer(gl.FRAMEBUFFER,t.fb);gl.viewport(0,0,t.w,t.h);}
    function draw(){gl.drawArrays(gl.TRIANGLES,0,3);}
    // Read one texel at a user event or a sequence boundary. Rendering has no GPU readback.
    function step(event,time){
      const next=1-read;surface(memory[next]);use(state);bind(0,memory[read].tex);
      sampler(state,'uMemory',0);f(state,'uEvent',event);f(state,'uTime',time);draw();
      gl.readPixels(0,0,1,1,gl.RGBA,gl.UNSIGNED_BYTE,bytes);read=next;
      const age=((time-(bytes[1]*256+bytes[2])/512+.001)%128+128)%128;
      return {mode:modes[bytes[0]]||'idle',entered:time-age,playing:bytes[3]>=128};
    }
    function getPrograms(model){
      if(model.set==='objects'){
        const o=lib.objects[model.id];if(!o)return {failed:true};
        const body=acquire('object/'+model.id,()=>[o.fastPanel?'#define OBJECT_FAST_PANEL':'',lib.objectUniforms,o.face,o.body,lib.objectMain].join('\n'));
        return {body,failed:body?.failed,ready:!!body?.U,record:o};
      }
      const set=lib.cases.sets[model.set],style=set?.models[model.id];
      if(!style||!lib.cases.faces[model.id])return {failed:true};
      const body=acquire('case/'+model.set,()=>set.source);
      const eye=acquire('face/'+model.id,()=>lib.cases.faces[model.id]);
      return {body,eye,failed:body?.failed||eye?.failed,ready:!!body?.U&&!!eye?.U,record:style};
    }
    function uniforms(p,values){
      for(const [k,v] of Object.entries(values)){
        const u=p.U[k];if(u==null)continue;
        if(typeof v==='number')gl.uniform1f(u,v);
        else if(v.length===3)gl.uniform3fv(u,v);
        else if(v.length===4)gl.uniform4fv(u,v);
        else if(v.length===2)gl.uniform2fv(u,v);
      }
    }
    function clocks(p,pose){
      f(p,'uEvent',pose.mode);f(p,'uSince',pose.age);f(p,'uTime',pose.time);f(p,'uReduce',pose.reduced?1:0);
      pair(p,'uLook',pose.lookX,pose.lookY);pair(p,'uPixelOrigin',0,0);
    }
    function releasePortrait(e){release(e.image);release(e.beauty);e.image=null;e.beauty=null;e.cacheKey='';}
    function render(e,programs,w,h,pose){
      if(!e.image||e.image.w!==w||e.image.h!==h){releasePortrait(e);e.image=target(w,h,true);}
      const {eye,body,record}=programs;
      if(eye){
        bind(1,dummy);surface(face);use(eye);clocks(eye,pose);draw();
      }
      function shade(pass,t){
        surface(t);use(body);
        clocks(body,pose);pair(body,'uResolution',w,h);
        pair(body,'uOrbit',pose.yaw-(eye?0:pose.turnX),pose.pitch-(eye?0:pose.turnY));
        pair(body,'uBodyTurn',pose.turnX,pose.turnY);f(body,'uPass',pass);
        if(eye)uniforms(body,record.uniforms);
        else if(body.U.uObjectFrame!=null)gl.uniform3fv(body.U.uObjectFrame,pose.detail?record.detailFrame:record.galleryFrame);
        bind(0,pass===2?e.beauty.tex:dummy);sampler(body,'uBeauty',0);
        bind(1,eye?face.tex:dummy);sampler(body,'uEyeMask',1);
        draw();
      }
      if(pose.moving||(!eye&&!record.cacheable)){
        e.cacheKey='';shade(0,e.image);
      }else{
        const key=[pose.yaw,pose.pitch,pose.turnX,pose.turnY].join(',');
        if(!e.beauty)e.beauty=target(w,h);
        if(e.cacheKey!==key){shade(1,e.beauty);e.cacheKey=key;}
        shade(2,e.image);
      }
    }
    function startDisplay(w,h){
      if(canvas.width!==w||canvas.height!==h){canvas.width=w;canvas.height=h;}
      gl.bindFramebuffer(gl.FRAMEBUFFER,null);gl.viewport(0,0,w,h);gl.clear(gl.COLOR_BUFFER_BIT);use(quad);sampler(quad,'uImage',0);
    }
    function blit(e,x,y,w,h){
      if(!e.image||w<=0||h<=0)return;
      gl.viewport(x,y,w,h);bind(0,e.image.tex);
      // Four subpixel taps resolve curved silhouettes; the LCD marks retain their true cell edges.
      pair(quad,'uFootprint',e.image.w>w*1.05?.23/w:0,e.image.h>h*1.05?.23/h:0);draw();
    }
    return {gl,maxSize,begin,getPrograms,render,startDisplay,blit,releasePortrait,step};
  }
  return {open,modes};
})();

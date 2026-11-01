precision highp float;
uniform vec2 uResolution, uOrbit, uLook;
uniform float uTime, uSince, uEvent, uReduce;
uniform sampler2D uMemory;
uniform sampler2D uBeauty;

uniform vec2 uOrigin;
uniform float uRadius;

float pcExpression = -1.;
// A pair of little rangefinders with independent focus and a radio mouth.
float scPixelBox(vec2 p,vec2 halfSize) {
    return step(max(abs(p.x)-halfSize.x,abs(p.y)-halfSize.y),0.);
}
float scFinder(vec2 p,vec2 h,float blink,vec2 eye,bool think) {
    h.y=max(1.,floor(h.y*blink+.5));
    if(h.y<=1.) return scPixelBox(p,vec2(h.x-1.,.55));
    vec2 d=abs(p);
    float chamfer=step(d.x+d.y,h.x+h.y-2.);
    float edge=scPixelBox(p,h)*chamfer;
    float core=scPixelBox(p,h-1.3)*step(d.x+d.y,h.x+h.y-4.);
    float bracket=(edge-core)*(.72+.28*step(min(abs(d.x-h.x),abs(d.y-h.y)),1.));
    vec2 k=p-eye;
    float focus=scPixelBox(k,vec2(2.5,3.5))*step(abs(k.x)+abs(k.y),4.);
    focus*=1.-scPixelBox(k-vec2(-1.,2.),vec2(.5));
    if(think)focus=max(scPixelBox(k,vec2(2.,.6)),scPixelBox(k,vec2(.6,2.)));
    return max(bracket,core*focus);
}
float baseFaceInk(vec2 cell,float mode,float t,vec2 look) {
    bool listen=mode==1.,think=mode==2.,speak=mode==3.,sleep=mode==4.;
    vec2 p=floor(cell)-vec2(31.,24.);
    float blink=sleep?0.:smoothstep(.02,.16,abs(mod(t+.85,5.35)-.16));
    float signX=p.x<0.?-1.:1.;
    vec2 gaze=floor(2.*look+vec2(.5));
    gaze.x+=floor(1.1*sin(.8*t)+.5);
    if(think)gaze=vec2(floor(3.*sin(t*1.38)+.5),1.);
    vec2 eye=p-vec2(10.*signX,3.);
    float radius=listen?(signX>0.?7.:5.):6.;
    if(think && signX<0.) eye.y-=2.;
    float v=scFinder(eye,vec2(radius,think && signX>0.?4.:6.),blink,gaze,think);
    // An etched central bridge makes each pair read as one optical instrument.
    if(!sleep) v=max(v,.52*scPixelBox(p-vec2(0.,5.),vec2(2.5,.5)));
    vec2 mouth=p-vec2(0.,-9.);
    if(speak) {
        float x=abs(mouth.x);
        float height=floor((1.-x/7.)*(2.4+2.3*sin(11.*t-.78*x))+1.);
        v=max(v,scPixelBox(vec2(mouth.x,mouth.y),vec2(6.,max(0.,height)))*step(mod(x,2.),.5));
    } else {
        float arc=floor(.09*mouth.x*mouth.x+.5);
        if(think)arc=floor(.22*mouth.x+.5);
        if(sleep)arc=0.;
        v=max(v,scPixelBox(vec2(mouth.x,mouth.y-arc),vec2(sleep?2.:4.,.55)));
    }
    if(listen) {
        float h=floor(1.+1.2*(.5+.5*sin(5.*t)));
        v=max(v,.72*scPixelBox(vec2(abs(p.x)-21.,p.y-3.),vec2(.55,h)));
    }
    return v;
}

// Two possible landmarks trade prominence. Finder marks then converge on a subject.
float actingFace(vec2 cell,float state,float age,vec2 look) {
    vec2 p=floor(cell);
    float phase=fract(age/3.);
    if(state<4.5) {
        float turn=sin(phase*6.283);
        vec2 nudge=vec2(floor(clamp(look.x,-1.,1.)+.5),0.);
        float ink=baseFaceInk(cell-nudge,2.,age,look);
        for(int i=0;i<2;i++) {
            float side=2.*float(i)-1.;
            vec2 peak=p-vec2(31.+side*7.,38.);
            float ridge=step(abs(peak.y+abs(peak.x)-2.),.55)*step(abs(peak.x),3.);
            float pin=scPixelBox(peak-vec2(0.,4.),vec2(.6));
            ink=max(ink,max(ridge,pin)*(.61+.37*side*turn));
        }
        return ink;
    }
    float focus=smoothstep(.16,.72,phase);
    float side=1.-2.*step(.5,fract(age/6.));
    vec2 target=vec2(31.+side*(9.-4.*focus),10.);
    float ink=baseFaceInk(cell,1.,age,look*.55+vec2(side*(1.-.5*focus),-.85));
    vec2 aim=p-floor(target+.5);
    vec2 extent=vec2(3.+floor(4.*(1.-focus)),2.+floor(2.*(1.-focus)));
    vec2 corner=abs(aim)-extent;
    float brackets=max(scPixelBox(corner+vec2(1.,0.),vec2(1.,.55)),scPixelBox(corner+vec2(0.,1.),vec2(.55,1.)));
    float diamond=step(abs(abs(aim.x)+abs(aim.y)-1.),.5);
    float lock=scPixelBox(aim,vec2(.55))*step(.76,phase);
    return max(ink,max(.86*brackets,max(.67*diamond,lock)));
}

float faceInk(vec2 cell,float mode,float t,vec2 look){
    float state=pcExpression<0.?mode:pcExpression;
    if(state==2. || state==5.) return actingFace(cell,state,t,look);
    return baseFaceInk(cell,mode,t,look);
}

uniform float uFinish;
// Alternate phosphor masks in the existing amber LCD. Cells are integral, +Y up.
float dialOval(vec2 p,vec2 radius){vec2 d=p/radius;return step(dot(d,d),1.);}
float dialRound(float x){return floor(x+.5);}
float dialArc(vec2 p,float width,float weight){
    float y=1.-floor(.43*abs(p.x));
    return step(abs(p.x),width)*step(abs(p.y-y),weight);
}
// The dish seeks right, listens, seeks left, and returns to center over eight seconds.
float dialSearch(float t){
    t=mod(t,8.);
    return .94*smoothstep(.12,2.,t)-1.98*smoothstep(2.61,5.43,t)+1.04*smoothstep(6.20,7.90,t);
}
// Two independent stepped bezels and the notched, side-lit pupils of the original toy.
float scoutOriginalInk(vec2 cell,float mode,float age,vec2 look){
    vec2 p=floor(cell)-vec2(31.,24.);
    if(abs(p.x)>16.||p.y< -14.||p.y>14.)return 0.;
    float t=max(0.,age);
    if(p.y< -6.){
        vec2 m=p-vec2(0.,-11.);
        if(mode==3.||mode==1.){
            float h=mode==1.?1.65:1.1+2.25*(.5+.5*sin(12.*t+.5*sin(4.*t)));
            return dialOval(m,vec2(2.8,h+.25))*(1.-dialOval(m,vec2(1.58,max(.45,h-.9))));
        }
        if(mode==4.)return .72*scPixelBox(m,vec2(1.15,.5));
        if(mode==2.)m.x-=1.;
        if(mode==2.||mode==5.){
            float y=mode==2.?step(1.,m.x):step(2.,m.x);
            return step(abs(m.x),3.)*step(abs(m.y-y),.5);
        }
        return 0.;
    }
    float side=p.x<0.?-1.:1.;
    vec2 q=p-vec2(9.*side,3.);
    float h=8.,aim=-2.,lift=0.;
    vec2 point=clamp(look,-1.,1.);
    if(mode==0.)aim+=step(.70,fract(t/6.5))*2.-step(.81,fract(t/6.5))*2.;
    if(mode==1.){lift=1.;if(side>0.)q.y-=1.;}
    if(mode==2.){
        aim=mix(-2.,2.,smoothstep(.35,.56,fract(t/3.7)));
        lift=1.;if(side>0.)h-=1.;
    }
    if(mode==5.){aim=2.-3.*smoothstep(.18,.63,fract(t/3.2));lift=-1.;if(side<0.)h-=1.;}
    if(mode==6.){aim=3.*dialSearch(t);lift=1.;}
    if(mode==7.){aim=1.;lift=-1.;h-=1.;}
    aim=dialRound(clamp(aim+point.x*3.5,-2.,2.));
    lift=dialRound(clamp(lift+point.y,-1.,1.));
    float blink=abs(mod(t+.64,5.35)-.17);
    float lid=mode==4.?0.:smoothstep(.045,.15,blink);
    if(lid<.16){
        float y=mode==4.?-1.+floor(abs(q.x)*.30):1.-floor(abs(q.x)*.30);
        return .84*step(abs(q.x),4.)*step(abs(q.y-y),.5);
    }
    h=max(2.,dialRound(h*lid));
    float band=h-abs(q.y),x=abs(q.x);
    float outer=step(0.,band)*step(x,band<.5?3.:band<1.5?4.:5.);
    float hollow=step(1.5,band)*step(x,4.);
    float rim=outer*(1.-hollow);
    vec2 a=q-vec2(aim,lift);
    // The one dark notch and broad flat flank are visible even at gallery scale.
    float pupilH=max(1.,h-3.);
    float edge=pupilH-abs(a.y);
    float pupil=step(0.,edge)*step(abs(a.x+.45),edge<.5?1.5:edge<1.5?2.:2.6);
    pupil*=1.-scPixelBox(a-vec2(-1.,dialRound(.58*pupilH)),vec2(.45));
    return max(rim,outer*pupil);
}
// A short, round-tipped phosphor segment under the same matrix cover.
float scoutSmileDistance(vec2 p,float mode){
    float radius=mode==7.?3.7:3.;
    vec2 q=vec2(abs(p.x),p.y+11.65-radius);
    vec2 tip=radius*vec2(.93,-.368);
    return dot(q,vec2(.368,.93))>0.?length(q-tip):abs(length(q)-radius);
}
float dialMouth(vec2 p,float mode,float t,float style){
    vec2 m=p-vec2(0.,-8.);
    if(mode==4.)return .64*scPixelBox(m,vec2(style==1.?2.:1.,.5));
    if(mode==3.){
        float beat=1.-abs(2.*fract(t*2.6+.08*style)-1.);
        float h=1.+floor(3.*beat),w=style==2.?4.:3.;
        float outer=dialOval(m,vec2(w+.6,h+.5));
        float hollow=h>1.5?dialOval(m-vec2(0.,1.),vec2(w-1.,max(.9,h-1.))):0.;
        return outer*(1.-.88*hollow);
    }
    if(mode==2.){
        m.x-=2.;float y=floor(.27*m.x+.5);
        return .91*scPixelBox(vec2(m.x,m.y-y),vec2(3.,.5));
    }
    if(mode==5.){
        float x=abs(m.x);float y=step(2.,m.x);
        return step(x,3.)*step(abs(m.y-y),.5);
    }
    if(mode==1.||(mode==6.&&style==1.)){
        vec2 r=mode==1.?vec2(2.72,2.45):vec2(2.78,2.65);
        return dialOval(m,r)*(1.-.97*dialOval(m,vec2(1.52,1.52)));
    }
    float width=style==3.?3.:4.;if(mode==7.)width+=1.;
    float y=floor(.105*m.x*m.x+.5);if(style==2.&&m.x>1.)y+=1.;
    return step(abs(m.x),width)*step(abs(m.y-y+.5),.55);
}
float dialBinocular(vec2 p,float mode,vec2 gaze,float lid,float focus,float turn){
    float side=p.x<0.?-1.:1.;
    vec2 q=p-vec2(10.*side,3.);
    if(mode==1.&&side>0.)q.y-=1.;
    if(mode==2.&&side<0.)q.y-=1.;
    if(lid<.1){
        float glasses=dialOval(q,vec2(8.7,4.8))-dialOval(q,vec2(7.4,3.6));
        float bridge=scPixelBox(p-vec2(0.,5.),vec2(2.,.6));
        return max(.88*dialArc(q,5.,.55),(mode==4.?.28:.55)*max(glasses,bridge));
    }
    float h=mode==1.&&side>0.?8.:7.;
    if((mode==2.&&side>0.)||(mode==5.&&side<0.)||mode==7.)h-=2.;
    h=max(2.,floor(h*lid+.5));
    float inside=dialOval(q,vec2(6.8,max(.9,h-1.85)));
    float rim=dialOval(q,vec2(9.25,h+.25))-inside;
    float ink=rim*(.77+.23*step(-1.,q.y));
    vec2 a=q-gaze;
    float pupil=dialOval(a,vec2(3.05,min(3.65,h-1.)));
    pupil*=1.-.88*scPixelBox(a-vec2(-1.,2.),vec2(.5));
    if(mode==5.&&side>0.){
        // One lens stops down. The other centers a focus target and confirms it.
        float r=dot(a,a),ring=step(3.1,r)*step(r,11.);
        pupil=max(.79*ring,focus*scPixelBox(a,vec2(.5)));
    }
    ink=max(ink,inside*pupil);
    float bridge=.87*scPixelBox(p-vec2(0.,5.),vec2(2.,.6));
    if(mode==6.){
        vec2 e=p-vec2(side*23.,4.);
        float tick=scPixelBox(e,vec2(.55,1.5));
        ink=max(ink,.72*tick*step(.60,turn*side));
    }
    return max(ink,bridge);
}
float dialWaypoint(vec2 p,float mode,vec2 gaze,float lid,float focus,float turn){
    float side=p.x<0.?-1.:1.;
    vec2 q=p-vec2(10.*side,4.);
    if((mode==1.&&side>0.)||(mode==2.&&side<0.))q.y-=2.;
    if(mode==6.)q.y-=2.*step(.45,side*turn);
    if(mode==7.)q.x+=floor(max(0.,-q.y)*.23+.5);
    if(lid<.1){
        float tip=step(abs(q.x),3.)*step(abs(q.y+4.-abs(q.x)),.5);
        return max(.88*dialArc(q,4.,.55),(mode==4.?.34:.56)*tip);
    }
    float h=max(2.,floor(6.2*lid+.5));
    float drop=mode==5.&&side>0.?11.:9.;
    float head=dialOval(q,vec2(6.65,h+.3));
    float tail=step(-drop,q.y)*step(q.y,-1.)*step(abs(q.x),.79*(q.y+drop));
    float pin=max(head,tail);
    vec2 a=q-gaze;
    float hole=dialOval(a,vec2(3.45,min(3.4,h)));
    float glint=.70*scPixelBox(a-vec2(-1.,1.),vec2(.5));
    float ink=pin*(.85+.15*step(-1.,q.y))*(1.-hole*(1.-glint));
    if(mode==5.&&side>0.){
        // The selected pin drops onto its two-cell landing pad and lights a cross.
        float crossMark=max(scPixelBox(a,vec2(1.4,.5)),scPixelBox(a,vec2(.5,1.4)));
        ink=max(ink,.93*focus*crossMark*hole);
        ink=max(ink,.65*focus*scPixelBox(q+vec2(0.,12.),vec2(2.,.5)));
    }
    if(mode==6.){
        vec2 ping=p-vec2(20.*side,4.);
        ink=max(ink,.69*step(.52,turn*side)*step(abs(abs(ping.x)+abs(ping.y)-2.),.5));
    }
    return ink;
}
float dialSweep(vec2 p,float mode,vec2 gaze,float lid,float focus,float turn,float t){
    vec2 q=p-vec2(0.,3.);float x=abs(q.x);
    float hi=5.-floor(max(x-17.,0.)*.50+.25);
    float lo=-5.+floor(max(x-17.,0.)*.50+.25)+step(x,2.);
    if(x>23.||q.y<lo||q.y>hi)return 0.;
    float top=step(hi-.9,q.y),bottom=step(q.y,lo+.9);
    float caps=step(21.5,x);
    float rim=max(.93*top,max(.62*bottom,.82*caps));
    float side=q.x<0.?-1.:1.;vec2 a=q-vec2(9.*side,0.)-gaze;
    if(mode==1.&&side>0.)a.y-=1.;
    if(lid<.1)return max((mode==4.?.38:.75)*rim,.78*dialArc(a,3.,.55));
    float scan=mode==6.?dialRound(18.*turn):mode==5.?dialRound(12.*(1.-focus)):mode==2.?-12.:floor(38.*fract(t/5.75))-19.;
    float offset=scan-(q.x+floor(q.y*.48));
    float trail=step(0.,offset)*step(offset,2.)*(1.-.30*offset);
    float ink=max(rim,trail*(mode==6.?.66:mode==5.?.37:.20));
    float h=mode==7.?2.:mode==2.&&side>0.?1.55:mode==1.&&side>0.?3.25:2.8;
    float pupil=dialOval(a,vec2(3.0,max(.7,h*lid)));
    pupil*=1.-.84*scPixelBox(a-vec2(-1.,1.),vec2(.5));
    if(mode==5.){
        vec2 b=abs(q)-vec2(2.,2.);
        float target=max(scPixelBox(b+vec2(1.,0.),vec2(1.,.5)),scPixelBox(b+vec2(0.,1.),vec2(.5,1.)));
        ink=max(ink,.85*focus*target);
    }
    if(mode==7.){
        vec2 speed=vec2(x-17.,q.y+1.);
        ink=max(ink,.56*scPixelBox(speed,vec2(1.5,.5)));
    }
    return max(ink,pupil);
}
float scoutDialInk(vec2 cell,float mode,float age,vec2 look,float style){
    vec2 p=floor(cell)-vec2(31.,24.);if(abs(p.x)>26.||p.y< -12.||p.y>12.)return 0.;
    float t=max(0.,age),turn=mode==6.?dialSearch(t):0.;
    float blink=abs(mod(t+.67+.31*style,5.35)-.18);
    float lid=mode==4.?0.:blink<.052?0.:blink<.115?.45:1.;
    vec2 point=clamp(look,-1.,1.);float focus=smoothstep(.22,.69,fract(t/3.2));
    vec2 gaze=floor(point*vec2(2.,1.)+.5);
    if(mode==0.)gaze.x+=step(.65,fract(t/6.7))-step(.77,fract(t/6.7));
    if(mode==2.)gaze=vec2(dialRound(point.x+2.*(1.-2.*step(.5,fract(t/4.)))),1.);
    if(mode==5.)gaze=vec2(dialRound((1.-focus)*2.+point.x*.5),0.);
    if(mode==6.)gaze=vec2(dialRound(2.*turn+.5*point.x),dialRound(.5*point.y));
    if(mode==7.)gaze=vec2(dialRound(1.+point.x),-1.);
    if(mode==4.)gaze=vec2(0.);
    gaze=clamp(gaze,vec2(-2.,-1.),vec2(2.,1.));
    float ink=style<1.5?dialBinocular(p,mode,gaze,lid,focus,turn):style<2.5?dialWaypoint(p,mode,gaze,lid,focus,turn):dialSweep(p,mode,gaze,lid,focus,turn,t);
    return max(ink,dialMouth(p,mode,t,style));
}

// Independent luminance masks for Buddy's iris/lids, catchlights and cheeks/tongue.
vec3 scoutFriendlyMarks(vec2 cell,float mode,float age,vec2 look){
    vec2 p=floor(cell)-vec2(31.,24.);
    if(abs(p.x)>24.||p.y< -13.||p.y>15.)return vec3(0.);
    float side=p.x<0.?-1.:1.,t=max(0.,age);
    float turn=mode==6.?dialSearch(t):0.;
    float focus=mode==5.?smoothstep(.12,.68,fract(t/3.2)):0.;
    vec2 aim=clamp(look,-1.,1.)*vec2(1.6,1.1);
    float h=7.2,cy=1.8,brow=12.;
    if(mode==1.&&side>0.){h+=.7;cy+=.7;brow+=1.;}
    if(mode==2.){
        aim=vec2(1.8*(1.-2.*step(.55,fract(t/3.7))),1.1)+aim*.3;
        if(side<0.)brow+=1.;else h-=1.2;
    }
    if(mode==5.){aim=vec2(1.6*(1.-focus),-.8)+aim*.35;if(side<0.)h-=1.5*focus;}
    if(mode==6.){aim=vec2(2.*turn,.6)+aim*.35;brow+=step(.42,side*turn);}
    if(mode==7.){aim=vec2(1.6,-1.)+aim*.4;h-=.6;}
    aim=floor(clamp(aim,vec2(-2.,-1.),vec2(2.,1.))+.5);
    float blink=abs(mod(t+.79,5.35)-.15);
    float lid=mode==4.?0.:smoothstep(.038,.16,blink);
    vec2 eye=p-vec2(10.*side,dialRound(cy));
    float amber=0.,glint=0.;
    if(lid<.12){
        float y=mode==4.?-1.+floor(.36*abs(eye.x)):1.-floor(.32*abs(eye.x));
        amber=.82*step(abs(eye.x),4.)*step(abs(eye.y-y),.55);
    }else{
        h=max(1.7,h*lid);
        float outside=dialOval(eye,vec2(6.15,h+.15));
        vec2 pupil=eye-vec2(aim.x,aim.y*lid);
        float center=dialOval(pupil,vec2(3.72,max(.75,h-2.05)))*
                     dialOval(eye,vec2(5.08,max(.8,h-1.15)));
        amber=outside*(1.-center)*(.77+.23*smoothstep(-h,h,eye.y));
        if(h>3.4){
            vec2 k=pupil-vec2(-1.5,dialRound(.35*h));
            float shine=dialOval(k,vec2(1.52,1.53));
            float fleck=.70*scPixelBox(pupil-vec2(2.,-1.),vec2(.55));
            glint=outside*center*max(shine,fleck);
        }
    }
    if(mode!=4.){
        float by=brow+dialRound(.37*(2.6-abs(eye.x))-.15*side*eye.x);
        amber=max(amber,.86*step(abs(eye.x),3.5)*step(abs(p.y-by),.5));
    }
    vec2 cheek=vec2(abs(p.x)-20.,p.y+4.);
    float blush=dialOval(cheek,vec2(3.1,1.55))*(.76+.24*step(cheek.x,0.));
    if(mode==4.)blush*=.42;
    vec2 m=p-vec2(0.,-9.);
    if(mode==3.){
        float beat=.5+.5*sin(12.*t+sin(5.*t)),opening=1.9+floor(2.2*beat);
        float outer=dialOval(m,vec2(4.6,opening+.3));
        float inner=dialOval(m-vec2(0.,.35),vec2(2.85,max(.8,opening-1.)));
        amber=max(amber,outer*(1.-inner));
        blush=max(blush,.78*inner*step(m.y,-1.));
    }else if(mode==1.){
        amber=max(amber,.92*(dialOval(m,vec2(2.8,2.4))-dialOval(m,vec2(1.45,1.3))));
    }else{
        float width=mode==4.?2.:mode==2.?3.:mode==5.?3.:mode==7.?5.:4.;
        if(mode==2.)m.x-=1.;
        float bend=mode==2.?.085:.16;
        float y=dialRound(bend*m.x*m.x);
        float previous=max(abs(m.x)-1.,0.);
        float lower=dialRound(bend*previous*previous)+1.;
        if(mode==2.||mode==5.)y+=step(1.5,m.x);
        amber=max(amber,step(abs(m.x),width)*step(min(y,lower),m.y)*step(m.y,y));
    }
    return vec3(amber,glint,blush);
}

float objectCoverage=1.;
vec3 objectStudioMiss(vec3 rgb){objectCoverage=0.;return rgb;}
// Scout. Four sprung wheels carry a machined survey head and a tiny offset dish.
float scBox(vec3 p,vec3 h,float r) {
    vec3 d=abs(p)-h+r;return min(max(d.x,max(d.y,d.z)),0.)+length(max(d,0.))-r;
}
float scRect(vec2 p,vec2 h,float r) {
    vec2 d=abs(p)-h+r;return min(max(d.x,d.y),0.)+length(max(d,0.))-r;
}
float scSection(float a,float b,float r){
    vec2 d=vec2(a,b)+r;return length(max(d,0.))+min(max(d.x,d.y),0.)-r;
}
float scRod(vec3 p,vec3 a,vec3 b,float r) {
    vec3 d=b-a;return length((p-a)-d*clamp(dot(p-a,d)/dot(d,d),0.,1.))-r;
}
vec2 scAdd(vec2 a,float b,float id){return a.x<b?a:vec2(b,id);}
const float scGlass=.516;
const vec2 scCenter=vec2(0.,.155);
// Bolt-on survey chassis. The factory branches use their original, parked geometry.
bool scKitOn=false;
float scKitRoll=0.;
vec2 scKitYawCS=vec2(1.,0.);
float scKitSweepMask=0.;
const vec3 scKitAxis=vec3(-.405,.455,-.156);
float scKitFaceMode(float mode){return mode==6.?2.:mode==7.?0.:mode;}
float scKitSearchAngle(float age){
    float t=mod(max(age,0.),8.);
    return .94*smoothstep(.12,2.,t)-1.98*smoothstep(2.61,5.43,t)+1.04*smoothstep(6.20,7.90,t);
}
void scKitPose(float style,float mode,float age){
    scKitOn=style>.5;
    float yaw=scKitOn && mode==6.?scKitSearchAngle(age):0.;
    scKitYawCS=vec2(cos(yaw),sin(yaw));
    float angle=6.2831853*mod(max(age,0.),3.2)/3.2;
    scKitRoll=scKitOn && mode==7.?angle-.106*sin(angle):0.;
}
vec2 scKitRange(vec3 o,vec3 rd,vec3 h){
    vec3 safe=max(abs(rd),vec3(.000001))*vec3(rd.x<0.?-1.:1.,rd.y<0.?-1.:1.,rd.z<0.?-1.:1.);
    vec3 a=(-h-o)/safe,b=(h-o)/safe,lo=min(a,b),hi=max(a,b);
    return vec2(max(lo.x,max(lo.y,lo.z)),min(hi.x,min(hi.y,hi.z)));
}
vec2 scKitRayVolumes(vec3 ro,vec3 rd){
    vec2 d=scKitRange(ro-vec3(-.405,.736,-.156),rd,vec3(.279,.244,.279));
    vec2 w=scKitRange(ro-vec3(0.,-.471,0.),rd,vec3(.812,.309,.740));
    return vec2(d.x<d.y?1.:0.,w.x<w.y?1.:0.);
}
bool scKitMovingRay(vec3 ro,vec3 rd){return scKitOn && dot(scKitRayVolumes(ro,rd),vec2(1.))>.5;}
void scKitConstrainRay(vec3 ro,vec3 rd){
    vec2 volumes=scKitRayVolumes(ro,rd);
    if(volumes.x<.5)scKitYawCS=vec2(1.,0.);
    if(volumes.y<.5)scKitRoll=0.;
    scKitSweepMask=scKitOn&&max(volumes.x,volumes.y)>.5?.67:0.;
}
// Front and rear tires have mirrored mold coordinates. Equal axle rotation in
// world space therefore has opposite sign in their respective tread coordinates.
float scKitWheelAngle(vec3 p,float neutral){return neutral+(p.z<0.?-scKitRoll:scKitRoll);}
float scKitBore(float r,float a){
    float f=mod(a+.5235988,1.0471976)-.5235988;
    return length(r*vec2(cos(f),sin(f))-vec2(.105,0.))-.020;
}
vec2 scKitWheelInside(vec2 object,vec3 wheel,float radius){
    // The rim is a single molded insert. Its graphite backplate meets the axle
    // boot at the center; the bright, perforated outboard cover stays separate.
    float barrel=scSection(radius-.148,abs(wheel.x+.001)-.083,.014);
    object=scAdd(object,barrel,11.);
    float backplate=scSection(radius-.160,abs(wheel.x+.114)-.032,.017);
    object=scAdd(object,max(backplate,.043-radius),12.);
    float socket=scSection(radius-.068,abs(wheel.x+.142)-.019,.009);
    return scAdd(object,socket,12.);
}
vec2 scKitUndertray(vec2 object,vec3 p){
    float x=abs(p.x);
    // One radiused belly encloses the cross shafts and mounts. The shoulders
    // narrow gently toward the skid surface while the four wheels sit proud.
    float skirt=clamp((p.y+.503)/.259,0.,1.);
    float halfWidth=.424+.058*skirt;
    float halfLength=.497+.061*skirt;
    float pan=scBox(p-vec3(0.,-.349,-.008),vec3(halfWidth,.180,halfLength),.109);
    object=scAdd(object,pan,16.);
    float radius=length(vec2(p.y+.472,abs(p.z)-.431));
    // Four short shouldered rubber stubs reach into the backplates. Their
    // broad roots intersect the rounded pan even near the chamfered corners.
    float taper=smoothstep(.390,.505,x);
    float stub=scSection(radius-mix(.087,.052,taper),abs(x-.487)-.128,.017);
    return scAdd(object,stub,14.);
}
vec3 scKitDishPoint(vec3 p){
    vec3 d=p-scKitAxis;
    return scKitAxis+vec3(scKitYawCS.x*d.x-scKitYawCS.y*d.z,d.y,scKitYawCS.y*d.x+scKitYawCS.x*d.z);
}
vec3 scKitBowlLocal(vec3 p){
    vec3 off=p-vec3(-.410,.726,-.153),axis=normalize(vec3(-.43,.56,.71));
    vec3 ex=normalize(cross(vec3(0.,1.,0.),axis)),ey=cross(axis,ex);
    return vec3(dot(off,ex),dot(off,ey),dot(off,axis));
}
vec2 scKitDish(vec2 s,vec3 p){
    vec3 pivot=scKitAxis;
    s=scAdd(s,scBox(p-pivot,vec3(.085,.035,.067),.022),8.);
    vec3 foot=p-(pivot+vec3(0.,.038,0.));s=scAdd(s,scSection(length(foot.xz)-.056,abs(foot.y)-.025,.008),13.);
    // The mast foot is fixed; the upper mast, socket, bowl, lip, feed and index
    // flag share a single rotation about the y-axis through that sealed bearing.
    vec3 m=scKitDishPoint(p),joint=vec3(-.405,.682,-.177),center=vec3(-.410,.726,-.153);
    vec3 axis=normalize(vec3(-.43,.56,.71));
    s=scAdd(s,scRod(m,pivot+vec3(0.,.048,0.),joint,.030),5.);
    s=scAdd(s,scRod(m,joint,center-.018*axis,.031),11.);
    vec3 d=scKitBowlLocal(m);float r=length(d.xy),depth=.94*r*r;
    s=scAdd(s,scSection(r-.211,abs(d.z-depth)-.014,.008),10.);
    s=scAdd(s,length(vec2(r-.207,d.z-.040))-.012,5.);
    s=scAdd(s,scRod(d,vec3(0.,0.,.006),vec3(.019,-.016,.114),.013),8.);
    s=scAdd(s,length(d-vec3(.020,-.016,.117))-.026,9.);
    // One small graphite-backed enamel marker wraps the rolled lip, never faces the camera.
    vec3 tangential=vec3(.875*d.x+.484*d.y,-.484*d.x+.875*d.y,d.z);
    s=scAdd(s,scBox(tangential-vec3(.204,0.,.041),vec3(.019,.038,.017),.010),11.);
    s=scAdd(s,scBox(tangential-vec3(.213,0.,.044),vec3(.013,.027,.020),.007),15.);
    return s;
}

vec2 scScene(vec3 p) {
    float ax=abs(p.x);
    vec3 q=p-vec3(0.,.148,.020);
    // Narrower toward the roof and aft: an armored trapezoidal cover above the deck.
    float width=.662-.16*max(q.y,0.)-.12*max(-q.z-.18,0.);
    float housing=scBox(q,vec3(width,.326,.488),.084);
    // A chamfer intersects the upper casting at aft to give the roof a dropped heel.
    float aftRoof=(q.y-.467*q.z-.452)*.905;
    housing=max(housing,aftRoof);
    vec2 display=p.xy-scCenter;
    float well=max(scRect(display,vec2(.548,.242),.066),.365-p.z);
    housing=max(housing,-well);
    vec2 obj=vec2(housing,1.);
    if(p.z>.29) {
        float lip=scSection(scRect(display,vec2(.574,.267),.075),abs(p.z-.475)-.072,.025);
        lip=max(lip,-max(scRect(display,vec2(.503,.197),.048),.432-p.z));
        obj=scAdd(obj,lip,2.);
        float glass=scSection(scRect(display,vec2(.511,.205),.053),abs(p.z-.500)-.016,.008);
        obj=scAdd(obj,glass,3.);
    }
    // Four chevron-tread tires. Each tire has a recessed hub, formed side wall and axle.
    vec3 w=vec3(ax-.654,p.y+.472,abs(p.z)-.431);
    if(w.y<.39 && w.y>-.38 && ax>.35) {
        float r=length(w.yz);
        float angle=scKitWheelAngle(p,atan(w.y,w.z));
        float treadAngle=24.*angle+4.4*abs(w.x/.145);
        float notch=smoothstep(.06,.59,cos(treadAngle))*.012;
        float tire=scSection(r-.295+notch*smoothstep(.215,.257,r),abs(w.x)-.141,.045);
        tire=max(tire,-max(r-.169,.054-w.x));
        if(scKitOn){tire=max(tire,-max(r-.156,w.x+.064));tire=max(tire,.092-r);}
        obj=scAdd(obj,tire,4.);
        float hub=scSection(r-.160,abs(w.x-.098)-.035,.013);
        if(scKitOn){hub=max(hub,-scKitBore(r,angle));obj=scKitWheelInside(obj,w,r);}
        obj=scAdd(obj,hub,5.);
        float cap=scSection(r-.063,abs(w.x-.129)-.015,.008);
        obj=scAdd(obj,cap,6.);
    }
    if(p.y<-.102) {
        obj=scAdd(obj,scBox(p-vec3(0.,-.169,-.018),vec3(.605,.063,.630),.045),7.);
        if(scKitOn){
            obj=scKitUndertray(obj,p);
        }else{
            vec3 mirror=vec3(ax,p.y,abs(p.z));
            obj=scAdd(obj,scBox(p-vec3(0.,-.253,-.010),vec3(.425,.082,.522),.067),8.);
            obj=scAdd(obj,scRod(mirror,vec3(.595,-.474,.432),vec3(.419,-.248,.285),.045),6.);
            obj=scAdd(obj,scRod(mirror,vec3(.603,-.455,.419),vec3(.529,-.222,.015),.034),8.);
            float sill=scBox(vec3(ax-.531,p.y+.235,p.z),vec3(.055,.040,.50),.030);
            obj=scAdd(obj,sill,5.);
        }
        if(p.z>.39) {
            vec3 bumper=p-vec3(0.,-.232,.584);
            float hook=scSection(abs(length((bumper.xy)/vec2(1.5,1.))-.063)-.015,abs(bumper.z)-.025,.006);
            obj=scAdd(obj,hook,9.);
        }
    }
    // Asymmetrical folding dish. Inner bowl, rolled lip and central receiver share an axis.
    if(scKitOn && p.y>.35 && p.x<-.12) {
        obj=scKitDish(obj,p);
    }else if(p.y>.35 && p.x<-.12) {
        vec3 a=vec3(-.405,.455,-.156),b=vec3(-.405,.682,-.177);
        obj=scAdd(obj,scRod(p,a,b,.032),5.);
        obj=scAdd(obj,scBox(p-a,vec3(.085,.035,.067),.022),8.);
        vec3 center=vec3(-.410,.726,-.153);
        vec3 n=normalize(vec3(-.43,.56,.71));
        vec3 ex=normalize(cross(vec3(0.,1.,0.),n)),ey=cross(n,ex);
        vec3 t=p-center;
        vec3 d=vec3(dot(t,ex),dot(t,ey),dot(t,n));
        float r=length(d.xy),z=.94*r*r;
        float bowl=scSection(r-.211,abs(d.z-z)-.014,.008);
        obj=scAdd(obj,bowl,10.);
        obj=scAdd(obj,length(vec2(r-.207,d.z-.040))-.012,5.);
        obj=scAdd(obj,scRod(p,center+.005*n,center+.115*n,.013),8.);
        vec3 tip=p-(center+.117*n);
        obj=scAdd(obj,length(tip)-.026,9.);
    }
    return obj;
}
vec3 scNormal(vec3 p) {
    vec2 e=vec2(.00115,-.00115);
    return normalize(e.xyy*scScene(p+e.xyy).x+e.yyx*scScene(p+e.yyx).x+
                     e.yxy*scScene(p+e.yxy).x+e.xxx*scScene(p+e.xxx).x);
}
float scSq(float x){return x*x;}
float scDash(float d,float w){return 1.-smoothstep(w,w+.004,abs(d));}
vec3 scEnv(vec3 r) {
    float sky=.38+.25*smoothstep(-.51,.59,r.y);
    float flag=exp(-8.*scSq(r.x-.53)-3.*scSq(r.y-.07));
    float window=exp(-3.5*scSq(r.x+.54)-5.*scSq(r.y-.52));
    float strip=exp(-33.*scSq(r.x-.85)-2.*scSq(r.y-.29));
    float crown=exp(-18.*scSq(r.y-.83)-2.*scSq(r.x+.18));
    return vec3(.26,.29,.32)*sky-vec3(.117)*flag+vec3(1.25,1.11,.94)*window+
           vec3(.92,.99,1.10)*strip+vec3(.67,.74,.82)*crown;
}
float scBrush(vec3 p) {
    float a=p.y*1270.+p.z*156.+.8*sin(p.z*82.+p.x*18.);
    float micro=.36*sin(a)+.23*sin(a*.638+.7)+.13*sin(a*1.364+p.z*9.);
    float fine=clamp((uResolution.y-280.)/650.,.08,.85);
    return fine*micro+.20*sin(p.y*108.+p.z*9.)+.12*sin(p.y*171.+.5*sin(p.x*47.));
}
float scTick(float d){return 1.-smoothstep(.001,.006,abs(d));}
vec3 scKitChassisFinish(vec3 p,vec3 n,vec3 v,float id,vec3 metal,vec3 env,float key){
    float wx=abs(p.x)-.654;vec2 w=vec2(p.y+.472,abs(p.z)-.431);float r=length(w);
    float a=scKitWheelAngle(p,atan(w.x,w.y));
    if(id==10.){
        vec3 d=scKitBowlLocal(scKitDishPoint(p));float rad=length(d.xy);
        bool inside=d.z>.94*rad*rad;
        float rolled=scDash(rad-.171,.002);float grain=scDash(rad-.107,.001);
        if(inside)return metal*vec3(1.075,1.035,.96)*(.99-.12*rolled-.045*grain)+.030*env;
        float ribs=.5+.5*cos(3.*atan(d.y,d.x));float spine=smoothstep(.968,.999,ribs)*smoothstep(.033,.080,rad);
        return metal*vec3(.77,.84,.86)*(.84+.18*spine);
    }
    if(id==11.){
        vec3 graphite=vec3(.069,.085,.092)*(.65+.42*key)+.105*env;
        if(p.y<-.17&&wx<-.134&&abs(n.x)>.61)graphite*=1.-.38*scDash(r-.059,.0035);
        return graphite;
    }
    if(id==12.){
        // A fine bead is enough to describe the circular inner hub, with the
        // same dark finish around its face and outer radius.
        vec3 hub=vec3(.032,.039,.044)*(.71+.47*key)+.045*min(env,vec3(1.10));
        if(abs(n.x)>.54){
            hub*=1.-.21*scDash(r-.136,.0025);
            hub+=vec3(.007)*scDash(r-.140,.0021);
        }
        return hub;
    }
    if(id==13.)return vec3(.057,.075,.084)*(.70+.52*key)+.113*env;
    if(id==14.){
        float seat=scDash(abs(p.x)-.486,.0035);
        return vec3(.025,.031,.034)*(.76+.43*key)*(1.-.16*seat)+.023*min(env,vec3(1.10));
    }
    if(id==16.){
        float facing=clamp(dot(n,v),0.,1.);
        float seam=scDash(p.y+.275,.0025)*(1.-abs(n.y));
        vec3 carbon=vec3(.010,.013,.015)*(.77+.49*key)+.019*min(env,vec3(1.08));
        return carbon*(1.-.20*seam)+vec3(.010,.012,.013)*pow(1.-facing,4.);
    }
    return vec3(.79,.182,.029)*(.72+.47*key)+.095*env;
}

// A permanently bonded navigation display, printed in roof-local coordinates.
const vec3 scoutAmber=vec3(.99,.688,.297);
bool scoutRoofHit=false;
float roofWord(float column,float mode){
    vec4 letters; float last;
    if(mode==0.){letters=vec4(23275.,29391.,23530.,15211.);last=9389.;}
    else if(mode==1.){letters=vec4(29257.,29847.,31183.,9367.);last=24573.;}
    else if(mode==2.){letters=vec4(9367.,23533.,29847.,24573.);last=23277.;}
    else if(mode==3.){letters=vec4(31183.,4843.,29391.,23530.);last=23277.;}
    else if(mode==4.){letters=vec4(31183.,29257.,29391.,29391.);last=4843.;}
    else if(mode==5.){letters=vec4(9367.,31599.,31599.,29257.);last=31183.;}
    else if(mode==6.){letters=vec4(31183.,29263.,23530.,24573.);last=0.;}
    else{letters=vec4(15211.,23275.,29847.,11117.);last=29391.;}
    if(column<1.)return letters.x;if(column<2.)return letters.y;
    if(column<3.)return letters.z;if(column<4.)return letters.w;return last;
}
vec3 roofNavigation(vec2 s,vec3 v){
    float bezel=scRect(s,vec2(.351,.217),.039);
    if(bezel>-.009)return vec3(.095,.100,.104);
    if(bezel>-.019)return vec3(.022,.023,.024);
    vec2 q=vec2(-s.x,s.y);
    vec2 cell=floor((vec2(q.x,-q.y)-vec2(-.294,-.176))/.021);
    float light=0.;
    if(cell.x>=0.&&cell.x<19.&&cell.y>=0.&&cell.y<5.&&mod(cell.x,4.)<3.)
        light=mod(floor(roofWord(floor(cell.x/4.),uEvent)/exp2(mod(cell.x,4.)+3.*cell.y)),2.);
    vec2 map=q-vec2(-.066,-.083);
    if(abs(map.x)<.224&&abs(map.y)<.083){
        vec2 grid=abs(fract(map/.054+.5)-.5);
        light=max(light,.052*(1.-smoothstep(.02,.13,min(grid.x,grid.y))));
        float route=.027*sin(17.*map.x)+.014*sin(36.*map.x);
        float x=uEvent==7.?-.16+.32*fract(uSince/3.2):.087;
        vec2 marker=map-vec2(x,.027*sin(17.*x)+.014*sin(36.*x));
        light=max(light,max(.43*(1.-smoothstep(.002,.007,abs(map.y-route))),1.-smoothstep(.011,.019,length(marker))));
    }
    vec2 b=abs(q-vec2(.230,.127));
    float frame=max(b.x-.059,b.y-.031);
    light=max(light,.64*(1.-smoothstep(.002,.006,abs(frame))));
    if(b.x<.046&&b.y<.018)light=max(light,.86*step(.25,fract((q.x-.17)/.03)));
    return vec3(.009,.012,.015)+.017*pow(1.-abs(v.y),2.)+scoutAmber*light;
}
vec3 scHousing(vec3 p,vec3 n,vec3 v,float id) {
    vec3 light=normalize(vec3(-.51,.90,.68));
    float key=max(dot(n,light),0.), facing=clamp(dot(n,v),0.,1.);
    vec3 ref=reflect(-v,n);
    vec3 env=scEnv(ref);
    float brush=scBrush(p);
    float ao=.76+.24*smoothstep(-.21,.0,p.y);
    vec3 metal=(vec3(.217,.243,.260)*(.60+.69*key)+vec3(.58,.62,.66)*env*(.79+.075*brush))*ao;
    metal+=vec3(.022,.021,.020)*(.5+brush);
    if(scKitOn&&id>=10.)return scKitChassisFinish(p,n,v,id,metal,env,key);
    if(id<1.5) {
        // Lightning-bolt calibration mark and recessed cooling louvers on the cheeks.
        if(abs(n.x)>.60) {
            vec2 s=vec2(p.z,p.y);
            float panel=scRect(s-vec2(-.018,.139),vec2(.312,.205),.046);
            metal*=1.-.42*scDash(panel,.002);
            if(s.x<.189 && s.x>-.29 && s.y>-.003 && s.y<.21) {
                float k=floor((s.x+.229)/.077+.5);
                vec2 l=s-vec2(-.229+k*.077,.092);
                l.x+=.33*l.y;
                float hole=scRect(l,vec2(.014,.073),.012);
                metal*=1.-.76*(1.-smoothstep(-.002,.003,hole));
                metal+=vec3(.081)*scTick(hole-.007);
            }
            vec2 badge=s-vec2(.103,.276);
            float mark=scRect(badge,vec2(.105,.017),.007);
            metal=mix(metal,vec3(.76,.134,.023)*(.6+.45*key),1.-smoothstep(-.002,.003,mark));
        }
        if(n.y>.75) {
            vec2 s=vec2(p.x,p.z+.095);
            s.x-=.098;
            if(scRect(s,vec2(.351,.217),.039)<0.){
                scoutRoofHit=true;
                return roofNavigation(s,v);
            }
            vec2 screw=vec2(abs(p.x)-.485,abs(p.z+.005)-.305);
            float rad=length(screw);metal*=1.-.57*scDash(rad-.022,.002);
            metal*=1.-.62*scDash(screw.x+.5*screw.y,.002)*(1.-smoothstep(.014,.018,rad));
        }
        if(n.z<-.65) {
            vec2 s=p.xy-vec2(0.,.146);
            float door=scRect(s,vec2(.465,.209),.052);
            metal*=1.-.51*scDash(door,.003);
            if(abs(s.x)<.299 && abs(s.y)<.131){
                vec2 uv=s-vec2(0.,.016);
                float line=floor((uv.y+.084)/.043+.5);
                float vent=scRect(uv-vec2(0.,-.084+.043*line),vec2(.261,.009),.006);
                metal*=1.-.69*(1.-smoothstep(-.002,.002,vent));
            }
            vec2 tailLamp=s-vec2(sign(s.x)*.369,-.147);
            float tape=scRect(tailLamp,vec2(.034,.012),.006);
            metal=mix(metal,vec3(.78,.125,.035),1.-smoothstep(-.001,.003,tape));
            vec2 screw=abs(s)-vec2(.392,.142);float r=length(screw);
            metal*=1.-.48*scDash(r-.022,.002);
            metal*=1.-.54*scDash(screw.x-screw.y,.002)*(1.-smoothstep(.012,.017,r));
        }
        return metal;
    }
    if(id<2.5) {
        vec2 s=p.xy-scCenter;
        float trim=scRect(s,vec2(.549,.242),.061);
        vec3 frame=vec3(.041,.052,.065)*(.6+.43*key)+.080*env;
        if(n.z>.45){
            frame+=vec3(.063,.057,.047)*scDash(trim,.0015);
            vec2 bolt=abs(s)-vec2(.532,.215);
            float r=length(bolt);
            frame=mix(frame,metal*.62,1.-smoothstep(.012,.017,r));
        }
        return frame;
    }
    if(id<3.5)return vec3(.024,.034,.038)+.18*env;
    if(id<4.5) {
        vec2 w=vec2(p.y+.472,abs(p.z)-.431);
        float r=length(w),a=scKitWheelAngle(p,atan(w.x,w.y));
        float rim=abs(p.x)-.654;
        float striation=.54+.46*cos(24.*a+4.4*abs(rim/.145));
        vec3 color=vec3(.021,.026,.029)*(.80+.59*key)+vec3(.017)*env;
        color*=.89+.11*striation;
        if(rim>.095) {
           color*=1.-.28*scDash(r-.212,.004);
           color+=vec3(.010)*scDash(r-.234,.001);
           if(scKitOn){float dotMark=length(r*vec2(cos(a-.81),sin(a-.81))-vec2(.220,0.));
               color=mix(color,vec3(.40,.304,.169)*(.62+.45*key),1.-smoothstep(.009,.013,dotMark));}
        }
        if(scKitOn){
            // A small light-grey witness molded into one shoulder block and a
            // second worn block show travel when the rim is seen exactly edge-on.
            float shoulder=smoothstep(-.099,-.058,rim)*(1.-smoothstep(.071,.101,rim))*smoothstep(.258,.282,r);
            float stripe=a+.12*abs(rim/.145)-.51-(p.x<0.?.56:0.);
            float witness=1.-smoothstep(.032,.065,abs(sin(.5*stripe)));
            float wear=1.-smoothstep(.026,.061,abs(sin(.5*(stripe+1.91))));
            color=mix(color,vec3(.132,.137,.119)*(.66+.46*key),shoulder*witness*.78);
            color=mix(color,vec3(.069,.077,.077)*(.64+.45*key),shoulder*wear*.63);
        }
        return color;
    }
    if(id<5.5) {
        if(abs(p.x)>.710 && p.y<-.18) {
          vec2 w=vec2(p.y+.472,abs(p.z)-.431);float r=length(w);
          float a=scKitWheelAngle(p,atan(w.x,w.y));
          float holes=length(vec2(r-.104,sin(a*3.)*.115))-.019;
          metal=mix(metal,vec3(.034,.040,.041),1.-smoothstep(-.002,.003,holes));
          metal*=1.-.34*scDash(r-.142,.002);
          if(scKitOn){
              float index=(1.-smoothstep(.013,.017,abs(r-.116)))*smoothstep(.928,.974,cos(a-.82));
              metal=mix(metal,vec3(.92,.209,.035)*(.72+.5*key)+.06*env,index);
          }
        }
        return metal*.85;
    }
    if(id<6.5)return metal*.5+vec3(.024);
    if(id<7.5)return vec3(.102,.121,.136)*(.59+.67*key)+.26*env;
    if(id<8.5)return vec3(.030,.039,.047)*(.63+.52*key)+.060*env;
    if(id<9.5)return vec3(.907,.124,.013)*(.56+.66*key)+.074*env;
    return metal*vec3(1.08,1.00,.88)+vec3(.055)*pow(1.-facing,3.);
}
// Each design drives one amber phosphor beneath the same inset cover glass.
float scoutLcdInk(vec2 cell,float age,vec2 look){
    if(uFinish<.5)return scoutOriginalInk(cell,uEvent,age,look);
    if(uFinish>3.5){
        vec3 marks=scoutFriendlyMarks(cell,uEvent,age,look);
        return max(.88*marks.r,max(marks.g,.45*marks.b));
    }
    return scoutDialInk(cell,uEvent,age,look,uFinish);
}
float scGridInt(float x){return floor(x)*.085+min(fract(x),.085);}
vec3 scLCD(vec3 p,vec3 v,float mode,float age,vec2 look) {
    vec2 s=p.xy-scCenter,inner=s-v.xy*.009/max(v.z,.27);
    vec2 g=inner/.0145+vec2(32.,24.);
    vec2 h=clamp((500./max(1.,uResolution.y))*vec2(.17,.16)/vec2(max(v.z,.44),1.),vec2(.055),vec2(.47));
    vec2 gaps=vec2(scGridInt(g.x+h.x+.0425)-scGridInt(g.x-h.x+.0425),
                   scGridInt(g.y+h.y+.0425)-scGridInt(g.y-h.y+.0425))/(2.*h);
    float aperture=(1.-gaps.x)*(1.-gaps.y);
    vec3 ff=reflect(-v,normalize(vec3(s.x*.54,s.y*.84,1.)));
    float card=.009+.049*smoothstep(.12,.87,ff.y-.13*ff.x);
    vec3 glass=vec3(.0106,.0122,.0162)*(.94+.06*aperture)+card*scEnv(ff);
    vec2 cell=floor(g),offset=fract(g)-.5;
    if(abs(cell.x-31.)>29.||abs(cell.y-24.)>18.)return glass;
    // Area-filter the emitters. Their local scatter follows the real lit cells
    // in panel space, inside the gasket, even at oblique viewing angles.
    float direct=0.,scatter=0.;
    for(int y=-2;y<=2;y++)for(int x=-2;x<=2;x++){
        vec2 tap=vec2(float(x),float(y)),delta=tap-offset;
        float r2=dot(delta,delta);
        if(r2<4.8){
            float ink=scoutLcdInk(cell+tap,age,look);
            vec2 cover=clamp((vec2(.5)+h-abs(delta))/(2.*h),0.,1.);
            direct+=ink*cover.x*cover.y;
            scatter+=ink*exp2(-1.14*r2)*(1.-smoothstep(3.,4.8,r2));
        }
    }
    vec2 glyph=g-vec2(31.5,24.5);
    if(uFinish<.5&&(uEvent==0.||uEvent==6.||uEvent==7.)&&abs(glyph.x)<7.&&glyph.y< -6.){
        float d=scoutSmileDistance(glyph,uEvent),aa=max(.12,.78*max(h.x,h.y));
        direct=max(direct,1.-smoothstep(.39-aa,.39+aa,d));
        scatter+=exp2(-1.63*d*d);
    }
    float emission=(.89+.11*aperture)*direct+.041*scatter*(1.-.65*direct);
    emission*=uEvent==4.?.68:1.;
    return glass+scoutAmber*emission;
}
bool pipGlassHit=false;
void scCamera(vec2 uv,vec2 orbit,out vec3 ro,out vec3 rd) {
    float yaw=.49+orbit.x,pitch=.161+orbit.y;
    vec3 eye=vec3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch));
    vec3 right=normalize(cross(vec3(0.,1.,0.),eye)),up=cross(eye,right);
    ro=eye*5.8+vec3(0.,.053,0.);
    rd=normalize(-eye+(uv.x*right+uv.y*up)*.410);
}
vec3 pcOverlay(vec2 uv,vec2 orbit,float mode,float age,vec2 look) {
    vec3 ro,rd;scCamera(uv,orbit,ro,rd);
    vec3 p=ro+rd*((scGlass-ro.z)/rd.z);
    return pow(max(scLCD(p,-rd,mode,age,look),0.),vec3(.45455));
}
vec3 pcHousing(vec2 uv,float mode,float age,float t,vec2 orbit,vec2 look) {
    vec3 ro,rd;scCamera(uv,orbit,ro,rd);scKitConstrainRay(ro,rd);
    vec3 col=mix(vec3(.900,.891,.858),vec3(.953,.941,.906),clamp(.39-uv.y*.5-uv.x*.19,0.,1.));
    if(rd.y<-.008) {
        float g=(-.767-ro.y)/rd.y;
        if(g>0.){
            vec2 xy=(ro+g*rd).xz;
            vec2 patch=vec2(abs(xy.x)-.648,abs(xy.y)-.428)/vec2(.19,.14);
            vec2 shade=(xy-vec2(.16,-.09))/vec2(.78,.58);
            col*=1.-.38*exp(-dot(patch,patch))-.22*exp(-dot(shade,shade)*.94);
        }
    }
    float c=dot(ro,rd),disc=c*c-dot(ro,ro)+1.225*1.225;
    if(disc<0.)return objectStudioMiss(col);
    float d=-c-sqrt(disc),farD=-c+sqrt(disc);vec2 h=vec2(1.);
    for(int i=0;i<83;i++){
        h=scScene(ro+rd*d);
        if(h.x<.00072||d>farD)break;
        d+=max(.00049,h.x*.70);
    }
    if(d>farD||h.x>.0021)return objectStudioMiss(col);
    vec3 p=ro+rd*d,n=scNormal(p),v=-rd;
    vec3 linear;
    if(h.y==3. && n.z>.94) {
        pipGlassHit=true;
        linear=scLCD(p+v*((scGlass-p.z)/v.z),v,mode,age,look);
    } else linear=scHousing(p,n,v,h.y);
    return clamp(pow(max(linear,vec3(0.)),vec3(.45455)),0.,1.);
}

#ifndef SCOUT_KIT_STYLE
#define SCOUT_KIT_STYLE 1.
#endif
#ifndef SCOUT_KIT_EXTERNAL_MASK
#define PC_MASK_ALPHA max(scKitSweepMask,(pipGlassHit?1.:0.))
#define PC_DRAW_DYNAMIC(mark,mode,age) ((mark)>.9 || (mode)==6. || (mode)==7.)
#endif
// Keep the chosen expression separate from this housing's mechanical drive.
vec3 pipLiveLCD(vec2 uv,vec2 orbit,float mode,float age,vec2 look){
    scKitPose(SCOUT_KIT_STYLE,mode,age);
    float face=scKitFaceMode(mode);pcExpression=face;
    if(mode==6.||mode==7.)return pcHousing(uv,face,age,age,orbit,look);
    return pcOverlay(uv,orbit,(face==5.?2.:face),age,look);
}
vec3 renderBot(vec2 uv,float mode,float age,float t,vec2 orbit,vec2 look){
    scKitPose(SCOUT_KIT_STYLE,mode,age);
    float face=scKitFaceMode(mode);pcExpression=face;
    return pcHousing(uv,(face==5.?2.:face),age,t,orbit,look);
}

// Bolt-on optical assemblies. Scout faces +Z; lamp origins are the glass apices.
vec3 headOrigin(float style,float side) {
    if(style<1.5)return vec3(side*.433,-.204,.734);
    if(style<2.5)return vec3(side*.237,.509,.536);
    return vec3(side*.736,.082,.614);
}

vec3 hwAxis(float style) {
    if(style<1.5)return normalize(vec3(.09,-.23,1.));
    if(style<2.5)return normalize(vec3(0.,-.18,1.));
    return normalize(vec3(.045,-.12,1.));
}
vec3 hwPartFrame(vec3 p,float style) {
    vec3 a=hwAxis(style),ex=normalize(vec3(a.z,0.,-a.x)),ey=cross(a,ex);
    vec3 origin=headOrigin(style,1.);
    if(style>1.5&&style<2.5)origin.x=0.;
    vec3 q=p-origin;
    return vec3(dot(q,ex),dot(q,ey),dot(q,a));
}
float hwDome(vec3 q,float aperture,float sphereRadius,float depth) {
    float sphere=length(q+vec3(0.,0.,sphereRadius))-sphereRadius;
    return max(max(sphere,length(q.xy)-aperture),-depth-q.z);
}
float hwShoulderProfile(vec2 p) {
    return max(scRect(p,vec2(.125,.105),.018),(abs(p.x)+abs(p.y)-.196)*.707107);
}
vec2 headParts(vec3 p,float style) {
    if(style<.5)return vec2(12.,20.);
    vec3 m=vec3(abs(p.x),p.yz);
    if(style<1.5) {
        float guard=scBox(m-vec3(.433,-.196,.643),vec3(.158,.152,.155),0.);
        if(guard>.045)return vec2(guard,20.);
        vec3 q=hwPartFrame(m,style);
        float r=length(q.xy);
        float shellRadius=mix(.075,.120,smoothstep(-.161,-.058,q.z));
        vec2 part=vec2(scSection(r-shellRadius,abs(q.z+.090)-.076,.013),20.);
        // The steel band crimps the pressed glass to its tapered rear cup.
        float band=scSection(abs(r-.1115)-.0125,abs(q.z+.011)-.022,.005);
        part=scAdd(part,band,21.);
        part=scAdd(part,hwDome(q,.103,.309,.027),22.);
        // Swivel foot bolted through the existing bumper shelf.
        float foot=scBox(m-vec3(.429,-.194,.604),vec3(.070,.039,.061),.013);
        part=scAdd(part,foot,23.);
        return part;
    }
    if(style<2.5) {
        float guard=scBox(p-vec3(0.,.491,.455),vec3(.55,.088,.134),0.);
        if(guard>.045)return vec2(guard,20.);
        vec3 q=hwPartFrame(p,style);
        float shell=scBox(q-vec3(0.,0.,-.048),vec3(.518,.051,.064),.017);
        float slot=scRect(q.xy,vec2(.469,.029),.012);
        shell=max(shell,-max(slot,-.040-q.z));
        vec2 part=vec2(shell,24.);
        float lens=scSection(scRect(q.xy,vec2(.471,.031),.012),abs(q.z+.014)-.014,.005);
        part=scAdd(part,lens,25.);
        // Two feet sink into the cast roof. Space between them reads in profile.
        float foot=scBox(m-vec3(.396,.455,.425),vec3(.047,.037,.059),.010);
        part=scAdd(part,foot,23.);
        return part;
    }
    float guard=scBox(m-vec3(.697,.085,.483),vec3(.202,.140,.202),0.);
    if(guard>.045)return vec2(guard,20.);
    vec3 q=hwPartFrame(m,style);
    float r=length(q.xy);
    // Pocket the chamfered shroud; the bore and bezel stay ahead of the convex optic.
    float shell=scSection(hwShoulderProfile(q.xy),abs(q.z+.068)-.102,.011);
    shell=max(shell,-max(r-.086,-.087-q.z));
    vec2 part=vec2(shell,26.);
    float retainer=scSection(abs(r-.076)-.011,abs(q.z+.028)-.027,.005);
    part=scAdd(part,retainer,27.);
    part=scAdd(part,hwDome(q,.068,.112,.032),28.);
    // A yoke shoulders into the side casting, behind the opening.
    float mount=scBox(m-vec3(.657,.071,.431),vec3(.098,.056,.079),.014);
    part=scAdd(part,mount,23.);
    return part;
}
float hwLine(float d,float radius) {return 1.-smoothstep(radius,radius+.004,abs(d));}
float hwSpot(vec2 p,vec2 center,vec2 radii) {
    vec2 a=(p-center)/radii;
    return exp(-dot(a,a));
}
vec3 headFinish(vec3 p,vec3 n,vec3 v,float id,float style,float power) {
    vec3 m=vec3(abs(p.x),p.yz);
    vec3 q=hwPartFrame(style>1.5&&style<2.5?p:m,style);
    vec3 vm=style>1.5&&style<2.5?v:vec3(v.x*(p.x<0.?-1.:1.),v.yz);
    vec3 a=hwAxis(style),ex=normalize(vec3(a.z,0.,-a.x)),ey=cross(a,ex);
    vec3 eye=vec3(dot(vm,ex),dot(vm,ey),dot(vm,a));
    float light=max(0.,dot(n,normalize(vec3(-.51,.90,.68))));
    vec3 reflected=scEnv(reflect(-v,n));
    float rim=pow(1.-clamp(dot(n,v),0.,1.),3.);
    vec3 dark=vec3(.038,.049,.058)*(.57+.72*light)+reflected*(.074+.085*rim);
    vec3 nickel=vec3(.091,.098,.101)*(.64+.48*light)+reflected*vec3(.61,.66,.70);
    if(id<20.5) {
        float fin=hwLine(q.z+.067,.002)+hwLine(q.z+.091,.002);
        return dark*(1.-.37*clamp(fin,0.,1.));
    }
    if(id<21.5) {
        vec2 lug=vec2(abs(q.x)-.084,abs(q.y)-.073);
        float stud=1.-smoothstep(.005,.008,length(lug));
        return mix(nickel,dark*.67,stud);
    }
    if(id<22.5) {
        // Pressed flutes refract alternate strips of the silvered parabola.
        vec2 d=q.xy/.103;
        vec2 parallax=d-.17*eye.xy/max(eye.z,.32);
        float r=length(d),b=length(parallax);
        float groove=sin(parallax.x*27.+1.7*parallax.y*parallax.y);
        float flank=smoothstep(-.66,.84,groove);
        float ridge=pow(max(0.,groove),8.);
        float bowl=.18+.46*(1.-smoothstep(.18,1.17,b))+.30*flank;
        float ring=hwLine(r-.89,.012);
        vec3 cold=vec3(.18,.116,.060)*(.31+.89*bowl)+reflected*(.12+.19*ridge+.17*rim);
        cold+=vec3(.104,.073,.037)*ring;
        float filament=hwSpot(parallax,vec2(0.,-.07),vec2(.33,.14));
        float hot=(.24+.69*bowl+.14*ridge)*(1.-.28*smoothstep(.79,1.,r));
        return cold+power*(vec3(1.36,.686,.244)*hot+vec3(.80,.71,.54)*filament);
    }
    if(id<23.5)return dark*.80+.18*nickel;
    if(id<24.5) {
        if(eye.z>0.&&q.z>-.007) {
            vec2 screw=vec2(abs(q.x)-.491,q.y);
            return mix(dark, .54*nickel,hwLine(length(screw)-.010,.002));
        }
        float fin=hwLine(q.z+.038,.002)+hwLine(q.z+.068,.002);
        return dark*(1.-.34*clamp(fin,0.,1.));
    }
    if(id<25.5) {
        // Eight individual optic cups behind one continuous clear cover.
        float cell=fract((q.x+.464)/.116)-.5;
        float seam=smoothstep(.405,.494,abs(cell));
        float y=q.y/.030;
        float optic=1.-smoothstep(.12,1.07,length(vec2(cell*1.40,y*.80)));
        float crease=.5+.5*cos(cell*21.+y*1.5);
        float guide=exp(-12.*(y+.05)*(y+.05));
        vec3 cold=mix(vec3(.053,.072,.086),vec3(.172,.215,.241),.72*optic+.22*crease);
        cold+=reflected*(.13+.22*rim);
        vec3 lit=vec3(.77,.96,1.15)*(.31+.55*optic+.17*guide+.10*crease);
        return mix(cold+power*lit,dark+.026+power*vec3(.24,.31,.37),seam*.89);
    }
    if(id<26.5) {
        float front=smoothstep(-.02,.024,q.z);
        vec2 screw=abs(q.xy)-vec2(.098,.078);
        float socket=1.-smoothstep(.006,.011,length(screw));
        float flash=hwLine(length(screw)-.010,.001);
        float rib=hwLine(q.z+.057,.003)+hwLine(q.z+.089,.003)+hwLine(q.z+.120,.003);
        vec3 parkerized=dark*vec3(.86,.93,1.04)*(1.-.36*clamp(rib,0.,1.));
        return mix(parkerized,vec3(.019)+.23*nickel*flash,front*socket);
    }
    if(id<27.5)return nickel*vec3(.47,.56,.63);
    // Aspheric projector: a focused pupil behind a thick, slightly blue-coated dome.
    vec2 d=q.xy/.068;
    vec2 pupil=d-.24*eye.xy/max(eye.z,.33);
    float r=length(d),pr=length(pupil);
    float pupilCore=exp(-3.7*pr*pr);
    float ring=exp(-120.*(pr-.60)*(pr-.60));
    float glint=hwSpot(d,vec2(-.32,.36),vec2(.23,.115));
    vec3 cold=vec3(.019,.044,.062)+reflected*(.14+.44*rim);
    cold+=vec3(.040,.084,.115)*ring+vec3(.18,.26,.30)*glint;
    return cold+power*(vec3(1.68,1.94,2.10)*pupilCore+
        vec3(.28,.53,.67)*(.32+.59*ring)*(1.-smoothstep(.79,1.,r)));
}

uniform float uStyle;
// The gallery drives this pose from the current action. The field kit has a manual hinge.
float kitLift=1.;

// Scout's flush headlamp hatch. All moving parts share one transverse pin.
// Each local point follows a circle about the fixed axle throughout the stroke.
const vec3 liftHinge=vec3(0.,.471,.278);
const float liftLensSpan=.074;
const float liftLensDepth=.0315;
vec2 liftSinCos(){
    float angle=1.48352986*smoothstep(0.,1.,kitLift);
    return vec2(sin(angle),cos(angle));
}
vec3 liftLampAxis(){
    vec2 sc=liftSinCos();
    // The cups aim 5.2 degrees below the front of the 85-degree lid at its stop.
    return vec3(0.,vec2(-sc.y,sc.x)*.9958741-vec2(sc.x,sc.y)*.0907460);
}
vec3 liftLampOrigin(float side){
    vec2 sc=liftSinCos();
    vec2 up=vec2(sc.x,sc.y),front=vec2(-sc.y,sc.x);
    return vec3(.237*side,liftHinge.yz+liftLensSpan*up+liftLensDepth*front);
}
float liftLampGain(){
    // Moving the lid off its upright stop opens the lamp switch.
    return smoothstep(.74,.97,kitLift);
}
vec3 liftLampReferenceDirection(vec3 world){
    vec3 axis=liftLampAxis(),reference=hwAxis(2.);
    float up=dot(world.yz,vec2(axis.z,-axis.y));
    return vec3(world.x,up*vec2(reference.z,-reference.y)+dot(world,axis)*reference.yz);
}
// Carve the pocket only into the stock magnesium roof. Its floor and walls
// carry a separate graphite liner finish, independent of the painted shell.
vec2 liftLampDeck(vec2 stock,vec3 p){
    if(stock.y!=1.)return stock;
    float outline=scRect(vec2(p.x,p.z-.345),vec2(.513,.079),.012);
    float cutter=max(outline,.431-p.y);
    return -cutter>stock.x?vec2(-cutter,43.):stock;
}
float liftAxialPin(vec2 radial,float x,float halfLength,float radius){
    return scSection(length(radial)-radius,abs(x)-halfLength,.002);
}
vec2 liftLampMap(vec3 p){
    // Includes the entire rigid sweep, pivots, and two stationary hinge blocks.
    float gate=scBox(p-vec3(0.,.522,.346),vec3(.516,.099,.085),0.);
    if(gate>.035)return vec2(gate,42.);
    vec2 sc=liftSinCos(),delta=p.yz-liftHinge.yz;
    vec2 along=vec2(sc.x,sc.y),front=vec2(-sc.y,sc.x);
    float u=dot(delta,along),w=dot(delta,front),mx=abs(p.x);

    // A single enameled outer stamping overlaps the integrated black front
    // bezel. Its exterior is up when parked and faces rearward when upright.
    float cap=scBox(vec3(p.x,u-.071,w-.0007),vec3(.506,.068,.0054),.0043);
    vec2 hit=vec2(cap,47.);
    vec3 q=vec3(p.x,u-liftLensSpan,w);
    float bezel=scBox(q-vec3(0.,0.,.0185),vec3(.500,.0555,.0168),.0075);
    float slot=scRect(q.xy,vec2(.469,.029),.011);
    bezel=max(bezel,-max(slot,.020-w));
    hit=scAdd(hit,bezel,40.);
    float glass=scSection(scRect(q.xy,vec2(.471,.031),.012),abs(w-.0275)-.0040,.0027);
    hit=scAdd(hit,glass,41.);

    // Alternating knuckles sit directly on the axle. The rotating half is
    // crimped into the hatch's back edge. Both fixed leaves reach the pocket floor.
    float axle=liftAxialPin(delta,p.x,.452,.0058);
    hit=scAdd(hit,axle,45.);
    float moving=liftAxialPin(delta,mx-.348,.045,.0102);
    float fold=scBox(vec3(mx-.348,u-.009,w-.0032),vec3(.045,.014,.0063),.003);
    hit=scAdd(hit,min(moving,fold),42.);
    float fixedBarrel=liftAxialPin(delta,mx-.419,.024,.0102);
    vec3 foot=vec3(mx-.419,p.y-.449,p.z-.279);
    float fixedLeaf=scBox(foot,vec3(.025,.023,.011),.003);
    hit=scAdd(hit,min(fixedBarrel,fixedLeaf),42.);
    return hit;
}
// n and view point outward in world space. power already includes the end switch.
vec3 liftLampSurface(vec3 p,vec3 n,vec3 view,float id,float power){
    float key=max(0.,dot(n,normalize(vec3(-.51,.90,.68))));
    vec3 env=scEnv(reflect(-view,n));
    if(id==47.){
        // The paint selector applies the current body finish to this same skin.
        // Keep factory metal in phase with the adjoining deck when closed.
        float brush=scBrush(p);
        return vec3(.217,.243,.260)*(.60+.69*key)+vec3(.58,.62,.66)*env*(.79+.075*brush)
             +vec3(.022,.021,.020)*(.5+brush);
    }
    if(id<41.5){
        vec2 sc=liftSinCos(),d=p.yz-liftHinge.yz;
        float u=dot(d,sc),w=dot(d,vec2(-sc.y,sc.x));
        vec3 a=hwAxis(2.);
        vec3 virtualPoint=vec3(p.x,vec2(.509,.536)+(u-liftLensSpan)*vec2(a.z,-a.y)
                               +3.*(w-liftLensDepth)*a.yz);
        return headFinish(virtualPoint,n,view,id<40.5?24.:25.,2.,power);
    }
    float rim=pow(1.-clamp(dot(n,view),0.,1.),3.);
    if(id==43.)return vec3(.029,.035,.040)*(.72+.40*key)+env*(.04+.04*rim);
    if(id==45.)return vec3(.140,.157,.173)*(.54+.48*key)+env*vec3(.32,.37,.42);
    return vec3(.065,.074,.080)*(.63+.48*key)+env*(.16+.065*rim);
}

// Scout's painted shell and the back of the low folding headlamp. All colors
// are linear. Pass the original material before stage tint or headlight bounce.
float kitPaintCard(vec3 ray,vec3 direction,vec2 size,float softness) {
    vec3 across=normalize(vec3(direction.z,0.,-direction.x));
    vec3 up=cross(direction,across);
    float depth=dot(ray,direction);
    vec2 edge=size*depth-abs(vec2(dot(ray,across),dot(ray,up)));
    return smoothstep(-softness,softness,min(edge.x,edge.y));
}
// Nearby studio cards shift in the reflection even across a planar roof.
float kitPaintPanel(vec3 p,vec3 ray,vec3 center,vec2 size,float softness) {
    vec3 direction=normalize(center),across=normalize(vec3(direction.z,0.,-direction.x));
    float aim=dot(ray,direction);
    vec3 hit=p+ray*(dot(center-p,direction)/max(.05,aim))-center;
    vec2 edge=size-abs(vec2(dot(hit,across),dot(hit,cross(direction,across))));
    return smoothstep(.05,.22,aim)*smoothstep(-softness,softness,min(edge.x,edge.y));
}
float kitPaintHash(vec3 cell) {
    cell=fract(cell*vec3(.1031,.11369,.13787));
    cell+=dot(cell,cell.yzx+19.19);
    return fract((cell.x+cell.y)*cell.z);
}
// Convert the stock material's actual stamped seams, screw slots and vents to
// relative relief. This keeps the original geometry's markings in the paint.
float kitPaintRelief(vec3 p,float key,vec3 environment,vec3 stock) {
    float brush=scBrush(p);
    vec3 titanium=vec3(.217,.243,.260)*(.60+.69*key)+vec3(.58,.62,.66)*environment*(.79+.075*brush);
    titanium=titanium*(.76+.24*smoothstep(-.21,0.,p.y))+vec3(.022,.021,.020)*(.5+brush);
    vec3 lum=vec3(.2126,.7152,.0722);
    return clamp(dot(stock,lum)/max(.025,dot(titanium,lum)),.10,1.30);
}
vec3 kitPaintFinish(vec3 p,vec3 n,vec3 v,float id,vec3 stock,float paint) {
    if(scoutRoofHit||paint<.5||(id!=1.&&id!=47.))return stock;
    bool shell=id==1.,ivory=paint>1.5&&paint<2.5,blue=paint>=2.5;
    vec3 reflection=reflect(-v,n),environment=scEnv(reflection);
    float key=max(dot(n,normalize(vec3(-.51,.90,.68))),0.);
    float facing=clamp(dot(n,v),0.,1.),edge=1.-facing;
    float diffuse=(.38+.14*(n.y*.5+.5)+.64*key+.065*max(dot(n,normalize(vec3(.70,.42,-.69))),0.))
                 *(.87+.13*smoothstep(-.21,.04,p.y));
    diffuse*=mix(ivory?.94:.72,1.,smoothstep(-.16,.43,p.y));
    vec3 pigment=ivory?vec3(.885,.804,.638):blue?vec3(.009,.065,.54):vec3(.74,.015,.018);
    float rough=ivory?.142:blue?.057:.036;
    float first=kitPaintCard(reflection,normalize(vec3(-.82,.68,.44)),vec2(.56,.22),rough);
    float rail=kitPaintPanel(p,reflection,vec3(-.78,1.41,-2.24),vec2(.80,.16),rough*3.8);
    float side=kitPaintPanel(p,reflection,vec3(1.95,-.17,-1.91),vec2(.50,.51),.15+rough*8.);
    float shoulder=kitPaintPanel(p,reflection,vec3(2.25,.06,1.54),vec2(.29,.81),.035+rough*3.6);
    vec3 cards=vec3(1.0,.93,.86)*(1.06*first+2.22*shoulder)+vec3(.90,.96,1.)*(.76*rail+.30*side);
    float fresnel=edge*edge*edge*edge*edge;
    vec3 spec=(environment*.90+cards*3.65)*(ivory?.034:blue?.056:.067);
    spec+=(.68*environment+1.3*cards)*fresnel*(ivory?.25:.73);
    vec3 coat=pigment*diffuse+spec;
    if(blue) {
        // Encapsulated mica. A bounded dot per object-space cell keeps the
        // flakes fixed in the casting. At small sizes they merge into the base.
        vec3 cells=p*68.,delta=fract(cells)-.5;
        float seed=kitPaintHash(floor(cells));
        float flake=(1.-smoothstep(.12,.49,length(delta)))*smoothstep(.46,.92,seed);
        float lod=clamp((uResolution.y-140.)/540.,.025,.92)*(.3+.7*facing);
        float blueSheen=.36*environment.b+.24*(first+side)+.43*rail;
        coat+=vec3(.012,.064,.187)*blueSheen+vec3(.10,.26,.43)*flake*lod*(.11+blueSheen);
    }
    if(ivory&&shell) {
        // Graphite louver insert and a single orange inspection witness on
        // the right front shoulder, following the casting over its radius.
        float grille=scRect(vec2(p.z+.056,p.y-.103),vec2(.237,.098),.022);
        float inset=smoothstep(.64,.88,abs(n.x))*(1.-smoothstep(-.003,.002,grille));
        coat=mix(coat,vec3(.087,.103,.110)*(.60+.50*key)+spec*.75,inset);
        float tab=(1.-smoothstep(.016,.020,abs(p.x-.543)))*smoothstep(.268,.274,p.z)
                 *(1.-smoothstep(.503,.511,p.z))*smoothstep(.333,.347,p.y);
        coat=mix(coat,vec3(.905,.155,.018)*diffuse+spec,tab);
    }
    if(shell) {
        float relief=kitPaintRelief(p,key,environment,stock);
        coat*=min(1.,relief);
        coat=mix(coat,vec3(.014,.018,.023)*(.69+.36*key),.55*smoothstep(.56,.77,1.-relief));
        coat+=vec3(.095,.102,.103)*max(relief-1.,0.);
        // Original safety-orange cheek badges and red tail reflectors are
        // separate printed details in the source material.
        float marking=smoothstep(.11,.38,stock.r-stock.g)*smoothstep(1.32,2.35,stock.r/max(.015,stock.g));
        coat=mix(coat,stock,marking);
    }
    return coat;
}

// Three low roof instruments. Forward is +Z. The upper housings and true
// glass share one local frame; the foot of each mount seats on Scout's roof.
void kitDisplayFrame(float style,out vec3 center,out vec3 halfSize,out vec3 front,out vec3 right,out vec3 up) {
    if(style<5.5){
        center=vec3(.346,0.642,-.175);halfSize=vec3(.182,.104,.044);
        front=normalize(vec3(.085,.205,1.));
    }else if(style<6.5){
        center=vec3(.137,0.637,.050);halfSize=vec3(.366,.081,.033);
        front=normalize(vec3(0.,.435,1.));
    }else{
        center=vec3(.357,0.688,-.153);halfSize=vec3(.120,.158,.045);
        front=normalize(vec3(.235,.190,1.));
    }
    right=normalize(vec3(front.z,0.,-front.x));up=cross(front,right);
}
vec2 kitWindow(float style){
    if(style<5.5)return vec2(.151,.077);
    if(style<6.5)return vec2(.335,.058);
    return vec2(.096,.124);
}
float kitWindowY(float style){return style>6.5?.014:.003;}
float kitWindowRadius(float style){return style<5.5?.018:style<6.5?.012:.015;}
float kitCylinderY(vec3 p,float r,float h,float edge){
    return scSection(length(p.xz)-r,abs(p.y)-h,edge);
}
vec2 kitDisplayMap(vec3 p,float style) {
    if(style<4.5||style>7.5)return vec2(20.,110.);
    vec3 bc=style<5.5?vec3(.346,0.605,-.169):style<6.5?vec3(.137,0.595,.052):vec3(.367,0.659,-.147);
    vec3 bh=style<5.5?vec3(.205,0.155,.120):style<6.5?vec3(.384,0.141,.095):vec3(.165,0.207,.120);
    float bound=scBox(p-bc,bh,0.);
    if(bound>.026)return vec2(bound,110.);
    vec3 center,h,front,right,up;kitDisplayFrame(style,center,h,front,right,up);
    vec3 v=p-center,q=vec3(dot(v,right),dot(v,up),dot(v,front));
    vec2 s=q.xy-vec2(0.,kitWindowY(style)),win=kitWindow(style);
    float wr=kitWindowRadius(style);
    float shell=scBox(q,h,style<5.5?.026:(style<6.5?.018:.025));
    // The rubber seal surrounds a recessed pane within the actual housing.
    shell=max(shell,-max(scRect(s,win+.004,wr+.005),h.z-.031-q.z));
    vec2 result=vec2(shell,110.);
    float rubber=max(scRect(s,win+.006,wr+.005),-scRect(s,win-.004,wr));
    result=scAdd(result,scSection(rubber,abs(q.z-(h.z-.009))-.005,.002),111.);
    float glass=scSection(scRect(s,win-.004,wr),abs(q.z-(h.z-.017))-.007,.003);
    result=scAdd(result,glass,112.);
    if(style<5.5){
        // A broad isolator, two pressed lugs and a short transverse hinge.
        vec3 m=p-vec3(.343,.477,-.159);
        result=scAdd(result,scBox(m,vec3(.090,.009,.055),.006),111.);
        m.x=abs(m.x)-.064;
        result=scAdd(result,scBox(m-vec3(0.,0.036,0.),vec3(.015,0.037,.034),.007),113.);
        vec3 hub=q-vec3(0.,-.095,-.012);
        result=scAdd(result,scSection(length(hub.yz)-.016,abs(hub.x)-.082,.004),113.);
    }else if(style<6.5){
        // A low, wedge-shaped common plinth sits on two rubber shoes.
        vec3 base=p-vec3(.137,0.529,.045);
        float foot=scBox(vec3(abs(base.x)-.247,p.y-.477,base.z),
                          vec3(.051,.009,.048),.006);
        result=scAdd(result,foot,111.);
        float saddle=scBox(base,vec3(.294,0.051,.048),.012);
        saddle=max(saddle,base.z*.45-base.y-0.030);
        result=scAdd(result,saddle,110.);
        result=scAdd(result,scBox(q-vec3(0.,-.074,-.017),vec3(.303,.018,.023),.006),111.);
    }else{
        // A compact swivel puck directly under the portrait receiver.
        vec3 foot=p-vec3(.354,.477,-.135);
        result=scAdd(result,kitCylinderY(foot,.070,.011,.005),111.);
        result=scAdd(result,kitCylinderY(foot-vec3(0.,0.031,0.),.053,0.026,.006),113.);
        result=scAdd(result,scBox(q-vec3(0.,-.149,-.015),vec3(.050,.022,.024),.008),113.);
        vec3 knob=q-vec3(.124,-.063,-.002);
        float radial=length(knob.yz)-(.029+.0018*cos(16.*atan(knob.y,knob.z)));
        result=scAdd(result,scSection(radial,abs(knob.x)-.013,.005),114.);
        vec3 key=q-vec3(0.,-.132,h.z);
        key.x=abs(key.x)-.037;
        result=scAdd(result,scBox(key,vec3(.018,.006,.006),.004),115.);
    }
    return result;
}

float kitDigit(vec2 cell,float digit) {
    if(min(cell.x,cell.y)<0.||cell.x>2.||cell.y>4.)return 0.;
    // Each integer encodes five rows of a 3 x 5 dot-matrix numeral, bottom first.
    float code;
    if(digit<.5)code=31599.;else if(digit<1.5)code=9879.;else if(digit<2.5)code=31183.;
    else if(digit<3.5)code=31207.;else if(digit<4.5)code=23524.;else if(digit<5.5)code=29671.;
    else if(digit<6.5)code=29679.;else if(digit<7.5)code=30866.;else if(digit<8.5)code=31727.;else code=31719.;
    return mod(floor(code/exp2(cell.y*3.+cell.x)),2.);
}
float kitNumeral(vec2 cell,vec2 origin,float digit){
    return kitDigit(floor((cell-origin)*.5),mod(digit,10.));
}
float kitRectPix(vec2 p,vec2 a,vec2 b){
    return step(a.x,p.x)*step(a.y,p.y)*step(p.x,b.x)*step(p.y,b.y);
}
float kitInk(vec2 px,float style,float mode,float time) {
    bool sleep=mode==4.,search=mode==6.,drive=mode==7.;
    bool scan=mode==2.||mode==5.||search;
    float tick=sleep?0.:floor(max(time,0.)*3.);
    if(style<5.5) {
        // Battery readout; the enclosed gauge at the right is an actual icon.
        float charge=drive?83.-min(floor(tick/16.),2.):mode==5.?84.-min(floor(tick/5.),2.):(mode==3.||search||mode==2.)?85.:mode==1.?87.:86.;
        float k=max(kitNumeral(px,vec2(1.,2.),floor(charge/10.)),kitNumeral(px,vec2(9.,2.),charge));
        float body=kitRectPix(px,vec2(18.,3.),vec2(23.,10.))-kitRectPix(px,vec2(19.,4.),vec2(22.,9.));
        body=max(body,kitRectPix(px,vec2(20.,11.),vec2(21.,11.)));
        float fill=kitRectPix(px,vec2(19.,4.),vec2(22.,7.+step(86.,charge)))*step(mod(px.y,2.),.1);
        return max(k,max(.62*body,.93*fill))*(sleep?.54:1.);
    }
    if(style<6.5) {
        // Three large sweeps-count digits, then a time trace with a live cursor.
        float val=search?60.+mod(tick,37.):drive?20.+mod(floor(tick*.5),32.):mode==5.?92.+min(tick,7.):mode==2.?41.+min(floor(tick*.5),7.):mode==1.?24.:mode==3.?52.:sleep?2.:16.;
        float k=max(kitNumeral(px,vec2(1.,1.),0.),max(kitNumeral(px,vec2(9.,1.),floor(val/10.)),kitNumeral(px,vec2(17.,1.),val)));
        k=max(k,.24*kitRectPix(px,vec2(25.,1.),vec2(25.,10.)));
        if(px.x>=29.&&px.x<=61.) {
            float x=px.x-29.;
            float marker=mod(tick+mode*4.,33.);
            float wave=4.+floor(.5+1.35*sin(x*.32)+.68*sin(x*.79));
            wave+=floor((scan?4.:2.)*exp(-.112*(x-18.)*(x-18.))+.5);
            float trace=(1.-step(.51,abs(px.y-wave)))*(scan?.88:.70);
            float cursor=(1.-step(.51,abs(x-marker)))*kitRectPix(px,vec2(29.,2.),vec2(61.,9.));
            float ticks=step(mod(x,4.),.1)*step(abs(px.y-1.),.1);
            k=max(k,max(trace,max(.28*cursor,.38*ticks)));
        }
        return k*(sleep?.46:1.);
    }
    // Sight glass at top, range to the selected return in tenths below.
    float dist=drive?27.+floor(4.*sin(tick*.18)+.5):search?42.-min(mod(tick,18.),13.):mode==5.?31.-min(tick,5.):mode==2.?35.-min(floor(tick*.5),3.):mode==1.?28.:mode==3.?34.:sleep?0.:32.;
    float k=max(kitNumeral(px,vec2(1.,1.),floor(dist/10.)),kitNumeral(px,vec2(11.,1.),dist));
    k=max(k,kitRectPix(px,vec2(8.,1.),vec2(9.,2.)));
    k=max(k,.32*kitRectPix(px,vec2(1.,12.),vec2(17.,12.)));
    vec2 aim=px-vec2(9.,20.);
    float ax=abs(aim.x),ay=abs(aim.y);
    float bracket=max(kitRectPix(vec2(ax,ay),vec2(6.,3.),vec2(6.,5.)),kitRectPix(vec2(ax,ay),vec2(4.,5.),vec2(6.,5.)));
    float crosshair=max(kitRectPix(vec2(ax,ay),vec2(2.,0.),vec2(4.,0.)),kitRectPix(vec2(ax,ay),vec2(0.,2.),vec2(0.,4.)));
    float pos=search?floor(2.*sin(tick*.42)+.5):scan?max(0.,2.-floor(tick*.5)):1.;
    float dotMark=(1.-step(.4,abs(aim.x-pos)))*(1.-step(.4,abs(aim.y)));
    return max(k,max(.70*bracket,max(.69*crosshair,dotMark)))*(sleep?.46:1.);
}
vec3 kitScreen(vec3 p,vec3 view,float style) {
    vec3 center,h,front,right,up;kitDisplayFrame(style,center,h,front,right,up);
    vec2 pos=vec2(dot(p-center,right),dot(p-center,up)-kitWindowY(style));
    float facing=dot(view,front);
    if(facing<.036)return vec3(.013,.014,.013);
    vec2 win=kitWindow(style)-vec2(.008);
    // Reproject from the outer cover to the phosphor behind it.
    pos-=.011*vec2(dot(view,right),dot(view,up))/max(facing,.16);
    float inner=scRect(pos,win,kitWindowRadius(style)-.004);
    vec3 color=vec3(.025,.020,.014);
    if(inner<0.) {
        vec2 grid=style<5.5?vec2(25.,14.):style<6.5?vec2(64.,12.):vec2(19.,28.);
        vec2 g=(.5*pos/win+.5)*grid,i=floor(g),f=fract(g);
        vec2 stepTo=step(.5,f)*2.-1.;
        float footprint=clamp(118./(max(140.,uResolution.y)*max(.3,facing)),.10,.74);
        vec2 blend=.5*clamp(1.-min(f,1.-f)/footprint,0.,1.);
        float clock=uReduce>.5?.8:uSince;
        float ia=kitInk(i,style,uEvent,clock),ix=kitInk(i+vec2(stepTo.x,0.),style,uEvent,clock);
        float iy=kitInk(i+vec2(0.,stepTo.y),style,uEvent,clock),ixy=kitInk(i+stepTo,style,uEvent,clock);
        float ink=mix(mix(ia,ix,blend.x),mix(iy,ixy,blend.x),blend.y);
        vec2 dotPos=abs(f-.5);
        float matrix=1.-smoothstep(.34,.50,max(dotPos.x,dotPos.y));
        float detail=clamp((uResolution.y*max(.3,facing)-95.)/440.,.10,.88);
        float light=ink*mix(.91,.25+.75*matrix,detail);
        float vignette=smoothstep(0.,.014,-inner);
        color+=vignette*(vec3(.003,.002,.001)*matrix+vec3(.99,.34,.046)*light);
    }
    vec3 r=reflect(-view,front);
    float reflection=pow(max(0.,dot(r,normalize(vec3(-.32,.72,.63)))),12.);
    float fres=1.-clamp(facing,0.,1.);fres*=fres;
    return color+vec3(.061,.061,.052)*(reflection+.48*fres);
}
vec3 kitDisplaySurface(vec3 p,vec3 n,vec3 view,float material,float style) {
    vec3 center,h,front,right,up;kitDisplayFrame(style,center,h,front,right,up);
    vec3 v=p-center,q=vec3(dot(v,right),dot(v,up),dot(v,front));
    float key=.32+.64*max(dot(n,normalize(vec3(-.55,.76,.47))),0.);
    vec3 r=reflect(-view,n);
    float strip=exp(-11.*(r.y-.61)*(r.y-.61)-3.4*(r.x+.32)*(r.x+.32));
    float edge=1.-clamp(dot(n,view),0.,1.);
    if(material>111.5&&material<112.5){
        if(dot(n,front)>.86)return kitScreen(p,view,style);
        return vec3(.018,.022,.023)*key+.035*strip;
    }
    if(material>114.5)return vec3(.28,.120,.040)*key+.045*strip;
    if(material>113.5)return vec3(.068,.072,.065)*key+.078*strip+.014*edge;
    if(material>112.5)return vec3(.25,.28,.27)*key+.17*strip+.037*edge;
    if(material>110.5)return vec3(.043,.045,.041)*key+.018*strip;
    vec3 base=style<5.5?vec3(.130,.145,.124):style<6.5?vec3(.115,.138,.156):vec3(.186,.155,.108);
    vec3 col=base*key+(.072*strip+.018*edge);
    // Housing front carries pressed fasteners; the rear is a separate screwing cover.
    float nd=dot(n,front);
    if(abs(nd)>.82) {
        vec2 s=abs(q.xy)-h.xy+vec2(.022,.023);
        float screw=length(s);
        float disk=1.-smoothstep(.006,.010,screw);
        col=mix(col,vec3(.26,.27,.243)*(.64+.28*key),disk);
        col*=1.-.44*disk*(1.-smoothstep(.0006,.0025,abs(s.x+.48*s.y)));
    }
    if(nd<-.8) {
        float seam=abs(scRect(q.xy,h.xy-.015,.018));
        col*=1.-.52*(1.-smoothstep(.001,.004,seam));
        vec2 uv=q.xy+vec2(.015,.008);
        float grille=step(abs(uv.x),h.x*.50)*step(abs(uv.y),h.y*.25);
        float grooves=1.-smoothstep(.001,.004,abs(fract(uv.y/.021)-.5)*.021);
        col*=1.-.49*grille*grooves;
    }
    return col;
}
// Called only for pixels certified as the frontmost flat portion of material 112.
vec3 kitDisplayGlassRay(vec3 eye,vec3 ray,float style) {
    vec3 center,h,front,right,up;kitDisplayFrame(style,center,h,front,right,up);
    float t=(h.z-.010-dot(eye-center,front))/dot(ray,front);
    return kitScreen(eye+ray*t,-ray,style);
}
bool kitDisplayLiveGlass(vec3 p,vec3 n,float id,float style) {
    if(id<111.5||id>112.5)return false;
    vec3 c,h,f,r,u;kitDisplayFrame(style,c,h,f,r,u);
    return dot(n,f)>.98;
}

// Scout-local receiving plane is y=-.767, +Z forward. Input coverage stays
// independent of any viewer color, so the transparent gallery can use it too.
uniform float uRough;
float scoutTravel(float age){
    float turns=max(0.,age)/3.2,angle=6.2831853*fract(turns);
    return .295*(6.2831853*floor(turns)+angle-.106*sin(angle));
}
float scoutCastOpacity(vec2 xz){
    if(uRough<=.5||abs(xz.x)>=1.70||xz.y<=-1.75||xz.y>=1.12)return 0.;
    // The major light is (-.51,.90,.68). Project the rounded housing over its
    // lower/upper heights into the receiver; three slab normals give its hull.
    const vec2 offsetDir=vec2(.566667,-.755556);
    vec2 halfSpan=offsetDir*.315,extent=vec2(.558,.432);
    vec2 q=xz-vec2(0.,.017)-offsetDir*.911;
    vec2 d=abs(q)-extent-abs(halfSpan);
    vec2 perpendicular=vec2(.8,.6);
    float diagonal=abs(dot(q,perpendicular))-dot(extent,abs(perpendicular));
    float casing=1.-smoothstep(-.095,.225,max(max(d.x,d.y),diagonal)-.065);
    // Projection of the actual four horizontal tire drums. Choose the nearest
    // tire and solve the round YZ cross-section against its finite axle width.
    vec2 w=xz-offsetDir*.295;w-=sign(w)*vec2(.654,.431);
    float yy=clamp(offsetDir.y*w.y/(1.+offsetDir.y*offsetDir.y),(w.x-.141)/offsetDir.x,(w.x+.141)/offsetDir.x);
    float wheel=1.-smoothstep(-.039,.145,length(vec2(yy,w.y-offsetDir.y*yy))-.295);
    vec2 dish=(xz-(vec2(-.410,-.153)+offsetDir*1.493))/vec2(.29,.25);
    float top=.23*(1.-smoothstep(.44,1.50,dot(dish,dish)));
    float castShade=max(.62*casing,max(.52*wheel,top));
    vec2 touch=(abs(xz)-vec2(.654,.431))/vec2(.167,.113);
    vec2 belly=(xz-vec2(0.,-.025))/vec2(.75,.63);
    float contact=.77*exp(-1.45*dot(touch,touch));
    float nearby=.26*exp(-1.49*dot(belly,belly));
    float edge=(1.-smoothstep(1.55,1.70,abs(xz.x)))*smoothstep(-1.75,-1.56,xz.y)*(1.-smoothstep(.99,1.12,xz.y));
    return edge*(1.-(1.-castShade)*(1.-contact)*(1.-nearby));
}
float scoutTreadLug(float across,float behind,float roll,float rear,float detail){
    // The wheel shader cuts its chevrons where cos(24*angle + 4.4*abs(x/.145))
    // is positive. Its front/rear mold coordinates mirror the wheel angle.
    float groove=4.4*abs(across/.145);
    float c=cos(24.*(roll-behind/.295)+mix(groove,-groove,rear));
    float raised=1.-smoothstep(.06,.59,c);
    // At a grazing angle the paired bands remain after individual lugs merge.
    float resolved=smoothstep(.065,.49,detail);
    return mix(.44,mix(.48-.40*c,raised,resolved),resolved);
}
float scoutDeposited(float behind,float travel){
    return smoothstep(-.024,.043,behind)*(1.-smoothstep(travel-.060,travel+.038,behind));
}
float scoutTreadCoverage(vec2 xz,float mode,float age,float detail){
    float across=abs(xz.x)-.654;
    if(mode!=7.||age<=0.||abs(across)>=.153||xz.y>=.47||xz.y<=-3.50)return 0.;
    float travel=scoutTravel(age),roll=mod(travel,1.8535397)/.295;
    float front=.431-xz.y,rear=-.431-xz.y;
    float f=scoutDeposited(front,travel),r=scoutDeposited(rear,travel);
    if(max(f,r)<=0.)return 0.;
    float frontLug=scoutTreadLug(across,front,roll,0.,detail);
    float rearLug=scoutTreadLug(across,rear,roll,1.,detail);
    float print=mix(f*(.12+.82*frontLug),.13+.87*rearLug,r);
    float shoulder=1.-smoothstep(.102,.148,abs(across));
    float distanceFade=1.-smoothstep(1.78,3.055,max(0.,rear));
    return print*shoulder*distanceFade*smoothstep(0.,.08,travel);
}
// x: occlusion of studio light; y: dust picked up by the actual rolling lugs.
vec2 scoutFootprint(vec2 xz,float mode,float age,float detail){
    return vec2(scoutCastOpacity(xz),scoutTreadCoverage(xz,mode,age,detail));
}
// Straight alpha, linear color. Composite dark cast over the dusty print.
vec4 scoutFloorOverlay(vec2 xz,float mode,float age,float detail){
    vec2 fx=scoutFootprint(xz,mode,age,detail);
    float shade=.90*fx.x,dust=.83*fx.y,alpha=shade+(1.-shade)*dust;
    vec3 rgb=vec3(.003,.005,.008)*shade+vec3(.119,.113,.094)*dust*(1.-shade);
    return vec4(rgb/max(alpha,.00001),alpha);
}

// Scout's optics in rover/world coordinates. Each beam starts at its actual lens.
// All returned colors are linear. The shared study pass owns the display transfer.
vec3 studyLampOrigin(float style,float side){return style>=3.5?liftLampOrigin(side):headOrigin(style,side);}
vec3 headTint(float style) {
    if(style>=3.5)style=2.;
    if(style<1.5) return vec3(1.,.66,.35);
    if(style<2.5) return vec3(.89,.95,1.);
    return vec3(.67,.84,1.);
}

float sfHash(vec2 cell) {
    vec3 k=fract(cell.xyx*vec3(.1031,.11369,.13787));
    k+=dot(k,k.yzx+19.19);
    return fract((k.x+k.y)*k.z);
}
float sfNoise(vec2 p) {
    vec2 i=floor(p),a=fract(p);
    a=a*a*(3.-2.*a);
    return mix(mix(sfHash(i),sfHash(i+vec2(1.,0.)),a.x),
               mix(sfHash(i+vec2(0.,1.)),sfHash(i+1.),a.x),a.y);
}

// Angular distributions of each reflector, in tangents of horizontal and
// downward ray angles. A weak, wider lobe models the dispersing lower facets.
float sfLobe(vec2 angle,vec2 width) {
    vec2 q=angle/width;
    return exp(-dot(q,q));
}
float sfCandela(vec3 ray,float style,float side) {
    // Lower glass and scattering in the reflector skirt throw a small amount
    // down to the leading tire edges, well outside the focused forward lobe.
    float skirtGain=style<1.5?.205:(style<2.5?.48:.20);
    float down=max(-ray.y,0.);
    float skirt=skirtGain*down*down*down*smoothstep(-.28,.42,ray.z);
    if(ray.z<=.008) return skirt;
    vec2 slope=vec2(ray.x,-ray.y)/max(ray.z,.075);
    float candela;
    if(style<1.5) {
        float x=slope.x-side*.09;
        float hot=sfLobe(vec2(x,slope.y-.23),vec2(.34,.235));
        float spread=sfLobe(vec2(x,slope.y-.39),vec2(.72,.47));
        float apron=sfLobe(vec2(x,slope.y-.94),vec2(1.12,.59));
        candela=10.3*hot+3.05*spread+.33*apron;
    } else if(style<2.5) {
        float x=slope.x-side*.09;
        float fan=sfLobe(vec2(x,slope.y-.30),vec2(.91,.135));
        float fill=sfLobe(vec2(x,slope.y-.55),vec2(1.08,.31));
        float apron=sfLobe(vec2(x,slope.y-.94),vec2(1.22,.49));
        // Shield above the bright horizontal row. Fade the upper shoulder.
        float cutoff=smoothstep(.188,.320,slope.y+.012*abs(x));
        candela=15.4*fan*cutoff+5.15*fill+1.12*apron;
    } else {
        float x=slope.x-side*.045;
        float core=sfLobe(vec2(x,slope.y-.212),vec2(.094,.075));
        float shoulder=sfLobe(vec2(x,slope.y-.315),vec2(.173,.125));
        float spill=sfLobe(vec2(x,slope.y-.58),vec2(.44,.33));
        // The projector lens directs its optical axis below the square shroud.
        float cutoff=smoothstep(.147,.208,slope.y);
        candela=82.*core*cutoff+11.2*shoulder+1.56*spill;
    }
    return candela*smoothstep(.008,.19,ray.z)+skirt;
}

vec3 studyFloor(vec3 p,vec3 view,float style,float power) {
    vec2 xz=p.xz;
    vec2 grainPos=xz;
    if(style>=3.5&&uEvent==7.)grainPos.y+=scoutTravel(uSince);
    float range2=dot(xz,xz);
    // Avoid high-frequency sparkle as the plane converges at grazing angles.
    float footprint=clamp(uResolution.y*max(.02,view.y)/(330.+7.*range2),0.,1.);
    float coarse=sfNoise(grainPos*2.9+vec2(14.9,2.1))-.5;
    float fleck=sfNoise(grainPos*18.+vec2(7.6,15.1))-.5;
    float grain=sfNoise(grainPos*71.+vec2(2.1,4.7))-.5;
    float textureScale=1.+.095*coarse+.095*fleck*sqrt(footprint)+.076*grain*footprint;
    // Shallow aggregate pores stay on the receiving surface as the camera moves.
    vec2 cell=grainPos*24.5, tile=floor(cell);
    vec2 center=vec2(sfHash(tile+5.3),sfHash(tile+17.4))*.58+.21;
    float pit=1.-smoothstep(.035,.19,length(fract(cell)-center));
    textureScale*=1.-.21*pit*smoothstep(.39,.87,sfHash(tile+10.1))*footprint;
    // One nearly flush expansion joint crosses the far part of the light field.
    float joint=abs(grainPos.y+.20*grainPos.x-3.17);
    if(style>=3.5)joint=abs(mod(grainPos.y+.20*grainPos.x+.48,3.65)-1.825);
    textureScale*=1.-.11*(1.-smoothstep(.003,.013,joint))*sqrt(footprint);
    vec2 soft=xz-vec2(.13,-.19);
    float local=exp(-.046*dot(soft,soft));
    vec3 ambient=mix(vec3(.0082,.0105,.0144),vec3(.022,.026,.032),local);
    vec2 imprint=scoutFootprint(xz,style>=3.5?uEvent:0.,uSince,footprint);
    vec3 track=vec3(.119,.113,.094)*(.91+.09*local);
    vec3 color=mix(ambient,track,.83*imprint.y)*textureScale*(1.-.90*imprint.x);
    if(style<.5||power<=0.) return color;

    vec3 lit=vec3(0.);
    for(int k=0;k<2;k++) {
        float side=k==0?-1.:1.;
        vec3 d=p-studyLampOrigin(style,side);
        float d2=dot(d,d);
        vec3 ray=d*inversesqrt(max(.0001,d2));
        // Project the fixture's angular intensity onto a horizontal receiver.
        vec3 opticRay=style>=3.5?liftLampReferenceDirection(ray):ray;
        float illuminance=sfCandela(opticRay,style>=3.5?2.:style,side)*max(-ray.y,0.)/(d2+.055);
        vec3 h=view-ray;
        float nh=max(h.y*inversesqrt(max(.001,dot(h,h))),0.);
        float sheen=pow(nh,19.+4.*fleck);
        vec3 reflectance=vec3(.245,.250,.258)*textureScale+vec3(.031)*sheen;
        lit+=reflectance*illuminance;
    }
    return color+lit*headTint(style)*power;
}

vec3 headBounce(vec3 p,vec3 n,float style,float power) {
    if(style<.5||power<=0.) return vec3(0.);
    float transport=0.;
    for(int k=0;k<2;k++) {
        float side=k==0?-1.:1.;
        vec3 src=studyLampOrigin(style,side);
        vec3 toward=src-p;
        float d2=max(.0001,dot(toward,toward));
        // Leakage through the glass edge reaches the surrounding bracket.
        float local=max(0.,dot(n,toward)*inversesqrt(d2));
        transport+=.020*local*exp(-12.*d2);
        // A small patch of lit floor returns diffuse light to the lower casting.
        vec3 toFloor=vec3(src.x+.12*side,-.767,src.z+1.1)-p;
        float f2=dot(toFloor,toFloor);
        transport+=.024*max(0.,dot(n,toFloor))*inversesqrt(f2)/(1.+f2);
    }
    return headTint(style)*transport*power;
}

// 5 x 7 column masks, with bit zero at the bottom of each letter. Each texel
// has four adjacent columns. The line-width header is texel 48 on every row.
uniform sampler2D uEyeMask;

float speechColumn(float col, float line, float cols){
    if(col<0. || col>=cols) return 0.;
    float address=col+96.*line;
    vec4 four=floor(texture2D(uEyeMask,vec2((floor(address*.25)+.5)/64.,.5))*255.+.5);
    float part=mod(address,4.);
    if(part<1.5) return part<.5?four.r:four.g;
    return part<2.5?four.b:four.a;
}

float speechBit(float col,float row){
    if(row<0. || row>6.) return 0.;
    return mod(floor(col*exp2(-row)),2.);
}

// faceUV spans the 3.5:1 print area; (0,0) is its lower left. Sampling the
// four adjacent bit cells makes one continuous stroke when neighbors are lit.
float speechInk(vec2 faceUV){
    vec2 lengths=floor(texture2D(uEyeMask,vec2(48.5/64.,.5)).rg*255.+.5);
    if(lengths.x<.5) return 0.;
    bool two=lengths.y>.5;
    float line=two&&faceUV.y<.5?1.:0.;
    float width=line>.5?lengths.y:lengths.x;
    float pitch=min(.95/(two?16.:7.),3.5*.95/max(lengths.x,lengths.y));
    float center=.5+(two?(line<.5?4.5:-4.5)*pitch:0.);
    vec2 g=vec2((faceUV.x-.5)*3.5/pitch+width*.5,(faceUV.y-center)/pitch+3.5);
    if(g.x<-.5 || g.x>width+.5 || g.y<-.5 || g.y>7.5) return 0.;
    vec2 p=floor(g-.5);
    float cellPixels=.42*min(uResolution.y,uResolution.x/2.2)*pitch;
    float aa=clamp(.48/max(cellPixels,.1),.065,.5);
    vec2 f=smoothstep(vec2(.5-aa),vec2(.5+aa),fract(g-.5));
    float a=speechColumn(p.x,line,width), b=speechColumn(p.x+1.,line,width);
    return mix(mix(speechBit(a,p.y),speechBit(b,p.y),f.x),
               mix(speechBit(a,p.y+1.),speechBit(b,p.y+1.),f.x),f.y);
}

// Orthographic volume in half-canvas-height units. +Z is the printed front.
// The caller may steer the loose puffs in the image plane; the printed cloud
// never flips, moves or changes color when the speaker changes sides.
float speechHitDepth=-4.;
vec2 speechTrailAim=vec2(-1.,-.57);

const vec3 talkCore=vec3(-.018,.004,.051),talkCoreR=vec3(1.351,.466,.320);
const vec3 talkWest=vec3(-1.080,-.005,.008),talkWestR=vec3(.554,.438,.383);
const vec3 talkNW=vec3(-.689,.213,.046),talkNWR=vec3(.508,.393,.371);
const vec3 talkCrown=vec3(.015,.274,.040),talkCrownR=vec3(.548,.401,.364);
const vec3 talkNE=vec3(.687,.182,.034),talkNER=vec3(.505,.402,.361);
const vec3 talkEast=vec3(1.089,-.012,-.011),talkEastR=vec3(.550,.436,.383);
const vec3 talkSE=vec3(.583,-.171,.024),talkSER=vec3(.606,.365,.357);
const vec3 talkSW=vec3(-.526,-.155,.026),talkSWR=vec3(.582,.355,.363);

vec4 talkJoin(vec4 a,vec4 b,float k){
    float h=clamp(.5+.5*(b.w-a.w)/k,0.,1.);
    return vec4(mix(b.xyz,a.xyz,h),mix(b.w,a.w,h)-k*h*(1.-h));
}
vec4 talkBlob(vec3 p,vec3 center,vec3 radius){
    vec3 q=(p-center)/radius;float scale=.5*min(radius.y,radius.z);
    return vec4(2.*scale*q/radius,scale*(dot(q,q)-1.));
}
vec4 talkShape(vec3 p){
    vec4 s=talkBlob(p,talkCore,talkCoreR);
    s=talkJoin(s,talkBlob(p,talkWest,talkWestR),.078);
    s=talkJoin(s,talkBlob(p,talkNW,talkNWR),.088);
    s=talkJoin(s,talkBlob(p,talkCrown,talkCrownR),.099);
    s=talkJoin(s,talkBlob(p,talkNE,talkNER),.087);
    s=talkJoin(s,talkBlob(p,talkEast,talkEastR),.074);
    s=talkJoin(s,talkBlob(p,talkSE,talkSER),.083);
    return talkJoin(s,talkBlob(p,talkSW,talkSWR),.083);
}
// x is signed distance to the projected silhouette, y is its line-of-sight
// tangent depth, and z is the nearest analytic ellipsoid surface.
void talkInterval(float edge,float tangent,float front,float k,inout vec3 result){
    float h=clamp(.5+.5*(edge-result.x)/k,0.,1.);
    result.xy=vec2(mix(edge,result.x,h)-k*h*(1.-h),mix(tangent,result.y,h));
    result.z=max(result.z,front);
}
void talkBallRay(vec3 base,vec3 eye,vec3 center,vec3 radius,float k,inout vec3 result){
    vec3 q=(base-center)/radius,v=eye/radius;
    float a=dot(v,v),t=-dot(q,v)/a;
    vec3 nearPoint=q+t*v;
    float margin=dot(nearPoint,nearPoint)-1.;
    float edge=margin/max(.25,length(2.*nearPoint/radius));
    float front=margin<=0.?t+sqrt(max(0.,-margin/a)):-4.;
    talkInterval(edge,t,front,k,result);
}
vec3 talkMatte(vec3 n,vec3 eye,float fold){
    // Broad diffuse and sky fill describe soft powder, including the shaded
    // underside of each billow. No image of a studio light is reflected here.
    vec3 key=normalize(vec3(-.54,.76,.36));
    float diffuse=clamp(.54+.52*dot(n,key),0.,1.);
    float sky=.5+.5*n.y;
    vec3 body=mix(vec3(.224,.261,.367),vec3(.936,.933,.884),diffuse);
    body+=vec3(.027,.037,.057)*sky;
    float scatter=1.-max(0.,dot(n,eye));
    body+=vec3(.052,.060,.070)*scatter*scatter*(.42+.58*sky);
    return body*fold;
}
vec4 talkPrimary(vec3 base,vec3 eye,float aa){
    vec3 ray=vec3(20.,0.,-4.);
    talkBallRay(base,eye,talkCore,talkCoreR,.078,ray);
    talkBallRay(base,eye,talkWest,talkWestR,.078,ray);
    talkBallRay(base,eye,talkNW,talkNWR,.088,ray);
    talkBallRay(base,eye,talkCrown,talkCrownR,.099,ray);
    talkBallRay(base,eye,talkNE,talkNER,.087,ray);
    talkBallRay(base,eye,talkEast,talkEastR,.074,ray);
    talkBallRay(base,eye,talkSE,talkSER,.083,ray);
    talkBallRay(base,eye,talkSW,talkSWR,.083,ray);
    if(ray.x>aa*1.7+.016)return vec4(0.);
    float edge=ray.x;
    if(edge>-.05-aa){
        vec4 q=talkShape(base+ray.y*eye);
        ray.y-=clamp(dot(q.xyz,eye)*.32,-.12,.12);
        q=talkShape(base+ray.y*eye);
        edge=q.w/max(.20,length(q.xyz-dot(q.xyz,eye)*eye));
    }
    float alpha=1.-smoothstep(-.56*aa,.56*aa,edge);
    if(alpha<=0.)return vec4(0.);
    float t=ray.z> -3.?ray.z:ray.y+.032;
    for(int i=0;i<3;i++){
        vec4 q=talkShape(base+t*eye);
        t-=clamp(q.w/max(.12,dot(q.xyz,eye)),-.13,.066);
    }
    vec3 p=base+t*eye,gradient=talkShape(p).xyz,n=normalize(gradient);
    // Incoming skylight shelves out where two distinct billows meet.
    vec3 fromLeft=vec3(-.195,.110,.075),fromRight=vec3(.145,.078,.088);
    float left=dot(gradient,fromLeft)-talkShape(p+fromLeft).w;
    float right=dot(gradient,fromRight)-talkShape(p+fromRight).w;
    float fold=1.-.19*smoothstep(.002,.045,max(left,right));
    vec3 body=talkMatte(n,eye,fold);
    vec2 faceUV=(p.xy-vec2(0.,.004))/vec2(2.86,.817143)+.5;
    if(alpha>=1.&&edge<-.78*aa&&n.z>.08&&p.z>.021&&min(faceUV.x,faceUV.y)>=0.&&max(faceUV.x,faceUV.y)<=1.){
        float print=speechInk(faceUV)*smoothstep(.08,.25,n.z)*smoothstep(.021,.09,p.z);
        body=mix(body,vec3(.039,.035,.050)*(.81+.22*max(n.y,0.)),print);
    }
    speechHitDepth=t;
    return vec4(pow(clamp(body,0.,1.),vec3(.454545)),alpha);
}

// Radial exit of this puff's true projected ellipse in the direction of the
// speaker. The satellites start beyond the visible silhouette at every orbit.
float talkRim(vec3 axis,vec3 eye,vec3 center,vec3 radius){
    vec3 d=axis/radius,v=eye/radius,c=center/radius;
    float iv=1./dot(v,v);
    d-=v*dot(d,v)*iv;c-=v*dot(c,v)*iv;
    float a=dot(d,d),b=dot(d,c),discriminant=b*b-a*(dot(c,c)-1.);
    return discriminant<0.?0.:(b+sqrt(max(0.,discriminant)))/a;
}
const vec3 talkLeftWisp=vec3(-1.445,.565,-.026);
const vec3 talkHighWisp=vec3(.963,.759,-.085);
float talkRimAlong(vec3 axis,vec3 eye){
    float r=talkRim(axis,eye,talkCore,talkCoreR);
    r=max(r,talkRim(axis,eye,talkWest,talkWestR));
    r=max(r,talkRim(axis,eye,talkNW,talkNWR));
    r=max(r,talkRim(axis,eye,talkCrown,talkCrownR));
    r=max(r,talkRim(axis,eye,talkNE,talkNER));
    r=max(r,talkRim(axis,eye,talkEast,talkEastR));
    r=max(r,talkRim(axis,eye,talkSE,talkSER));
    r=max(r,talkRim(axis,eye,talkSW,talkSWR));
    return r+.015;
}

// A loose tuft has three unequal soft lobes of its own. Work only in its
// little projected bounds. Wobble and depth keep the row from reading as dots.
const vec3 talkTuftA=vec3(.300,-.114,.050),talkTuftAR=vec3(.700,.545,.592);
const vec3 talkTuftB=vec3(-.466,-.089,-.019),talkTuftBR=vec3(.534,.484,.491);
const vec3 talkTuftC=vec3(-.111,.289,.027),talkTuftCR=vec3(.468,.508,.485);
vec4 talkTuftForm(vec3 p){
    return talkJoin(talkJoin(talkBlob(p,talkTuftA,talkTuftAR),talkBlob(p,talkTuftB,talkTuftBR),.20),
                    talkBlob(p,talkTuftC,talkTuftCR),.18);
}
vec4 talkTuft(vec2 local,float radius,float lean,float depth,vec3 along,vec3 across,vec3 eye,float aa){
    vec2 q=local/radius;
    if(abs(q.x)>1.10+aa/radius||abs(q.y)>.94+aa/radius)return vec4(0.);
    q.y*=lean;
    vec3 plane=vec3(q,0.),view=vec3(0.,0.,1.),ray=vec3(20.,0.,-4.);
    talkBallRay(plane,view,talkTuftA,talkTuftAR,.20,ray);
    talkBallRay(plane,view,talkTuftB,talkTuftBR,.20,ray);
    talkBallRay(plane,view,talkTuftC,talkTuftCR,.18,ray);
    float alpha=(1.-smoothstep(-.55*aa,.55*aa,ray.x*radius))*smoothstep(.12*aa,.72*aa,radius);
    if(alpha<=0.)return vec4(0.);
    float t=ray.z> -3.?ray.z:ray.y;
    for(int i=0;i<2;i++){
        vec4 s=talkTuftForm(vec3(q,t));
        t-=clamp(s.w/max(.15,s.z),-.17,.07);
    }
    vec3 n=normalize(talkTuftForm(vec3(q,t)).xyz);
    n=normalize(along*n.x+across*(n.y*lean)+eye*n.z);
    speechHitDepth=depth+radius*t;
    return vec4(pow(clamp(talkMatte(n,eye,.984),0.,1.),vec3(.454545)),alpha);
}
vec4 speechCloud(vec2 uv,vec2 orbit,vec2 pixelSize){
    speechHitDepth=-4.;
    float aa=clamp(max(pixelSize.x,pixelSize.y),.0006,.09);
    if(abs(uv.x)>2.125+aa||abs(uv.y)>1.015+aa)return vec4(0.);
    vec2 cs=cos(orbit),sn=sin(orbit);
    vec3 eye=vec3(sn.x*cs.y,sn.y,cs.x*cs.y),right=vec3(cs.x,0.,-sn.x),up=cross(eye,right);
    vec3 base=right*uv.x+up*uv.y;
    if(abs(uv.x)<1.71+aa&&abs(uv.y)<.85+aa){
        vec4 cloud=talkPrimary(base,eye,aa);
        if(cloud.a>0.)return cloud;
    }

    // Two lifted curls leave clear sky around the primary mass. They are fixed
    // to the sculpture and stay behind the lettering at every viewing angle.
    vec2 leftAt=vec2(dot(talkLeftWisp,right),dot(talkLeftWisp,up));
    vec2 highAt=vec2(dot(talkHighWisp,right),dot(talkHighWisp,up));
    vec2 l=uv-leftAt,h=uv-highAt;
    if(abs(l.x)<.225+aa&&abs(l.y)<.18+aa){
        vec4 wisp=talkTuft(vec2(l.x,l.y*1.23),.209,1.,dot(talkLeftWisp,eye),right,up*1.23,eye,aa);
        if(wisp.a>0.)return wisp;
    }
    if(abs(h.x)<.215+aa&&abs(h.y)<.169+aa){
        vec4 wisp=talkTuft(vec2(-h.x,h.y*1.21),.199,1.,dot(talkHighWisp,eye),-right,up*1.21,eye,aa);
        if(wisp.a>0.)return wisp;
    }
    vec2 d=speechTrailAim;
    if(dot(d,d)<.0001)d=vec2(-1.,-.57);
    d=normalize(d);
    vec2 side=vec2(-d.y,d.x),local=vec2(dot(uv,d),dot(uv,side));
    if(local.x<.40||abs(local.y)>.32+aa)return vec4(0.);
    vec3 along=right*d.x+up*d.y,across=right*side.x+up*side.y;
    float start=talkRimAlong(along,eye);
    float end=min(2.07/max(.001,abs(d.x)),.945/max(.001,abs(d.y)));
    float span=max(.01,end-start),u=(local.x-start)/span;
    if(u<.045-aa/span||u>1.+aa/span)return vec4(0.);
    float room=smoothstep(.34,.70,span);
    float first=mix(.353,.312,room),second=mix(.714,.660,room);
    float outer=mix(.109,.063,room),last=1.-outer;
    float broad=mix(.214,.178,room),middle=.100*room,margin=.59*aa/span;
    float size,center,bend,lean,z;
    if(abs(u-first)<broad+margin){
        size=broad;center=first;bend=-.038;lean=1.;z=-.035;
    }else if(middle*span>.12*aa&&abs(u-second)<middle+margin){
        size=middle;center=second;bend=.043;lean=-1.;z=.042;
    }else{
        size=outer;center=last;bend=0.;lean=1.;z=.002;
    }
    if(abs(u-center)>size+margin)return vec4(0.);
    vec2 stem=d*(start+center*span);
    // Bend around the lifted curls gently rather than clipping the trail as its
    // aim crosses either curl. The last puff stays on the actual speaker ray.
    float av=(1.-smoothstep(.065,.35,length(stem-highAt)))-(1.-smoothstep(.065,.35,length(stem-leftAt)));
    float offset=bend*span+av*.139*(1.-smoothstep(.69,1.,center));
    vec2 origin=stem+side*offset;
    vec3 centerPlane=right*origin.x+up*origin.y;
    float depth=(z-centerPlane.z)/max(.32,eye.z);
    return talkTuft(vec2((u-center)*span,local.y-offset),size*span,lean,depth,along,across,eye,aa);
}

// The smallest puff is tied to a socket on Scout. As a camera cranes over
// him the socket rounds the visible roof edge, keeping the letters upright.
uniform float uEmission;
vec4 studySpeech(vec3 ro,vec3 rd,vec2 orbit,float style,float camera,float zoom,out float depth){
    vec3 subject=vec3(0.,.31,.06),socket=vec3(.54,.60,.18);
    vec3 shell=vec3(.66,.26,.52),roof=vec3(0.,.53,.025);
    float scale=.214,aperture=.442;
    if(style<3.5){
        subject=vec3(0.,.26,.13);socket=vec3(.55,.48,.32);
        roof=vec3(0.,.43,.08);scale=.202;
        aperture=mix(.43,.69,smoothstep(.38,1.,orbit.y));
    }else if(camera>.5&&camera<1.5){
        vec3 h,forward,across,rise;kitDisplayFrame(style,subject,h,forward,across,rise);
        if(style<4.5){subject=vec3(0.,.49,.29);h=vec3(.49,.062,.032);}
        socket=subject+vec3(h.x*.82,h.y+.016,.016);
        shell=vec3(h.x,h.y,max(.085,h.z));roof=subject;
        scale=style<4.5?.121:style<5.5?.097:style<6.5?.121:.100;
        aperture=style<4.5?.29:style<5.5?.214:style<6.5?.282:.225;
    }else if(camera>=3.5){
        scale=.232;aperture=.48;
    }else if(camera>=2.5){
        subject=vec3(0.,.167,.504);socket=vec3(.32,.353,.542);
        shell=vec3(.45,.16,.095);roof=subject;
        scale=.091;aperture=.226;
    }else if(camera>=1.5){
        subject=vec3(.05,-.19,.055);socket=vec3(.745,.055,.18);
        roof=vec3(0.,.18,.025);shell=vec3(.67,.18,.51);
        scale=.152;aperture=.37;
    }
    float cp=cos(orbit.y),sp=sin(orbit.y),cy=cos(orbit.x),sy=sin(orbit.x);
    vec3 view=vec3(sy*cp,sp,cy*cp),cameraRight=vec3(cy,0.,-sy);
    vec3 cameraUp=cross(view,cameraRight);
    float high=smoothstep(.59,1.28,orbit.y);
    // Ellipsoid support point in the camera-up direction at the roof rim.
    // Its X/Z footprint survives a vertical orbit where a world-Y offset vanishes.
    float side=clamp(dot(socket-subject,cameraRight)/max(.06,shell.x*.66),-1.,1.);
    vec3 rimDirection=cameraUp+.61*side*cameraRight;
    vec3 rim=roof+shell*shell*rimDirection/max(.001,length(shell*rimDirection));
    socket=mix(socket,rim,high);
    scale*=mix(1.,1.065,high);

    vec3 n=normalize(ro-socket),r=normalize(cameraRight-n*dot(n,cameraRight));
    vec3 u=cross(n,r);
    vec2 outwards=vec2(dot(socket-subject,r),dot(socket-subject,u));
    outwards.y=max(outwards.y,.30*length(outwards)+.032);
    outwards=normalize(outwards);
    // The volume's last puff lies on the inset boundary (±2.07 by ±.945).
    float reach=1./max(abs(outwards.x)/2.07,abs(outwards.y)/.945);
    vec3 center=socket+(r*outwards.x+u*outwards.y)*scale*(reach+.115);

    if(style>=4.5 && camera<.5){
        // Keep the ink above a near-side telemetry pane. The last puffs may
        // meet the casing, but the battery digits or range stay legible.
        vec3 gauge,h,f,gr,gu;kitDisplayFrame(style,gauge,h,f,gr,gu);
        float ratio=dot(ro-center,view)/max(.1,dot(ro-gauge,view));
        vec3 gaugeOnPlane=ro+(gauge-ro)*ratio;
        float hx=ratio*(abs(dot(gr,cameraRight))*h.x+abs(dot(gu,cameraRight))*h.y+
                         abs(dot(f,cameraRight))*h.z);
        float hy=ratio*(abs(dot(gr,cameraUp))*h.x+abs(dot(gu,cameraUp))*h.y+
                         abs(dot(f,cameraUp))*h.z);
        vec3 gap=center-gaugeOnPlane;
        float overlap=hx+1.68*scale-abs(dot(gap,cameraRight));
        float lift=clamp(hy+.60*scale-dot(gap,cameraUp),0.,.19);
        center+=cameraUp*lift*smoothstep(0.,.040,overlap)*(1.-high);
    }

    // Close camera presets can place a roof socket at the crop edge. Move the
    // prop in its real camera plane just far enough to fit its text and trail.
    float lens=aperture*zoom,along=dot(ro-center,view);
    vec2 extent=.5*lens*along*vec2(uResolution.x/uResolution.y,1.);
    scale=min(scale,.945*min(extent.x/2.16,extent.y/1.04));
    vec2 room=max(vec2(.001),extent-vec2(2.16,1.04)*scale);
    vec2 offset=vec2(dot(center-ro,cameraRight),dot(center-ro,cameraUp));
    vec2 correction=clamp(offset,-room,room)-offset;
    center+=cameraRight*correction.x+cameraUp*correction.y;

    vec3 eye=normalize(ro-center);
    r=normalize(cameraRight-eye*dot(eye,cameraRight));u=cross(eye,r);
    depth=10000.;float facing=dot(rd,eye);
    if(facing>=-.05)return vec4(0.);
    float planeT=dot(center-ro,eye)/facing;
    if(planeT<=0.)return vec4(0.);
    vec3 delta=ro+planeT*rd-center;
    vec2 local=vec2(dot(delta,r),dot(delta,u))/scale;
    float footprint=lens*planeT/(uResolution.y*scale);
    if(abs(local.x)>2.18+footprint||abs(local.y)>1.04+footprint)return vec4(0.);

    // Reproject the actual speaker AFTER the crop correction so the trail
    // keeps pointing inward even when the camera changes shoulders.
    vec3 tip=ro+(subject-ro)*(dot(center-ro,eye)/dot(subject-ro,eye))-center;
    vec2 aim=vec2(dot(tip,r),dot(tip,u));
    speechTrailAim=dot(aim,aim)>.000001?normalize(aim):vec2(0.,-1.);
    vec2 turn=vec2(.39*sin(orbit.x-.12),.20*sin(orbit.y-.12))*(1.-.68*high);
    vec4 cloud=speechCloud(local,turn,vec2(footprint));
    depth=planeT+scale*speechHitDepth/facing;
    return cloud;
}

// The object-frame uniform carries the chosen optics, lamp power and camera scale.
uniform vec3 uObjectFrame;
uniform vec2 uBodyTurn;
uniform float uPass;
const float studyGroundY = -.767;

void studyCamera(vec2 uv, vec2 orbit, float zoom, out vec3 eye, out vec3 ray) {
    float yaw=orbit.x, pitch=orbit.y;
    vec3 axis=vec3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch));
    vec3 right=vec3(cos(yaw),0.,-sin(yaw));
    vec3 up=cross(axis,right);
    if(uObjectFrame.x>=3.5){
        float style=uObjectFrame.x, camera=uBodyTurn.y;
        vec3 target=vec3(0.,.12,.04);float distance=5.60,aperture=.442;
        if(camera>.5&&camera<1.5){
            vec3 center,h,forward,across,rise;kitDisplayFrame(style,center,h,forward,across,rise);
            target=style<4.5?vec3(0.,.49,.29):center;
            distance=3.54;aperture=style<4.5?.29:style<5.5?.214:style<6.5?.282:.225;
        }else if(camera>=3.5){target=vec3(0.,-.12,-1.15);distance=6.85;aperture=.48;}
        else if(camera>=2.5){target=vec3(0.,.165,.505);distance=3.40;aperture=.226;}
        else if(camera>=1.5){target=vec3(.06,-.30,.00);distance=4.77;aperture=.37;}
        eye=target+axis*distance;
        ray=normalize(-axis+zoom*aperture*(uv.x*right+uv.y*up));return;
    }
    float high=smoothstep(.38,1.00,pitch);
    float wide=smoothstep(.78,1.,zoom);
    vec3 target=vec3(0.,mix(.015,mix(-.17,-.70,high),wide),
                        mix(.08,mix(.68,2.20,high),wide));
    eye=target+axis*mix(5.85,8.80,high*wide);
    float window=zoom*mix(.43,.69,high);
    ray=normalize(-axis+window*(uv.x*right+uv.y*up));
}
vec2 studySDF(vec3 p, float style) {
    vec2 base=scScene(p);
    if(style<.5)return base;
    vec2 lamp;
    if(style>=3.5){
        base=liftLampDeck(base,p);
        lamp=liftLampMap(p);
        if(style>=4.5){vec2 instrument=kitDisplayMap(p,style);if(instrument.x<lamp.x)lamp=instrument;}
    }else lamp=headParts(p,style);
    return lamp.x<base.x?lamp:base;
}
vec3 studyNormal(vec3 p,float style) {
    vec2 e=vec2(.0011,-.0011);
    return normalize(e.xyy*studySDF(p+e.xyy,style).x+e.yyx*studySDF(p+e.yyx,style).x+
                     e.yxy*studySDF(p+e.yxy,style).x+e.xxx*studySDF(p+e.xxx,style).x);
}
vec3 studyAir(vec3 ray){
    return mix(vec3(.010,.012,.015),vec3(.005,.006,.009),smoothstep(-.08,.34,ray.y));
}
// A small lens bloom is depth tested against the first visible surface.
vec3 studyGlare(vec3 eye,vec3 ray,float depth,float style,float power){
    vec3 glow=vec3(0.);
    if(style<.5||power<=0.)return glow;
    for(int i=0;i<2;i++){
        float side=float(i)*2.-1.;
        vec3 light=studyLampOrigin(style,side);
        if(((style>1.5&&style<2.5)||style>=3.5)){
            float t=dot(light-eye,ray);
            light.x+=clamp((eye+t*ray).x-light.x,-.20,.20);
        }
        vec3 d=light-eye;
        float along=dot(d,ray);
        if(along<=0.||along>depth+.115)continue;
        float facing=smoothstep(.02,.92,dot(normalize(eye-light),(style>=3.5?liftLampAxis():normalize(vec3(.04*side,-.13,1.)))));
        vec3 sep=d-ray*along;
        float r2=dot(sep,sep);
        float radius=((style>1.5&&style<2.5)||style>=3.5)?.062:.105;
        glow+=headTint(style)*(.062*exp(-2.*r2/(radius*radius))+.009*exp(-20.*r2))*power*facing;
    }
    return glow;
}
float faceMode(float mode){return mode==5.?2.:scKitFaceMode(mode);}
vec3 studyPixels(vec3 ro,vec3 rd,float mode){
    float t=(scGlass-ro.z)/rd.z;pcExpression=scKitFaceMode(mode);
    return scLCD(ro+rd*t,-rd,faceMode(mode),uSince,uLook)*.93;
}
vec3 studyGroundColor(vec3 ro,vec3 rd,float t,float style,float power){
    return mix(studyFloor(ro+rd*t,-rd,style,power),studyAir(rd),smoothstep(11.,31.,t));
}
void main(){
    vec2 uv=(gl_FragCoord.xy-.5*uResolution)/uResolution.y;
    float style=uObjectFrame.x;bool kit=style>=3.5;
    kitLift=kit?clamp(uBodyTurn.x,0.,1.):1.;
    float power=style<.5?0.:uObjectFrame.y*(kit?liftLampGain():1.);
    bool bake=uPass>.5&&uPass<1.5;
    float mode=bake?0.:uEvent;
    vec3 ro,rd;studyCamera(uv,uOrbit,uObjectFrame.z,ro,rd);
    scKitPose(kit?1.:0.,mode,bake?.75:uSince);
    if(kit)scKitConstrainRay(ro,rd);
    float floorT=rd.y<-.0001?(studyGroundY-ro.y)/rd.y:10000.;
    if(floorT<0.)floorT=10000.;
    vec2 swept=vec2(0.);if(kit)swept=scKitRayVolumes(ro,rd);
    vec4 speech=vec4(0.);float speechT=10000.;
    if(!bake&&uEmission>.5)speech=studySpeech(ro,rd,uOrbit,style,uBodyTurn.y,uObjectFrame.z,speechT);
    if(uPass>1.5&&speech.a==0.){
        vec4 saved=texture2D(uBeauty,gl_FragCoord.xy/uResolution);
        float tag=floor(saved.a*31.+.5),surface=mod(tag,8.);
        bool moving=(mode==6.&&mod(floor(tag/8.),2.)>.5)||(mode==7.&&tag>=16.);
        if(!moving){
            if(surface==0.||(surface==4.&&mode!=7.)){gl_FragColor=vec4(saved.rgb,1.);return;}
            if(surface==1.||surface==2.||surface==4.){
                float d=floorT;vec3 live;
                if(surface==1.){d=(scGlass-ro.z)/rd.z;live=studyPixels(ro,rd,mode);}
                else if(surface==2.){
                    vec3 c,h,f,r,u;kitDisplayFrame(style,c,h,f,r,u);
                    d=(h.z-.010-dot(ro-c,f))/dot(rd,f);
                    live=kitDisplayGlassRay(ro,rd,style);
                }else live=studyGroundColor(ro,rd,d,style,power);
                live+=studyGlare(ro,rd,d,style,power);
                gl_FragColor=vec4(pow(clamp(live,0.,1.),vec3(1./2.2)),1.);return;
            }
        }
    }
    float depth=floorT;vec2 hit=vec2(0.);
    float along=dot(ro,rd),radius=kit?1.48:1.38;
    float discriminant=along*along-dot(ro,ro)+radius*radius;
    if(discriminant>0.){
        float root=sqrt(discriminant),t=max(0.,-along-root),end=min(-along+root,floorT);
        if(t<end){
            for(int i=0;i<112;i++){
                vec2 probe=studySDF(ro+rd*t,style);
                if(probe.x<.00075){hit=probe;depth=t;break;}
                t+=max(.00042,probe.x*.74);
                if(t>end||(!kit&&i>=97))break;
            }
        }
    }
#ifdef STUDY_FLOOR_MASK
    gl_FragColor=vec4(vec3(hit.y<.5&&floorT<1000.?1.:0.),1.);return;
#endif
    float surface=0.;vec3 color;
    if(hit.y>.5){
        vec3 p=ro+rd*depth,n=studyNormal(p,style),v=-rd;
        if(hit.y==3.&&n.z>.94){surface=1.;color=studyPixels(ro,rd,mode);}
        else if(hit.y>=110.){
            color=kitDisplaySurface(p,n,v,hit.y,style);
            if(hit.y==112.){
                if(kitDisplayLiveGlass(p,n,hit.y,style)){surface=2.;color=kitDisplayGlassRay(ro,rd,style);}
                else surface=3.;
            }
        }else if(hit.y>=40.){
            color=kitPaintFinish(p,n,v,hit.y,liftLampSurface(p,n,v,hit.y,power),uStyle);
            if(hit.y==47.)color*=vec3(.74,.78,.83);
        }
        else if(hit.y>=19.5)color=headFinish(p,n,v,hit.y,style,power);
        else{
            color=kitPaintFinish(p,n,v,hit.y,scHousing(p,n,v,hit.y),uStyle);
            if(scoutRoofHit){surface=3.;color*=.93;}
            else{color*=vec3(.74,.78,.83)*mix(.76,1.,smoothstep(-.69,-.21,p.y));color+=headBounce(p,n,style,power);}
        }
    }else if(floorT<800.){surface=kit?4.:0.;color=studyGroundColor(ro,rd,floorT,style,power);}
    else color=studyAir(rd);
    color+=studyGlare(ro,rd,depth,style,power);
    vec3 display=pow(clamp(color,0.,1.),vec3(1./2.2));
    if(speechT<depth)display=mix(display,speech.rgb,speech.a);
    gl_FragColor=vec4(display,bake?(surface+8.*swept.x+16.*swept.y)/31.:1.);
}

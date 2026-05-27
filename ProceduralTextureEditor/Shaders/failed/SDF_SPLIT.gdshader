shader_type spatial;
uniform vec2 scale;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;

#include "shader_modules/library.gdshaderinc"



vec3 sdgCircle( in vec2 p, in float r )
{
    float d = length(p);
    return vec3( d-r, p/d );
}

vec3 sdgBox( in vec2 p, in vec2 b )
{
    vec2 w = abs(p)-b;
    vec2 s = vec2(p.x<0.0?-1.:1.,p.y<0.0?-1.:1.);
    float g = max(w.x,w.y);
    vec2  q = max(w,0.0);
    float l = length(q);
    return vec3(   (g>0.0)?l  :g,
                s*((g>0.0)?q/l:((w.x>w.y)?vec2(1,0):vec2(0,1))));
}

vec3 map( in vec2 p ){
float id = 0.;
vec3 seg = sdgBox(p,vec2(1.));
id =sign(seg.x);
vec2 c = seg.x*vec2(seg.y,seg.z);
//seg=min(seg,sdgBox(c,vec2(0.5)));
seg=sdgBox(c,vec2(0.5));

c = seg.x*vec2(seg.y,seg.z);
seg=sdgBox(c,vec2(0.25));
c = seg.x*vec2(seg.y,seg.z);

//seg.xz=c;

return seg;
    }



void vertex(){
	    w_norm = NORMAL;
		w_pos = VERTEX;
	}

void fragment() {

    vec3 anorm=abs(w_norm);
	vec3 v=w_pos;
	v.x*=floor(sign(w_norm.z));
	v.z*=-floor(sign(w_norm.x));
	v.y=-v.y;
	vec2 mp =mix(v.xy,v.zy,round(anorm.x));
	mp=mix(mp,w_pos.xz*-sign(w_norm.y),round(anorm.y));
	mp*=scale;

	vec3 outp = map(mp);
	//outp.x=clamp(outp.x,0.,1.);
	ALBEDO=vec3(abs(outp.x));//outp;//

}

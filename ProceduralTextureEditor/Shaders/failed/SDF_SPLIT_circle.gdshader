shader_type spatial;
uniform vec2 scale;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;

#include "shader_modules/library.gdshaderinc"

float sdBox( in vec2 p, in vec2 b )
{
    vec2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}

float sdCircle( vec2 p, float r )
{
    return length(p) - r;
}

vec3 sdgCircle( in vec2 p, in float r )
{
    float d = length(p);
    return vec3( d-r, p/d );
}


float shape( in vec2 p, in vec2 id ){

float b = hash12(id);
vec2 shift = hash22(id)-0.5;
    return sdCircle(p+shift,0.);
}


vec3 map( in vec2 p ){
float id = 0.;
vec3 seg = sdgCircle(p,2.);
id =sign(seg.x);
vec2 c = seg.x*vec2(seg.y,seg.z);
//seg=min(seg,sdgCircle(c,0.5));
seg=sdgCircle(c+vec2(0.1,0.3),0.5);

c = seg.x*vec2(seg.y,seg.z);
seg=sdgCircle(c+vec2(0.2,0.1),0.25);
c = seg.x*vec2(seg.y,seg.z);


seg.xz=c;

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
	ALBEDO=vec3(outp.xz,0.);//vec3(abs(outp.x));//outp;//

}

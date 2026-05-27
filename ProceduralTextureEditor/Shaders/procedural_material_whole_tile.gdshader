shader_type spatial;
//render_mode world_vertex_coords;
uniform float mult;
varying vec3 w_pos;
varying vec3 w_norm;

#include "shader_modules/library.gdshaderinc"




vec4 mat(vec2 uv){

	//uv+=fbm(uv*0.1)*4.;
	//uv.x+=floor(uv.y)*32.;
	vec2 muv =fract(uv)*4.;
	vec2 iuv = round(muv);
    vec2 fuv = muv-iuv;

	vec2 smth = fuv;
	float r = abs(smth.x)*2.;
    float f = grand(iuv.x*0.5);
	float edg = 0.1;
		float col1 = (1.-step(f,r))*abs(bn(iuv.xx));
			  col1 += (step(f,r))*abs(bn(floor(uv.xx+1.5)));//придумать что нибудь поэлегантнее
    	float f1 =1.-smoothstep(f-edg,f,r);

		f1 += smoothstep(f,f+edg,r);

    float h =grand(col1)-muv.y;
    return vec4(h*f1,0.,0.,f1);//min(f1,f2);
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

	mp*=mult;

    vec4 outp = mat(mp);

		float offset = 0.001;// /mult ? создаёт проблемы
		float mlp = 0.1;

		vec2 nuv = vec2(mp.x+offset,mp.y);
    vec3 fa = vec3(nuv.x, 0.0,mat(nuv).w*mlp);;

	    nuv = vec2(mp.x,mp.y-offset);
    vec3 fc = vec3(0.0, nuv.y,mat(nuv).w*mlp);

		 nuv = vec2(mp.x-offset,mp.y);
    vec3 fb = vec3(nuv.x, 0.0,mat(nuv).w*mlp);

	    nuv = vec2(mp.x,mp.y+offset);
    vec3 fd = vec3(0.0, nuv.y,mat(nuv).w*mlp);

const vec3 a = vec3(1., 0.8, 0.5);
const vec3 b = vec3(0.5, 0.5, 0.3);
const vec3 c = vec3(0.5, 0.360784, 0.3);
const vec3 d = vec3(0., 0.2, 0.333333);


	vec3 normal = 0.5+normalize(cross(fa-fb*vec3(1.,0.,1.), fc-fd*vec3(0.,1.,1.)))*vec3(1.,-1.,1.);
	
	ALBEDO=vec3(outp.x);
	//ALBEDO=vec3(fract(mp),0.);
	//ALBEDO=vec3(outp.w);
	//ALBEDO=normal;
    ROUGHNESS = 0.25;
	//NORMAL_MAP=normal;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
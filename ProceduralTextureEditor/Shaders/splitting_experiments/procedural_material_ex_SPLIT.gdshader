shader_type spatial;
uniform float mult;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;
uniform sampler2D sed:filter_nearest;

#include "shader_modules/library.gdshaderinc"



float lines(vec2 uv){

	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	/*

	vec2 c = vec2(fbm(uv*2.)*0.2+0.4);
	vec2 f = step(c, fuv);
	fuv =   (fuv - c * f) / mix(c, 1.0 - c, f);


	f = step(c, fuv);
	fuv =   (fuv - c * f) / mix(c, 1.0 - c, f);


	float c = grand(uv.x*2.)*0.2+0.5;
	float f = step(c, fuv.y);
	fuv.y =   (fuv.y - c * f) / mix(c, 1.0 - c, f);


	c = grand(fuv.x*4.)*0.2+0.5;
	f = step(c, fuv.y);
	fuv.y =   (fuv.y - c * f) / mix(c, 1.0 - c, f);

	//	fuv.y =  fract(fuv.y+c);
	*/

	float rand=fbm(uv);

	float c =  rand;
	float f = step(c, fuv.y);
	iuv.y+=f*32.;
	fuv.y =   (fuv.y - c * f) / mix(c, 1.0 - c, f);


	c = rand;
	f = step(c, fuv.x);
	iuv.x+=f*32.;
	fuv.x =   (fuv.x - c * f) / mix(c, 1.0 - c, f);

	c =   rand;
	f = step(c, fuv.y);
	iuv.y+=f*32.;
	fuv.y =   (fuv.y - c * f) / mix(c, 1.0 - c, f);





	vec2 smth = fuv-vec2(0.5,0.5);
	//float r=length(smth)*2.;
	float r = max(abs(smth.x),abs(smth.y))*2.;
	r=smoothstep(1.,0.9,r);

return bn(iuv)*r;
}

vec4 mat(vec2 uv){
	float f_out = lines(uv);
    return vec4(f_out,0.,0.,f_out);
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

		float offset = 0.001;
		float mlp = 0.1;

		vec2 nuv = vec2(mp.x+offset,mp.y);
    vec3 fa = vec3(nuv.x, 0.0,mat(nuv).w*mlp);;

	    nuv = vec2(mp.x,mp.y-offset);
    vec3 fc = vec3(0.0, nuv.y,mat(nuv).w*mlp);

		 nuv = vec2(mp.x-offset,mp.y);
    vec3 fb = vec3(nuv.x, 0.0,mat(nuv).w*mlp);

	    nuv = vec2(mp.x,mp.y+offset);
    vec3 fd = vec3(0.0, nuv.y,mat(nuv).w*mlp);

	vec3 normal = 0.5+normalize(cross(fa-fb*vec3(1.,0.,1.), fc-fd*vec3(0.,1.,1.)))*vec3(1.,-1.,1.);
	ALBEDO=vec3(mat(mp).x);
   // ROUGHNESS = 0.5;
	NORMAL_MAP=normal;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
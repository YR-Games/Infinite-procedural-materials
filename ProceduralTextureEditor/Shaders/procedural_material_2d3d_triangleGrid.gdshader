shader_type spatial;
uniform float mult;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;
uniform sampler2D sed:filter_nearest;

#include "shader_modules/library.gdshaderinc"



vec2 p_distr(vec2 uv){
	

	vec2 outp=random2(uv+TIME*0.001)*0.5;	
	return outp;
}

vec3 triangular_param(vec2 st) {
	float x=st.y+st.x;
	float y=st.y;
	float z=st.y-st.x;
    return vec3(x,y,z);
}



float lines(vec2 uv){
	//uv=warped_coords(uv);
	vec3 muv=triangular_param(uv);
	vec3 iuv = floor(muv);
    vec3 fuv = fract(muv);
	vec3 smth = fuv-vec3(0.5);
	float r = max(max(smth.x,smth.y),smth.z)*2.;
	float a = atan(smth.y,smth.x);
	a/=PI;
	a*=2.;
    float f = 1.;//frand(a+bn(iuv));


	float	 f1 =1.-smoothstep(f-0.2,f,r);

	
return f1;
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
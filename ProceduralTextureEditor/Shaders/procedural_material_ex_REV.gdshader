shader_type spatial;
render_mode world_vertex_coords;
uniform float mult;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;
uniform sampler2D sed:filter_nearest;


#include "shader_modules/library.gdshaderinc"



vec2 p_distr(vec2 uv){


	vec2 outp=random2(uv);
	return outp;
}

vec2 warped_coords(vec2 uv) {
    vec2 i_uv = floor(uv*2.);
	vec2 c_uv = i_uv+vec2(1.);
    vec2 f_uv = fract(uv*2.);


	vec2 a =p_distr(i_uv);
	vec2 b =p_distr(vec2(c_uv.x,i_uv.y));
	vec2 c =p_distr(vec2(i_uv.x,c_uv.y));
	vec2 d =p_distr(c_uv);


   //f_uv = f_uv * f_uv * (3.0 - 2.0 * f_uv);


    vec2 offset = mix(
        mix(a, b, f_uv.x),
        mix(c, d, f_uv.x),
        f_uv.y
    );

    return uv + offset;
}





float lines(vec2 uv){
	//uv.x+=fbm(uv*0.01)*32.;

	
	vec2 muv=uv;
	vec2 iuv = floor(muv);
    vec2 fuv = fract(muv);

	vec2 smth = fuv-vec2(0.5,0.5);
	float r = abs(smth.x)*2.;
    float f = bn(uv);
	float edg=0.3;
		//float col1 = (1.-step(f,r))*abs(bn(iuv.xx));
		//	  col1 += (step(f,r))*abs(bn(floor(uv.xx+1.5)));
	    	//float f1 =1.-smoothstep(f-edg,f,r);
		//f1 += smoothstep(f,f+edg,r);
		float f1=step(f,r-0.1);
		//f1+=1.-step(f,r+0.1);

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

// Цветовая интерполяция между тремя точками

	
	
	//ALBEDO=vec3(mat(mp).x);


	ALBEDO=mat(mp).xxx;
	//ALBEDO=vec3(abs(col.x - col.y) + abs(col.y - col.z) + abs(col.z - col.x));
	//ALBEDO=vec3(vor(mp,0.1).y);
   // ROUGHNESS = 0.5;
	NORMAL_MAP=normal;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
shader_type spatial;
//render_mode world_vertex_coords;
uniform float mult;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;

#include "shader_modules/library.gdshaderinc"






vec4 mat(vec2 uv){

	//uv*=rotate2d(PI*cos(TIME));
	float f_out =fract(uv).x;//tileN(uv);//lines(uv+lines(uv)+lines(uv));
		//f_out=vor2(uv).z;
    return vec4(f_out,0.,0.,f_out);//min(f1,f2);
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
/*
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
	*/
	vec2 fuv =fract(mp);
	
	ALBEDO=vec3(fuv,0.);//colorize(outp.x,vec3(1., 0.8, 0.5),vec3(0.5, 0.5, 0.3),vec3(0.5, 0.360784, 0.3), vec3(0., 0.2, 0.333333));
	//ALBEDO=vec3(bn(mp+tileN(mp)));
	//ALBEDO=vec3(mat(mp+tile2(mp)).x);
	//SPECULAR = 0.5;
	//METALLIC=0.5;
    ROUGHNESS = 1.;
	//NORMAL_MAP=normal;
	//NORMAL_MAP_DEPTH=normal_power;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
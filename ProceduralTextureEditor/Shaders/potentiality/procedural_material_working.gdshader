shader_type spatial;
//render_mode world_vertex_coords;
uniform float mult;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;


#include "shader_modules/library.gdshaderinc"
#include "shader_modules/SmoothMins.gdshaderinc"

vec2 metric(vec2 uv){
	//uv=floor(uv);
	vec2 smth = uv-0.5;
	float r = length(smth);
	//float r = smin_cube_poly(abs(smth.x),abs(smth.y),length(uv))*2.;
	//float r = max(abs(smth.x),abs(smth.y))*2.;
	//r =mix(r,max(abs(smth.x),abs(smth.y))*2.,fbm(uv));
	float a = atan(smth.y,smth.x);
	//a=max(abs(smth.x),abs(smth.y))*2.;
    return vec2(a,r);

}


float lines(vec2 uv){

	float fra = pfbm(uv*0.2,1.5,2.5,0.5);//+pfbm(uv,0.05,2.,0.5); //fbm(uv*0.1)*2.;
	uv+=fra;
	vec2 iuv=floor(uv);
	vec2 fuv=fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);
 	vec2 r = abs(smth)*2.;
    float f =grand(uv.y);
 	float edg =0.;

  float col1 = (1.-step(f-edg,r.x))*hash(iuv.x);
     	col1 += (step(f+edg,r.x))*hash(iuv.x+floor(smth.x)+0.5);

		f = grand(uv.x);
  float col2 = (1.-step(f-edg,r.y))*hash(iuv.y);
		col2 += (step(f+edg,r.y))*hash(iuv.y+floor(smth.y)+0.5);


    return col1*col2;//min(col1,col2);
}


vec4 mat(vec2 uv){

	//uv*=rotate2d(PI*cos(TIME));
	//vec3 muv = simplexGrid(uv)*32.;
	float f_out = lines(uv);//tileN(uv);//lines(uv+lines(uv)+lines(uv));
		//f_out=pseudoVoronoi(uv);
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


	vec4 mt =mat(mp);
	ALBEDO=colorize(mt.x,vec3(0.5, 0.5, 0.5),vec3(0.5, 0.5, 0.5),vec3(0.5, 0.360784, 0.3), vec3(0., 0.2, 0.333333));

	NORMAL_MAP=normal;
	NORMAL_MAP_DEPTH=normal_power;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
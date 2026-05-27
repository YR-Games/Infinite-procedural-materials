shader_type spatial;
uniform float mult;
uniform float normal_power;
uniform sampler2D fourier;
uniform sampler2D lx;
uniform sampler2D ly;
varying vec3 w_pos;
varying vec3 w_norm;

#include "shader_modules/library.gdshaderinc"
/*
float lines(vec2 uv){
	vec2 muv =uv+vec2(brand(uv.x),brand(uv.y)); //uv+snoise(uv*0.2);
	uv=mix(muv,uv,bn(uv)*1.5);
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);

	//float r1 =abs(smth.x)*2.;// length(smth)*2.;
	//float r2 =abs(smth.y)*2.; //max(abs(smth.x),abs(smth.y))*2.;
	float r =length(smth)*2.; //max(abs(smth.x),abs(smth.y))*2.;
	float a = atan(smth.y,smth.x);
 			float f =1.;
    		float f1=1.-smoothstep(f-0.4,f,r);
			//f1+=smoothstep(f,f+0.2,r);
    return f1;
}
*/

float stile(vec2 uv){
	//vec2 ruv=metric(uv);
	vec2 f1=vec2(brand(uv.x),brand(uv.y)); //uv+snoise(uv*0.2);
	float f2= bn(uv)*1.5;
	uv+=f1*(1.-f2);

    vec3 xyz = vec3(0.0);

    vec2 p = skew(uv);
    if (p.x > p.y) {
        xyz.xy = 1.0-vec2(p.x,p.y-p.x);
        xyz.z = p.y;
    } else {
        xyz.yz = 1.0-vec2(p.x-p.y,p.y);
        xyz.x = p.x;
    }




	vec3 muv = xyz;
	vec3 iuv = floor(muv);
    vec3 fuv = fract(muv);

	vec3 smth = muv-vec3(0.5);
	float r =length(smth)*2.; //max(abs(smth.x),abs(smth.y))*2.;
	float a = atan(smth.y,smth.x);
 			float f =10.+cos(TIME*0.1)*10.;
    		 f=1.-smoothstep(f-0.2,f,r);

    return f;
}



float Rcurve(float x){

	//uv+=fbm(uv*0.1)*4.;
	//uv.x+=floor(uv.y)*32.;
	float ix = floor(x);
    float fx = fract(x);

	float smth = fx-0.5;
	float r = abs(smth);
    float f = grand(x);
	float edg = 0.1;
    	float f1 =1.-smoothstep(f-edg,f,r);
		f1 += smoothstep(f,f+edg,r);


    return f1;//min(f1,f2);
}


vec2 metric(vec2 uv){
	//uv=floor(uv);
	float r = length(uv)*2.;
	//float r = smin_cube_poly(abs(smth.x),abs(smth.y),length(uv))*2.;
	//float r = max(abs(smth.x),abs(smth.y))*2.;
	// r =mix(r,max(abs(smth.x),abs(smth.y))*2.,fbm(uv));
	float a = atan(uv.y,uv.x);

    return vec2(a,r);

}





float lines(vec2 uv){
	vec2 f1=vec2(brand(uv.x),brand(uv.y)); //uv+snoise(uv*0.2);

	float f2= bn(uv)*1.5;
	uv+=f1*(1.-f2);
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);

	//float r1 =abs(smth.x)*2.;// length(smth)*2.;
	//float r2 =abs(smth.y)*2.; //max(abs(smth.x),abs(smth.y))*2.;
	float r =length(smth)*2.; //max(abs(smth.x),abs(smth.y))*2.;
	float a = atan(smth.y,smth.x);
 			float f =1.;
    		f=1.-smoothstep(f-0.2,f,r);
			//f1+=smoothstep(f,f+0.2,r);
    return f;
}


vec4 mat(vec2 uv){

	//uv*=rotate2d(PI*cos(TIME));
	float f_out = lines(uv);//tileN(uv);//lines(uv+lines(uv)+lines(uv));
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
	ALBEDO=vec3(1.);//colorize(outp.x,vec3(1., 0.8, 0.5),vec3(0.5, 0.5, 0.3),vec3(0.5, 0.360784, 0.3), vec3(0., 0.2, 0.333333));
	//ALBEDO=vec3(bn(mp+tileN(mp)));
	//ALBEDO=vec3(mat(mp+tile2(mp)).x);
	//SPECULAR = 0.5;
	//METALLIC=0.5;
    ROUGHNESS = 0.5;
	NORMAL_MAP=normal;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
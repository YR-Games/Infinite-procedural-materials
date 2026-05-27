shader_type spatial;
render_mode world_vertex_coords;
uniform float mult;
varying vec3 w_pos;
varying vec3 w_norm;

#include "shader_modules/BlueNoise.gdshaderinc"
#include "shader_modules/FBMNoise.gdshaderinc"
#include "shader_modules/PerlinNoise.gdshaderinc"
#include "shader_modules/random2.gdshaderinc"
#include "shader_modules/random.gdshaderinc"
#include "shader_modules/rotate2d.gdshaderinc"
#include "shader_modules/WaveletNoise.gdshaderinc"
#include "shader_modules/voronoi.gdshaderinc"


float pcurve( float x, float a, float b )
{
    float k = pow(a+b,a+b)/(pow(a,a)*pow(b,b));
    return k*pow(x,a)*pow(1.0-x,b);
}



vec3 colorize(float t,vec3 a, vec3 b, vec3 c,vec3 d){
	return  a + b * cos(TAU*(c*t+d));
}


vec3 mat(vec2 uv){

	//uv+=fbm(uv*0.1)*4.;
	//uv.x+=floor(uv.y)*32.;
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);

	vec2 smth = fuv-vec2(0.5,0.5);
	float r = abs(smth.x)*2.;
    float f = fract(uv.y);//wn(uv*0.4,uv.y)+0.5;
	float edg =  0.1;
		float col1 = (1.-step(f,r))*bn(iuv.xx);
			  col1 += (step(f,r))*bn(floor(uv.xx+1.5));//придумать что нибудь поэлегантнее
    	float f1 =1.-smoothstep(f-edg,f,r);

		f1 += smoothstep(f,f+edg,r);

	r = abs(smth.y)*2.;
	f = 1.;
   //	edg = fbm(uv);
		float col2 = (1.-step(f,r))*bn(iuv.yy);
			  col2 += (step(f,r))*bn(floor(uv.yy+1.5));//придумать что нибудь поэлегантнее
    	float f2 =1.-smoothstep(f-edg,f,r);
		f2 += smoothstep(f,f+edg,r);

    //float nois = fbm(uv*4.)*0.4;
	float h=min(f1,f2);
    return vec3(abs(col1*col2),0.,h);//min(f1,f2);
}


float scratches(vec2 uv){
	float worl =abs(wn(uv*0.01,0.))*4.;
	uv.x+=worl;
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);

	float r = length(smth.x)*2.;
	float a = atan(smth.y,smth.x);
 			float f1 =abs(cos(uv.y*0.05+worl))*ceil(bn(iuv.xx));
    		f1=smoothstep(f1-0.9,f1,r);

    return f1;
}

float tile(vec2 uv){
	float worl =vor3(vec3(uv,TIME)).z*4.;
	uv+=worl;
	float f_out=0.;
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);

	float r = length(smth.y)*2.;
	float a = atan(smth.y,smth.x);
 			float f1 =wn(uv,smth.x)+0.5;
    		f1=1.-smoothstep(f1-0.5,f1,r);

    return f1;
}


float FTN (in vec2 st) {
    // Initial values
    float value = 0.1;
    float amplitude = 0.1;
    //
    // Loop of octaves
    for (int i = 0; i <6; i++) {
        value += amplitude * tile(st);//wn(st,1.)
        st *= 2.;
        amplitude *= 0.6;
    }
    return value;
}



float lines(vec2 uv){

	//uv+=fbm(uv*0.1)*4.;
	//uv.x+=floor(uv.y)*32.;
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);

	vec2 smth = fuv-vec2(0.5,0.5);
	float r = abs(smth.x)*2.;
    float f = abs(wn(uv.yy*0.2,0.))+0.3;
	float edg = 0.5;//vor2(uv).z;

    	float f1 =1.-smoothstep(f-edg,f,r);

		f1 += smoothstep(f,f+edg,r);

    return f1;//min(f1,f2);
}


float lines3(vec3 pos){

	//uv+=fbm(uv*0.1)*4.;
	//uv.x+=floor(uv.y)*32.;
	float f_out=1.;
	vec3 ipos = floor(pos);
    vec3 fpos = fract(pos);
	vec3 smth = fpos-vec3(0.5);

	float r = abs(smth.x)*2.;
    float f = vor2(pos.xz).z;
	float edg = 0.1;//vor2(uv).z;
    	float f1 =1.-smoothstep(f-edg,f,r);
		f1 += smoothstep(f,f+edg,r);

		f_out=min(f_out,f1);

	r = abs(smth.y)*2.;
    f = vor2(pos.xy).z;
	edg = 0.1;//vor2(uv).z;
    	f1 =1.-smoothstep(f-edg,f,r);
		f1 += smoothstep(f,f+edg,r);

		f_out=min(f_out,f1);

	r = abs(smth.z)*2.;
    f = vor2(pos.zx).z;
	edg = 0.1;//vor2(uv).z;
    	f1 =1.-smoothstep(f-edg,f,r);
		f1 += smoothstep(f,f+edg,r);

		f_out=min(f_out,f1);

    return f_out;//min(f1,f2);
}

float height(vec3 uv){

	float xy =lines(uv.xy);
	//float zy =lines2(uv.zy);
	//float xz =lines2(uv.xz);
	float outp =lines(uv.xy);//lines(vec2(xy,yz),xz);//min(min(xy,yz),min(yz,xz));
    return outp;
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

		float offset = 0.001;// /mult ? создаёт проблемы
		float mlp = 0.1;
		/*
		float h1 = height(mp)*mlp;
		vec2 nuv = vec2(mp.x+offset,mp.y);
		float h2 = height(nuv)*mlp;
		 vec3 fa = vec3(mp.x, 0.0,h1);
		 vec3 fb = vec3(nuv.x, 0.0,h2);
		nuv = vec2(mp.x,mp.y+offset);
		float h3 = height(nuv)*mlp;
		 vec3  fc = vec3(0.0, mp.y,h1);
		 vec3  fd = vec3(0.0, nuv.y,h3);
*/

/*
		vec2 nuv = vec2(mp.x+offset,mp.y);
    vec3 fa = vec3(nuv.x, 0.0,height(nuv)*mlp);;

	    nuv = vec2(mp.x,mp.y-offset);
    vec3 fc = vec3(0.0, nuv.y,height(nuv)*mlp);

		 nuv = vec2(mp.x-offset,mp.y);
    vec3 fb = vec3(nuv.x, 0.0,height(nuv)*mlp);

	    nuv = vec2(mp.x,mp.y+offset);
    vec3 fd = vec3(0.0, nuv.y,height(nuv)*mlp);
*/

//	vec3 normal = 0.5+normalize(cross(fa-fb*vec3(1.,0.,1.), fc-fd*vec3(0.,1.,1.)))*vec3(1.,-1.,1.);
	//ALBEDO=vec3(0.6627,0.4431,0.2588);
	ALBEDO=vec3(pfbm(mp,0.25,2.,0.5));
	METALLIC =1.;
	//ALBEDO=vec3(outp.w);
	//ALBEDO=normal;
    ROUGHNESS = 0.38;
	//NORMAL_MAP=normal;
	//SPECULAR =1.180;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
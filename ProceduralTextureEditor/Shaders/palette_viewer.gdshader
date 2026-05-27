shader_type spatial;
uniform sampler2D grad:source_color;
uniform vec3 ua;
uniform vec3 ub;
uniform vec3 uc;
uniform vec3 ud;
#include "shader_modules/library.gdshaderinc"


float gain( float x, float k )
{

    return 1.-0.8*pow((1.-x),1./3.)-0.2;
}

vec3 colorz(float t){
	float gain = gain(t,0.25);
	float rr =frand(t*512.+13.);
	float gr =frand(t*864.+14.);
	float br =frand(t*456.+15.);
	return  texture(grad,vec2(t,0.)).xyz;//vec3(0.01+rr*(0.22+gain*0.2),0.15+gr*(0.01+t*0.1),0.08+br*(0.235*(t+0.3)))+gain;
}

vec3 graph(vec2 uv,vec3 c){
	return vec3(1.0) - smoothstep( 0.0, 0.01, abs(vec3(uv.y)-c));
}


void vertex(){}

void fragment() {
vec2 uv = UV;
uv.y*=3.;
uv.x=1.-uv.x;
vec3 color=vec3(uv.x);


//Цвет палитры:{ "a": (0.418453, 0.393333, 0.313712),
//"b": (0.807843, 0.811765, 0.752941), "c":
// (3208.1, 3208.1, 3208.1),
//"d": (0.352941, 0.360784, 0.266667), "e": (0.419608, 0.427451, 0.333333), "frequency": 3 }
vec3 a = vec3(0.541176,0.498039, 0.5);
vec3 b = vec3(0.5);
vec3 c = vec3(0.5,0.5,0.5);
vec3 d = vec3(0., 0.2, 0.333333);
float f = cos(TIME)*3.;

vec3 palette = colorz(uv.x);

if(uv.y<2.){
color=palette; //vec3(0.5, 0.5, 0.5),vec3(1., 1., 1.),vec3(1.0, 1.0, 1.0),vec3(0., 0.33, 0.66)
}

if(uv.y<1.){
color=graph(uv,palette); //vec3(0.5, 0.5, 0.5),vec3(1., 1., 1.),vec3(1.0, 1.0, 1.0),vec3(0., 0.33, 0.66)
}






	ALBEDO=color;
	//ALBEDO=vec3(outp);
    ROUGHNESS = 1.;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
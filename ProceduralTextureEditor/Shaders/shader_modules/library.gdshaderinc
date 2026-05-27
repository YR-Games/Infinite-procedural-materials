#include "rotate2d.gdshaderinc"
#include "random.gdshaderinc"
#include "BlueNoise.gdshaderinc"
#include "FBMNoise.gdshaderinc"
#include "PerlinNoise.gdshaderinc"
#include "random2.gdshaderinc"
#include "random.gdshaderinc"
#include "rotate2d.gdshaderinc"
#include "WaveletNoise.gdshaderinc"
#include "voronoi.gdshaderinc"
#include "1dNoises.gdshaderinc"
#include "SmoothMins.gdshaderinc"
#include "SimplexSpace.gdshaderinc"
#include "GNoise.gdshaderinc"
#include "VNoise.gdshaderinc"
float pcurve( float x, float a, float b )
{
    float k = pow(a+b,a+b)/(pow(a,a)*pow(b,b));
    return k*pow(x,a)*pow(1.0-x,b);
}



vec3 colorize(float t,vec3 a, vec3 b, vec3 c,vec3 d){
	return  a + b * cos(TAU*(c*t+d));
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



vec2 planarMap(vec3 pos, vec3 norm){
    vec3 anorm=abs(norm);
	vec3 v=pos;
	v.x*=floor(sign(norm.z));
	v.z*=-floor(sign(norm.x));
	v.y=-v.y;
	vec2 mp =mix(v.xy,v.zy,round(anorm.x));
	return mp=mix(mp,pos.xz*-sign(norm.y),round(anorm.y));
}

shader_type spatial;
uniform float xc :hint_range(0.0, 1.0, 0.01);
uniform float yc :hint_range(0.0, 1.0, 0.01);

#include "shader_modules/library.gdshaderinc"

void vertex() {
	// Called for every vertex the material is visible on.
}

float opXor( float a, float b )
{
    return max(min(a,b),-max(a,b));
}

void fragment() {
	vec2 uv = UV*64.;
	uv.x*=1.1547;
	vec2 uv1=vec2(uv.x,uv.y+0.5*uv.x);
	
	vec2 uv2=uv*vec2(0.7,1.4)*rotate2d(PI*0.25)+vec2(xc,yc);
	uv=vec2(uv.x,uv.y-0.5*uv.x);
	float a =bn(uv)*2.-1.;
	float b =bn(uv1)*2.-1.;
	float c =bn(uv2)*2.-1.;

	vec2 fuv = fract(uv);
	vec2 fuv1 = fract(uv1);
	vec2 fuv2 = fract(uv2);
	

	a=min(a,b);
	a=min(a,c);
	vec3 dis = vec3(a,b,c);
	vec3 grid = vec3( step(.98, fuv.x) + step(.98, fuv.y),step(.98, fuv1.x) + step(.98, fuv1.y),step(.98, fuv2.x) + step(.98, fuv2.y)  );
	ALBEDO=vec3(abs(a));//vec3(smoothstep(0.,0.5,a));
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

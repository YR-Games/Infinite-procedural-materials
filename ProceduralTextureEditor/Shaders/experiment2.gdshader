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

	float a =bn(uv*vec2(1.,2.))*2.-1.;
	float b =bn(uv*vec2(2.,1.)+vec2(1643.,0.))*2.-1.;
	float c =bn(uv+vec2(156.,123.))*2.-1.;

	
	a=max(a,b);
	a=max(a,b);
	vec3 dis = vec3(a,b,c);
	ALBEDO=vec3(abs(a));//vec3(smoothstep(0.,0.5,a));
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

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

	float a =bn(uv);
	float b =bn(uv*2.);
	float c =bn(uv*4.);
	vec2 fuv=fract(uv);
	vec3 grid = vec3( step(.98, fuv.x) + step(.98, fuv.y));
	ALBEDO=vec3(a,b,c)*0.5;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

shader_type spatial;

varying vec3 wpos;

#include "shader_modules/library.gdshaderinc"

void fragment() {
	vec2 uv = UV*64.;
float col = bn(uv+bn(uv*3.));
ALBEDO=vec3(col);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

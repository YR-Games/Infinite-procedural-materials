shader_type fog;
#include "shader_modules/library.gdshaderinc"
// Параметры льда

void fog() {
	vec4 n1 = gfbm(UVW,3);
 ALBEDO = vec3(0.4,0.6,1.)*abs(n1.x)*10.;
 EMISSION=ALBEDO;
 DENSITY = 2.;//abs(n1.x)*20.+1.;
}
shader_type spatial;
uniform sampler2D dt1; 
uniform sampler2D dt2; 
#include "shader_modules/library.gdshaderinc"
void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	vec2 uv=UV;
	float d1 = texture(dt1,uv).x;
	float d2 = texture(dt2,uv).y;
	float clrnc=d1+d2;
	float midsurf=d1-d2;
	vec2 coord = vec2(clrnc,midsurf);
	vec2 iuv= floor(coord);
	vec2 fuv= coord-iuv;
	
	vec3 coord3 = vec3(d1,d2,clrnc)*8.;
	vec3 iuv3= floor(coord3);
	vec3 fuv3= coord3-iuv3;

	vec3 grid = vec3((step(.95, fuv.x) + step(.95, fuv.y)));
	vec3 grid3 = vec3((step(.95, fuv3.x) + step(.95, fuv3.y))+ step(.95, fuv3.z));
	ALBEDO = vec3(grid3);//vec3(sin(tbf*32.)*sin(clrnc*16.));//vec3(smoothstep(0.,0.5,a));
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

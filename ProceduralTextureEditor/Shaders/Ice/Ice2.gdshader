shader_type spatial;
render_mode world_vertex_coords;
varying vec3 w_pos;
varying vec3 w_norm;
varying vec3 w_tan;
varying vec3 w_bin;
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture;

#include "shader_modules/library.gdshaderinc"
void vertex(){
	    w_norm = NORMAL;
		w_tan = TANGENT;
		w_bin = BINORMAL;
		w_pos = VERTEX;

	}




void fragment() {


    vec4 noise = vfbm(w_pos*2.,1);


    vec3 gradient = noise.yzw;
vec3 TAN = (INV_VIEW_MATRIX * vec4(TANGENT, 0.0)).xyz;
vec3 BIN = (INV_VIEW_MATRIX * vec4(BINORMAL, 0.0)).xyz;
vec3 normal_tangent = vec3(
    dot(gradient, TAN),
    dot(gradient, BIN),
    1.0
);
normal_tangent.y*=1.;
  vec3 normal_map = normal_tangent*0.5+0.5 ;

    NORMAL_MAP = normal_map;

    ALBEDO = vec3(0.9)*abs(noise.x);
	SPECULAR =1.3;
	ROUGHNESS =0.1;
	//SSS_STRENGTH =1.;
	//SSS_TRANSMITTANCE_COLOR=vec4(0.1);
    //ALPHA = 1.;//noise.x;
}

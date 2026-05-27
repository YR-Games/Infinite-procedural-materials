shader_type spatial;
render_mode blend_mix,world_vertex_coords;
#include "shader_modules/library.gdshaderinc"
uniform float scale: hint_range(0.0, 64.0, 0.1);
varying vec3 w_pos;
varying vec3 wnorm;
varying vec3 wtan;
varying vec3 wbin;
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture;

void vertex(){

	wtan = (MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz;
    wbin= (MODEL_MATRIX * vec4(BINORMAL, 0.0)).xyz;
  	 wnorm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
		w_pos = VERTEX*scale;

	}


void fragment() {



	vec4 n1 = gfbm(w_pos,6);

	vec4 n2 = gfbm(w_pos+n1.ywz*0.5,2);
    vec3 world_normal = n1.yzw;
    // Преобразуем в касательное пространство
    mat3 tbn = mat3(wtan, wbin, wnorm);
    vec3 normal = world_normal * tbn;
  ALBEDO = vec3(0.6,0.8,1.)*abs(n2.x+0.5);
  NORMAL_MAP = normal*0.5+0.5;
  NORMAL_MAP_DEPTH = n1.x;
  ALPHA = 0.5*n2.x+0.75;
  SPECULAR = 1.3;
  ROUGHNESS = 0.2;
}


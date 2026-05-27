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



	vec4 n1 = gfbm(w_pos,3);//мелкие детали

	vec4 n2 = gfbm(w_pos+n1.yzw*0.1,1);// поменять целое число для увеличения детализации
	
    vec3 world_normal = n2.yzw;
    // Преобразуем в касательное пространство
    mat3 tbn = mat3(wtan, wbin, wnorm);
    vec3 normal = world_normal * tbn;

  NORMAL_MAP = normal*0.5+0.5;
  NORMAL_MAP_DEPTH = 0.2;
  //ALPHA = 0.5*n2.x+0.75;
  SPECULAR = 1.3;
  ROUGHNESS = 0.0;

  ALBEDO = vec3(0.4,0.7,1.)*4.;//*abs(n2.x+0.5);
  vec3 refracted = refract(-VIEW, normal, 1.0/1.3);
  vec3 env_refraction = textureLod(SCREEN_TEXTURE, SCREEN_UV - refracted.xy * 0.1, ROUGHNESS * 8.0).rgb;
  ALBEDO = mix(ALBEDO, env_refraction, 0.8);

}




/*


void fragment() {
    // Базовые свойства материала
    ALBEDO = base_color.rgb;
    ALPHA = base_color.a;
    ROUGHNESS = roughness;
    
    // Нормаль из карты нормалей (если используется)
    NORMAL_MAP = texture(normal_map, UV).rgb;
    
    // Эффект преломления
    vec3 refracted = refract(-VIEW, NORMAL, 1.0/ior);
    METALLIC = 0.0;
    SPECULAR = 0.5;
    
    // Используем кубическую карту окружения для преломления
    vec3 env_refraction = textureLod(SCREEN_TEXTURE, SCREEN_UV - refracted.xy * 0.1, ROUGHNESS * 8.0).rgb;
    ALBEDO = mix(ALBEDO, env_refraction, 0.7);
}

*/
shader_type spatial;
render_mode world_vertex_coords;
#include "shader_modules/library.gdshaderinc"
varying vec3 w_pos;
varying vec3 wnorm;
varying vec3 wtan;
varying vec3 wbin;

uniform float radius = 0.5;
uniform float period = 2.0;
uniform int octaves = 3;



// Ядро SDF сферы
float sphere_sdf(vec3 p, float r) {
  return length(p) - r;
}

// Повторение домена с аналитическим градиентом
vec4 repeated_sdf_with_gradient(vec3 p) {
  vec3 cell_id = round(p / period);
  vec3 q = p - cell_id * period;
  vec3 gn = vor3(cell_id);
  q+=gn*0.5;
  float dist = sphere_sdf(q, gn.x);
  vec3 grad = normalize(q); // Градиент сферы
  return vec4(dist, grad);
}

// FBM-гипертекстура min-комбинацией
float fbm_min_sdf(vec3 p, out vec3 gradient) {
  float min_dist = 1e6;
  gradient = vec3(0.0);
  
  for(int i=0; i<octaves; i++) {
    float freq = pow(2.0, float(i));
    float weight = 1.0 / freq;
    vec3 sample_pos = p * freq;
    
    vec4 sdf_data = repeated_sdf_with_gradient(sample_pos);
    float dist = sdf_data.x * weight;
    vec3 grad = sdf_data.yzw * freq * weight;
    
    if(dist < min_dist) {
      min_dist = dist;
      gradient = grad;
    }
  }
  return min_dist;
}

void vertex(){
	 
	wtan = (MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz;
    wbin= (MODEL_MATRIX * vec4(BINORMAL, 0.0)).xyz;
  	 wnorm = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
		w_pos = VERTEX;
	}


void fragment() {

  // Вычисляем SDF и градиент
  	vec3 grad;
	float sdf_val = fbm_min_sdf(w_pos, grad);
    vec3 world_normal = grad;
    
    // Преобразуем в касательное пространство
    mat3 tbn = mat3(wtan, wbin, wnorm);
    vec3 normal = world_normal * tbn;
  ALBEDO = vec3(0.9);//vec3(sdf_val * 0.5 + 0.5); // Визуализация SDF
  NORMAL_MAP = normal*0.5+0.5;
  NORMAL_MAP_DEPTH =0.5;
  ROUGHNESS = 0.2;
}


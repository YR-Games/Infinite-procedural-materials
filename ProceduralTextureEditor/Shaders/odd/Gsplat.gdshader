shader_type spatial;
render_mode world_vertex_coords;
uniform sampler2D parameters_tex;
uniform int grid_resolution = 16;
uniform float amplitude = 1.0;
varying vec3 w_pos;

float gaussian_splat(vec2 uv, vec2 center, vec2 scale) {
    vec2 delta = uv - center;
    // Оптимизированное масштабирование:
    return exp(-dot(delta * delta, scale * 20.0));
}

void vertex() {
    w_pos = VERTEX;
}

void fragment() {
    vec2 uv = w_pos.xz;
    float result = 0.0;
    float cell_size = 1.0 / float(grid_resolution);
    
    // Точное вычисление ячейки
    vec2 grid_coord = uv / cell_size;
    ivec2 cell_id = ivec2(floor(grid_coord));
    
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            ivec2 neighbor_id = cell_id + ivec2(dx, dy);
            neighbor_id = (neighbor_id + grid_resolution) % grid_resolution;
            
            vec4 params = texelFetch(parameters_tex, neighbor_id, 0);
            vec2 center = params.xy; // Глобальные координаты!
            vec2 scale = params.zw;
            
            if (length(scale) > 0.001) {
                // Убираем fract и cell_origin - center уже абсолютные
                result += gaussian_splat(uv, center, scale) * amplitude;
            }
        }
    }
    
    ALBEDO = vec3(clamp(result, 0.0, 1.0));
}

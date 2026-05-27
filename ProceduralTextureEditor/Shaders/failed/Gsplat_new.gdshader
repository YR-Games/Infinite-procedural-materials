shader_type spatial;

// Unified texture inputs
uniform sampler2D splat_data : source_color;  // Old combined format
uniform sampler2D splat_pos_scale : source_color;  // New position/scale
uniform sampler2D splat_color_alpha : source_color;  // New color/alpha
uniform bool use_separated_textures = true;

void fragment() {
    vec2 uv = UV;
    vec4 color = vec4(0.0);
    float cell_size = 1.0/16.0;
    ivec2 cell = ivec2(uv / cell_size);
    
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            ivec2 neighbor = cell + ivec2(x,y);
            int idx = int(neighbor.y * 16 + neighbor.x) % 256; // Simple grid hash
            
            vec4 pos_scale, splat_color;
            
            if (use_separated_textures) {
                pos_scale = texelFetch(splat_pos_scale, ivec2(idx,0), 0);
                splat_color = texelFetch(splat_color_alpha, ivec2(idx,0), 0);
            } else {
                pos_scale = texelFetch(splat_data, ivec2(idx,0), 0);
                splat_color = vec4(pos_scale.xyz, 1.0); // Legacy color handling
                pos_scale.w = 0.02; // Default scale for legacy
            }
            
            vec2 delta = uv - pos_scale.xy;
            float dist_sq = dot(delta/pos_scale.zw, delta/pos_scale.zw);
            if (dist_sq < 9.0) {
                float weight = exp(-dist_sq/2.0) * splat_color.a;
                color += splat_color * weight;
            }
        }
    }
    
    ALBEDO = color.rgb;
    ALPHA = color.a;
}
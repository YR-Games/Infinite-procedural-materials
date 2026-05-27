shader_type spatial;
render_mode blend_mix;


uniform float blur_strength: hint_range(0, 0.05) = 0.01;
uniform float distortion_strength: hint_range(0, 0.1) = 0.03;
uniform float transparency: hint_range(0, 1) = 0.7;
uniform vec4 glass_tint: source_color = vec4(0.92, 0.95, 0.98, 1.0);


uniform sampler2D noise_texture: hint_normal;
uniform sampler2D normal_map: hint_normal;
uniform sampler2D SCREEN_TEXTURE: hint_screen_texture;

void fragment() {

    vec2 screen_uv = SCREEN_UV;
    

    vec2 distortion = texture(noise_texture, UV * 2.0).rg;
    distortion = (distortion - 0.5) * 2.0 * distortion_strength;
    


        vec3 normal_perturb = texture(normal_map, UV).xyz * 2.0 - 1.0;
        distortion += normal_perturb.xy * 0.015;

    
    screen_uv += distortion;
    
    vec4 blurred_color = vec4(0.0);
    const float kernel[9] = float[](
        0.077847, 0.123317, 0.077847,
        0.123317, 0.195346, 0.123317,
        0.077847, 0.123317, 0.077847
    );
    
    vec2 offsets[9] = vec2[](
        vec2(-1, -1), vec2(0, -1), vec2(1, -1),
        vec2(-1,  0), vec2(0,  0), vec2(1,  0),
        vec2(-1,  1), vec2(0,  1), vec2(1,  1)
    );
    
    for (int i = 0; i < 9; i++) {
        vec2 offset = offsets[i] * blur_strength;
        blurred_color += textureLod(SCREEN_TEXTURE, screen_uv + offset, 0.0) * kernel[i];
    }
    
    // Применяем цвет стекла и прозрачность
    blurred_color.rgb = mix(blurred_color.rgb, glass_tint.rgb, 0.5);
    blurred_color.a = transparency;

    ALBEDO = blurred_color.rgb;
	SPECULAR =1.3;
	ROUGHNESS =0.;
	//SSS_STRENGTH =1.;
	//SSS_TRANSMITTANCE_COLOR=vec4(0.1);
    ALPHA = blurred_color.a;
}

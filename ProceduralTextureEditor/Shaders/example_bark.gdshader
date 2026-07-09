shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

float blueNoise(in vec2 uv, in float scale){
	return bn(uv*scale);
}


void fragment() {
	vec2 uv = UV;

	vec4 base_albedo = vec4(1.0);
	float gen_val_layer_10229529_1927314791 = blueNoise(uv, 10.000000);
	vec4 layer_layer_10229529_1927314791 = vec4(vec3(gen_val_layer_10229529_1927314791), 1.0);
	base_albedo = mix(base_albedo, layer_layer_10229529_1927314791, layer_layer_10229529_1927314791.a * 1.000000);
	ALBEDO = base_albedo.rgb;
	ALPHA = base_albedo.a;

}
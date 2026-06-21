shader_type spatial;
render_mode blend_mix, depth_draw_opaque;

float sphereGrid(vec2 uv) {
    vec2 squaregrid = fract(uv) - .5; //rectangular grid with center in the middle
    float spheregrid = dot(squaregrid, squaregrid); //squared distance form scenter
    return spheregrid;
}


#define cos1            1.0049000034 //cos((pi * 24.)/180.)*1.1
#define sin1            0.4474103074 //sin((pi * 24.)/180.)*1.1

float cellTiling(vec2 uv) {
    float c = sphereGrid(uv);// first grid
        
    mat2 m = mat2(vec2(cos1, -sin1),vec2(sin1, cos1)); // rotation/scale matric
    
    uv *= m; //each iteration gets rotated and scaled one addional time
    //c = smin_cube_poly(c, sphereGrid(uv),0.0); // blending the voronoi with
     c = min(c, sphereGrid(uv));
    uv *= m; //each iteration gets rotated and scaled one addional time
    //c = smin_cube_poly(c, sphereGrid(uv),0.0); // blending the voronoi with 
    c = min(c, sphereGrid(uv));
    return c; //sqrt for center distance, 1.5 for 0-1 range
}


float cfbm( in vec2 x, in float H, in int numOct )
{    
    float G = exp2(-H);
    float f = 1.0;
    float a = 1.0;
    float t = 0.0;
    for( int i=0; i<numOct; i++ )
    {
        t += a*cellTiling(f*x);
        f *= 2.;
        a *= G;
    }
    return t;
}


float cellNoise(in vec2 uv, float chaos, int numOctaves, float scale,){
	return cfbm(uv*scale,chaos,numOctaves);
}


vec4 colorRamp(float value, vec3 palette[8]) {
    const int SIZE = 8;

    float t = clamp(value, 0.0, 1.0) * float(SIZE - 1);

    int i = int(floor(t));
    i = clamp(i, 0, SIZE - 2);

    float f = fract(t);

    return vec4(mix(palette[i], palette[i + 1], f), 1.0);
}


vec4 normalBlend(vec4 base, vec4 blend) {
    return mix(base, blend, blend.a);
}


void fragment() {
	vec2 uv = UV;

	vec4 base_albedo = vec4(0.0);
	float gen_val_layer_6458644_259489479 = cellNoise(uv, 1.000000, 1, 20.000000);
	
	
	vec3 %s[%d] = vec3[](
		%s
	);
	
	vec4 mod_mod_13957749_2471323238 = colorRamp(gen_val_layer_6458644_259489479, mod_mod_13957749_2471323238_palette);
	vec4 layer_layer_6458644_259489479 = mod_mod_13957749_2471323238;
	base_albedo = normalBlend(base_albedo, layer_layer_6458644_259489479);
	ALBEDO = base_albedo.rgb;
	ALPHA = base_albedo.a;

}
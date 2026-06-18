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


vec4 multiplyBlend(vec4 base, vec4 blend) {
    return base * blend;
}


vec4 normalBlend(vec4 base, vec4 blend) {
    return mix(base, blend, blend.a);
}


void fragment() {
	vec2 uv = UV;

	vec4 base_albedo = vec4(0.0);
	float gen_val_layer_14846772_2500332088 = cellNoise(uv, 1.0, 1, 1.0);
	vec4 layer_layer_14846772_2500332088 = vec4(vec3(gen_val_layer_14846772_2500332088), 1.0);
	base_albedo = multiplyBlend(base_albedo, layer_layer_14846772_2500332088);
	float gen_val_layer_15968733_3454246235 = cellNoise(uv, 0.38, 10, 8.75);
	vec4 layer_layer_15968733_3454246235 = vec4(vec3(gen_val_layer_15968733_3454246235), 1.0);
	base_albedo = normalBlend(base_albedo, layer_layer_15968733_3454246235);
	ALBEDO = base_albedo.rgb;
	ALPHA = base_albedo.a;

}
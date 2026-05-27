shader_type spatial;
//render_mode world_vertex_coords;
uniform float mult;
group_uniforms height;
uniform float heightmap_scale : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform int heightmap_layers : hint_range(8, 128, 1) = 32;
uniform float depthOffset : hint_range(0.0, 1.0, 0.1) = 0;
varying vec3 w_pos;
varying vec3 w_norm;
uniform vec3 albedo :source_color;
uniform vec3 albedo_seam :source_color;
uniform float specular : hint_range(0.0, 10.0, 0.01) = 0.5;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float normal_depth : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float seam_scale : hint_range(0.0, 1.0, 0.01) = 0.0;
uniform float slope_scale : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform float roundness : hint_range(0.0, 1.0, 0.001) = 0.01;


#include "shader_modules/library.gdshaderinc"


void vertex(){
	    w_norm = NORMAL;
		w_pos = VERTEX;
	}

	vec4 mat(vec2 uv){

    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);
	float r = smin_cube_poly(abs(smth.x),abs(smth.y),roundness)*2.;
    		float f1=smoothstep(seam_scale,slope_scale,r);

float test =step(0.05,f1);


    return vec4(test*albedo+(1.-test)*albedo_seam,f1);
}



const int MaxSamples = 10;
vec4 filtered_mat( in vec2 uvw)
{
float detail= 1.;
vec2 ddx_uvw = uvw+dFdx(uvw);
vec2 ddy_uvw = uvw+dFdy(uvw);
    int sx = 1 + int( clamp( detail*length(ddx_uvw-uvw), 0.0, float(MaxSamples-1) ) );
    int sy = 1 + int( clamp( detail*length(ddy_uvw-uvw), 0.0, float(MaxSamples-1) ) );

	vec4 no = vec4(0.0);

    for( int j=0; j<sy; j++ )
    for( int i=0; i<sx; i++ )
    {
        vec2 st = vec2( float(i), float(j) ) / vec2( float(sx),float(sy) );
        no += mat( uvw + st.x*(ddx_uvw-uvw) + st.y*(ddy_uvw-uvw));
    }

	return no / float(sx*sy);
}


float height(vec2 uv){
	return mat(uv).w;
}

vec3 color(vec2 uv){
	return filtered_mat(uv).xyz;
}


vec3 normalFromHeight(vec2 uv,float offset,float mlp){

/*
float h=height(uv);
float x=dFdx(h);
float y=dFdy(h);

    vec3 dx = vec3(1.0, 0.0, x);
    vec3 dy = vec3(0.0, 1.0, y);
	    return 0.5+normalize(cross(dx, dy));
*/


vec2 nuv = vec2(uv.x+offset,uv.y);
    vec3 fa = vec3(nuv.x, 0.0,height(nuv)*mlp);

	    nuv = vec2(uv.x,uv.y-offset);
    vec3 fc = vec3(0.0, nuv.y,height(nuv)*mlp);

		 nuv = vec2(uv.x-offset,uv.y);
    vec3 fb = vec3(nuv.x, 0.0,height(nuv)*mlp);

	    nuv = vec2(uv.x,uv.y+offset);
    vec3 fd = vec3(0.0, nuv.y,height(nuv)*mlp);

	return 0.5+normalize(cross(fa-fb, fc-fd))*vec3(1.,-1.,1.);
}



float GetNormalizedDepth(float startDepth, float stopDepth, float inverseDepthRange, vec2 uv) {
    float current_sample = height(uv.xy);
    float normalizedDepth = 0.0;
    if(stopDepth - startDepth > 0.0001)
    {
        float minNormalizedDepth = -startDepth * inverseDepthRange;
        normalizedDepth = max(current_sample, minNormalizedDepth);
    }
    return normalizedDepth;
}

vec2 parallax(vec2 base_uv,vec3 dirToCameraTS){
		float height_scale = heightmap_scale;

	    float dirToCameraZInverse = 1.0 / dirToCameraTS.z;
	    float steps = 1.0 / float(heightmap_layers);
		float currentStep = 0.0;

	    // the amount to shift per step, shift in the inverse direction of dirToCameraTS
	    vec3 delta = -dirToCameraTS.xyz * height_scale * dirToCameraZInverse * steps;

	    float depthSearchStart = depthOffset;
	    float depthSearchEnd = depthSearchStart + height_scale;
	    float inverseDepthFactor = 1.0 / height_scale;

	    // This is the relative position at which we begin searching for intersection.
	    // It is adjusted according to the depthOffset, raising or lowering the whole surface by depthOffset units.
	    vec3 parallaxOffset = -dirToCameraTS.xyz * dirToCameraZInverse * depthOffset;

	    float currentSample = height(base_uv + parallaxOffset.xy);
	    float prevSample;

	    // Do a basic search for the intersect step
	    while(currentSample > currentStep) {
	        currentStep += steps;
	        parallaxOffset += delta;

	        prevSample = currentSample;
	        currentSample = GetNormalizedDepth(depthSearchStart, depthSearchEnd, inverseDepthFactor, base_uv + parallaxOffset.xy);
	    }

	    if(currentStep > 0.0)
	    {
	        // Contact refinement propose by Andrea Riccardi
	        // https://www.artstation.com/andreariccardi/blog/3VPo/a-new-approach-for-parallax-mapping-presenting-the-contact-refinement-parallax-mapping-technique

	        // Based on the rough approximation, rolling back to the previous step along the ray.
	        parallaxOffset -= delta;
	        currentStep -= steps;
	        currentSample = prevSample;

	        // Adjust precision
	        vec3 adjustedDelta = delta * steps;
	        float adjustedStep = steps * steps;

	        // Uses another loop with the same step numbers, this times only covers the distance between previous point and the rough intersection point.
	        while(currentSample > currentStep)
	        {
	            currentStep += adjustedStep;
	            parallaxOffset += adjustedDelta;
	            prevSample = currentSample;

	            currentSample = GetNormalizedDepth(depthSearchStart, depthSearchEnd, inverseDepthFactor, base_uv + parallaxOffset.xy);
	        }
	    }
	    if(parallaxOffset.z > 0.0)
	    {
	        parallaxOffset = vec3(0.0);
	    }

		base_uv += parallaxOffset.xy;
		return base_uv;
	}



vec3 filtered_normals( in vec2 uvw)
{
float detail= 100.;
vec2 ddx_uvw = uvw+dFdx(uvw);
vec2 ddy_uvw = uvw+dFdy(uvw);
    int sx = 1 + int( clamp( detail*length(ddx_uvw-uvw), 0.0, float(MaxSamples-1) ) );
    int sy = 1 + int( clamp( detail*length(ddy_uvw-uvw), 0.0, float(MaxSamples-1) ) );

	vec3 no = vec3(0.0);

    for( int j=0; j<sy; j++ )
    for( int i=0; i<sx; i++ )
    {
        vec2 st = vec2( float(i), float(j) ) / vec2( float(sx),float(sy) );
        no += normalFromHeight( uvw + st.x*(ddx_uvw-uvw) + st.y*(ddy_uvw-uvw),0.001,0.1);
    }

	return no / float(sx*sy);
}



void fragment() {
	vec2 mp = planarMap(w_pos,w_norm)*mult;
	vec3 dirToCameraTS = normalize(normalize(VIEW) * mat3(TANGENT, -BINORMAL, NORMAL));
	mp=parallax(mp,dirToCameraTS);
	vec3 normal =filtered_normals(mp);


	ALBEDO=color(mp);
	NORMAL_MAP=normal;
	NORMAL_MAP_DEPTH=normal_depth;
	SPECULAR = specular;
	ROUGHNESS = roughness;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
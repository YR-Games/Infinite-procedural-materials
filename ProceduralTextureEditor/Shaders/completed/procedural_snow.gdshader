shader_type spatial;
render_mode world_vertex_coords;
uniform float mult;
group_uniforms height;
uniform float heightmap_scale : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform int heightmap_layers : hint_range(8, 128, 1) = 32;
uniform float depthOffset : hint_range(0.0, 1.0, 0.1) = 0;
varying vec3 w_pos;
varying vec3 w_norm;

#include "shader_modules/library.gdshaderinc"


void vertex(){
	    w_norm = NORMAL;
		w_pos = VERTEX;
	}

	float tile(vec2 uv){
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);

	float r = max(abs(smth.x),abs(smth.y))*2.;
	float a = atan(smth.y,smth.x);
 			float f1 =1.;
    		f1=smoothstep(f1-0.2,f1,r);

    return f1;
}



float height(vec2 uv){

	return pfbm(uv*0.25,1.,1.5,0.5)+pfbm(uv,0.05,2.,0.5);
}


vec3 normalFromHeight(vec2 uv,float offset,float mlp){

		vec2 nuv = vec2(uv.x+offset,uv.y);
    vec3 fa = vec3(nuv.x, 0.0,height(nuv)*mlp);

	    nuv = vec2(uv.x,uv.y-offset);
    vec3 fc = vec3(0.0, nuv.y,height(nuv)*mlp);

		 nuv = vec2(uv.x-offset,uv.y);
    vec3 fb = vec3(nuv.x, 0.0,height(nuv)*mlp);

	    nuv = vec2(uv.x,uv.y+offset);
    vec3 fd = vec3(0.0, nuv.y,height(nuv)*mlp);

	return 0.5+normalize(cross(fa-fb*vec3(1.,0.,1.), fc-fd*vec3(0.,1.,1.)))*vec3(1.,-1.,1.);
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






void fragment() {
	vec2 mp = planarMap(w_pos,w_norm)*mult;
	vec3 dirToCameraTS = normalize(normalize(VIEW) * mat3(TANGENT, -BINORMAL, NORMAL));
	mp=parallax(mp,dirToCameraTS);
	vec3 normal = normalFromHeight(mp,0.001,0.1);

	ALBEDO=vec3(0.9);//smoothstep(0.,1.,pfbm(mp*4.,0.1,0.5,1.)-1.2)
	//ALBEDO=normal;
	SPECULAR =1.3;
	ROUGHNESS =1.-smoothstep(0.,1.,pfbm(mp*64.,0.1,0.5,1.)-0.9);
	NORMAL_MAP=normal;
	SSS_STRENGTH =1.;
	SSS_TRANSMITTANCE_COLOR=vec4(0.75);


	//SPECULAR =1.180;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
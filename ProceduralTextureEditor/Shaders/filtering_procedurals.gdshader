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


float checkersTextureGradBox( in vec2 p, in vec2 ddx, in vec2 ddy )
{
    // filter kernel
    vec2 w = max(abs(ddx), abs(ddy)) + 0.01;
    // analytical integral (box filter)
    vec2 i = 2.0*(abs(fract((p-0.5*w)/2.0)-0.5)-abs(fract((p+0.5*w)/2.0)-0.5))/w;
    // xor pattern
    return 0.5 - 0.5*i.x*i.y;
}

float checkersTexture( in vec2 p )
{
    vec2 q = floor(p);
    return mod( q.x+q.y, 2.0 );            // xor pattern
}



float height(vec2 uv){
	//return checkersTextureGradBox(uv,dFdx(uv),dFdy(uv));
	return tile(uv);
}

vec4 heightAndNormal(vec2 uv){
	vec2 fuv = fract(uv);
	vec2 iuv = floor(uv);
	float h = bn(iuv.xx)*fuv.x+bn(iuv.yy)*fuv.y;
	vec3 normal = vec3(bn(iuv.xx),(bn(iuv.yy)),0.);
	return vec4(normal,h);
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



const int MaxSamples = 6;  // 10*10

// sample a procedural texture with filtering
vec3 sampleTextureWithFilter( in vec2 uvw, in vec2 ddx_uvw, in vec2 ddy_uvw,in float detail)
{
    int sx = 1 + int( clamp( detail*length(ddx_uvw-uvw), 0.0, float(MaxSamples-1) ) );
    int sy = 1 + int( clamp( detail*length(ddy_uvw-uvw), 0.0, float(MaxSamples-1) ) );

	vec3 no = vec3(0.0);

    for( int j=0; j<sy; j++ )
    for( int i=0; i<sx; i++ )
    {
        vec2 st = vec2( float(i), float(j) ) / vec2( float(sx),float(sy) );
        no += height( uvw + st.x*(ddx_uvw-uvw) + st.y*(ddy_uvw-uvw));
    }

	return no / float(sx*sy);
}


void fragment() {
	vec3 world_camera = (INV_VIEW_MATRIX * vec4(vec3(0.0), 1.0)).xyz;
	vec4 a = INV_VIEW_MATRIX * vec4(VERTEX, 1.0);
	float d = distance(a.xyz, world_camera)*0.0005;
	vec2 mp = planarMap(w_pos,w_norm)*mult;
	vec3 dirToCameraTS = normalize(normalize(VIEW) * mat3(TANGENT, -BINORMAL, NORMAL));

	//mp=parallax(mp,dirToCameraTS);
	//vec3 normal = normalFromHeight(mp,0.001,0.1);
	//vec3 normal =heightAndNormal(mp).xyz;
	//ALBEDO=vec3(heightAndNormal(mp).w);
	//ALBEDO=vec3(normal.xy,0.);
	//ALBEDO=vec3(height(mp));
	vec2 uvwX = mp+dFdx(mp); // X offset
    vec2 uvwY = mp+dFdy(mp); // Y offset

	ALBEDO=vec3(sampleTextureWithFilter(mp,uvwX,uvwY,10.));
	//NORMAL_MAP=0.5+abs(normal);

	//SPECULAR =1.180;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
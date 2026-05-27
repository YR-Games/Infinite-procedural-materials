shader_type spatial;

//#include "shader_modules/library.gdshaderinc"
#include "shader_modules/cell_noise.gdshaderinc"
#include "shader_modules/voronoi.gdshaderinc"
#include "shader_modules/FBMNoise.gdshaderinc"
#include "shader_modules/gradient_noise.gdshaderinc"
#include "shader_modules/1dNoises.gdshaderinc"
const int numOctaves = 10;


float cfbm( in vec2 x, in float H )
{    
    float G = exp2(-H);
    float f = 1.0;
    float a = 1.0;
    float t = 0.0;
    for( int i=0; i<numOctaves; i++ )
    {
        t += a*cellTiling(f*x);
        f *= 2.;
        a *= G;
    }
    return t;
}


float gradfbm( in vec2 x, in float H )
{    
    float G = exp2(-H);
    float f = 1.0;
    float a = 1.0;
    float t = 0.0;
    for( int i=0; i<numOctaves; i++ )
    {
        t += a*gradient_noise(f*x);
        f *= 2.;
        a *= G;
    }
    return t*0.5+0.5;
}

vec3 linearPalette(float t) {
    // Linear RGB
    vec3 colors[7] = vec3[](
        vec3(0.039, 0.037, 0.031),
        vec3(0.076, 0.074, 0.069),
        vec3(0.107, 0.106, 0.101),
        vec3(0.136, 0.135, 0.132),
        vec3(0.165, 0.164, 0.162),
        vec3(0.193, 0.192, 0.191),
        vec3(0.219, 0.219, 0.218)
    );
    float f = clamp(t, 0.0, 1.0) * 6.0;
    int i = clamp(int(f), 0, 5);
    return clamp(mix(colors[i], colors[i + 1], fract(f)), 0.0, 1.0);
}


void fragment() {
vec2 uv = UV*16.;




//uv=mix(uv,vec2(cfbm(uv,1.)),0.008);
vec3 col=vec3(gradfbm(uv,0.5));//cfbm(uv,1.));
//col=vec3(cellTiling(uv));//gradient_noise(uv)*.5+.5);
ALBEDO=linearPalette(col.x);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

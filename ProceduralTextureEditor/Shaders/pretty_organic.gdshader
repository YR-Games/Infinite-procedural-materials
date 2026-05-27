shader_type spatial;

//#include "shader_modules/library.gdshaderinc"
#include "shader_modules/cell_noise.gdshaderinc"
#include "shader_modules/voronoi.gdshaderinc"
#include "shader_modules/FBMNoise.gdshaderinc"
const int numOctaves = 6;


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


void fragment() {
vec2 uv = UV*16.;


uv=mix(uv,vec2(cfbm(uv,1.)),0.8);
vec3 col=vec3(fbm(uv));//cfbm(uv,1.));
ALBEDO=col*0.1;
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

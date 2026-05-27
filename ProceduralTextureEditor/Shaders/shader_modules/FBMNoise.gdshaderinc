#include "Snoise.gdshaderinc"
#include "GNoise.gdshaderinc"
#include "VNoise.gdshaderinc"

float fbm (in vec2 st) {
    // Initial values
    float value = 0.5;
    float amplitude = 0.25;
    float frequency = 2.;
    //
    // Loop of octaves
    for (int i = 0; i < 6; i++) {
        value += amplitude * snoise(st);//wn(st,1.)
        st *= 2.;
        amplitude *= 0.5;
    }
    return value;
}


const mat3 m3  = mat3(vec3( 0.00,  0.80,  0.60),
                      vec3(-0.80,  0.36, -0.48),
                      vec3(-0.60, -0.48,  0.64) );
const mat3 m3i = mat3(vec3(0.00, -0.80, -0.60),
                      vec3( 0.80,  0.36, -0.48),
                      vec3( 0.60, -0.48,  0.64));



vec4 gfbm( in vec3 x, in int octaves )
{
    float f = 1.98;  // could be 2.0
    float s = 0.49;  // could be 0.5
    float a = 0.0;
    float b = 0.5;
    vec3  d = vec3(0.0,0.0,0.0);
    mat3  m = mat3(vec3(1.0,0.0,0.0),
                   vec3(1.0,0.0,0.0),
                   vec3(1.0,0.0,0.0));
    for( int i=0; i<octaves; i++ )
    {
        vec4 n = gnoised(x);
        a += b*n.x;          // accumulate values
        d += b*m*n.yzw;      // accumulate derivatives
        b *= s;
        x = f*m3*x;
        m = f*m3i*m;
    }
    return vec4( a, d );
}


vec4 vfbm( in vec3 x, in int octaves )
{
    float f = 1.98;  // could be 2.0
    float s = 0.49;  // could be 0.5
    float a = 0.0;
    float b = 0.5;
    vec3  d = vec3(0.0,0.0,0.0);
    mat3  m = mat3(vec3(1.0,0.0,0.0),
                   vec3(1.0,0.0,0.0),
                   vec3(1.0,0.0,0.0));
    for( int i=0; i<octaves; i++ )
    {
        vec4 n = vnoised(x);
        a += b*n.x;          // accumulate values
        d += b*m*n.yzw;      // accumulate derivatives
        b *= s;
        x = f*m3*x;
        m = f*m3i*m;
    }
    return vec4( a, d );
}


float pfbm (in vec2 st,float starting,float freqmul,float ampmul) {
    float amp = starting;
  	float value=1.;

    for (int i = 0; i < 6; i++) {
        value += amp * snoise(st);//wn(st,1.)
        st *= freqmul;
        amp *= ampmul;
    }
    return value;
}

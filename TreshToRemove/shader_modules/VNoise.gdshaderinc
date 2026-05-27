#include "Hash.gdshaderinc"

vec4 vnoised( in vec3 x )
{
    vec3 p = floor(x);
    vec3 w = fract(x);

    vec3 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    vec3 du = 30.0*w*w*(w*(w-1.0)+2.0);

    float a = hash13( p+vec3(0,0,0) );
    float b = hash13( p+vec3(1,0,0) );
    float c = hash13( p+vec3(0,1,0) );
    float d = hash13( p+vec3(1,1,0) );
    float e = hash13( p+vec3(0,0,1) );
    float f = hash13( p+vec3(1,0,1) );
    float g = hash13( p+vec3(0,1,1) );
    float h = hash13( p+vec3(1,1,1) );

    float k0 =   a;
    float k1 =   b - a;
    float k2 =   c - a;
    float k3 =   e - a;
    float k4 =   a - b - c + d;
    float k5 =   a - c - e + g;
    float k6 =   a - b - e + f;
    float k7 = - a + b + c - d + e - f - g + h;

    return vec4( -1.0+2.0*(k0 + k1*u.x + k2*u.y + k3*u.z + k4*u.x*u.y + k5*u.y*u.z + k6*u.z*u.x + k7*u.x*u.y*u.z),
                 2.0*du *vec3( k1 + k4*u.y + k6*u.z + k7*u.y*u.z,
                               k2 + k5*u.z + k4*u.x + k7*u.z*u.x,
                               k3 + k6*u.x + k5*u.y + k7*u.x*u.y ) );
}

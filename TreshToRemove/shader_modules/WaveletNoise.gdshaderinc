#include "rotate2d.gdshaderinc"
#include "random.gdshaderinc"

float wavelet(vec2 p, float phase, float k) {
    float d = 0.0, s = 1.0, m=0.0, a = 0.0;
    for (float i = 0.0; i < 4.0; i++) {
        vec2 q = p*s;
        a = random(floor(q)) * 1e3;
        q = (fract(q) - 0.5) * rotate2d(a);
        d += sin(q.x * 10.0 + phase) * smoothstep(.25, 0.0, dot(q,q)) / s;
        p = p * mat2(vec2(.54,-0.84),vec2( 0.84, 0.54)) + i;
        m += 1.0 / s;
        s *= k;
    }
    return d / m;}


float wn(vec2 p, float phase) {
    return wavelet(p, phase, 1.24);}


	float wn3(vec3 p, float k) {
    return wavelet(p.xy, p.z, k);
}
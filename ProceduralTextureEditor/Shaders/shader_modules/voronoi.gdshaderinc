#include "random2.gdshaderinc"
#define VORONOI_RANDOM_FNC(uv) ( 0.5 + 0.5 * sin(time + TAU * random2(uv) ) );

vec3 voronoi(vec2 uv, float time) {
    vec2 i_uv = floor(uv);
    vec2 f_uv = fract(uv);
    vec3 rta = vec3(0.0, 0.0, 10.0);
    for (int j=-1; j<=1; j++ ) {
        for (int i=-1; i<=1; i++ ) {
            vec2 neighbor = vec2(float(i),float(j));
            vec2 point = VORONOI_RANDOM_FNC(i_uv + neighbor);
            point = 0.5 + 0.5 * sin(time + TAU * point);
            vec2 diff = neighbor + point - f_uv;
            float dist = length(diff);
            if ( dist < rta.z ) {
                rta.xy = point;
                rta.z = dist;
            }
        }
    }
    return rta;}

vec3 vor2(vec2 p)  { return voronoi(p, 0.0); }
vec3 vor3(vec3 p)  { return voronoi(p.xy, p.z); }
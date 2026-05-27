shader_type spatial;
//render_mode depth_draw_always;
uniform vec2 scale;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;
uniform sampler2D sed:filter_linear;

#include "shader_modules/library.gdshaderinc"
      // random point
struct ThreePoints {
    vec2 p1;
    vec2 p2;
    vec2 p3;
};

ThreePoints tri_voronoi(vec2 uv) {
    vec2 cell = floor(uv);
	vec2 f_uv = fract (uv);
    vec2 p1 = vec2(0.0);
    vec2 p2 = vec2(0.0);
    vec2 p3 = vec2(0.0);
    float d1 = 1e10;
    float d2 = 1e10;
    float d3 = 1e10;

    // Check 3x3 neighborhood of cells
    for (int i = -1; i <= 1; i++) {
        for (int j = -1; j <= 1; j++) {
            vec2 offset = vec2(float(i), float(j));
            vec2 point = hash22(cell + offset);
            vec2 diff = offset + point - f_uv;
            float dist = length(diff);  // Position the point in the same space as uv

            if (dist < d1) {
                d3 = d2; p3 = p2;
                d2 = d1; p2 = p1;
                d1 = dist; p1 = point;

            } else if (dist < d2) {
                d3 = d2; p3 = p2;
                d2 = dist; p2 = point;

            } else if (dist < d3) {
                d3 = dist; p3 = point;

            }
        }
    }

    return ThreePoints(p1, p2, p3);
}

float sdTriangle( in vec2 p, in vec2 p0, in vec2 p1, in vec2 p2 )
{
    vec2 e0 = p1-p0, e1 = p2-p1, e2 = p0-p2;
    vec2 v0 = p -p0, v1 = p -p1, v2 = p -p2;
    vec2 pq0 = v0 - e0*clamp( dot(v0,e0)/dot(e0,e0), 0.0, 1.0 );
    vec2 pq1 = v1 - e1*clamp( dot(v1,e1)/dot(e1,e1), 0.0, 1.0 );
    vec2 pq2 = v2 - e2*clamp( dot(v2,e2)/dot(e2,e2), 0.0, 1.0 );
    float s = sign( e0.x*e2.y - e0.y*e2.x );
    vec2 d = min(min(vec2(dot(pq0,pq0), s*(v0.x*e0.y-v0.y*e0.x)),
                     vec2(dot(pq1,pq1), s*(v1.x*e1.y-v1.y*e1.x))),
                     vec2(dot(pq2,pq2), s*(v2.x*e2.y-v2.y*e2.x)));
    return -sqrt(d.x)*sign(d.y);
}

float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}


vec2 p_distr(vec2 uv){
	return hash22(uv);
}

vec2 warped_coords(vec2 uv) {
    vec2 i_uv = floor(uv*2.);
	vec2 c_uv = i_uv+vec2(1.);
    vec2 f_uv = fract(uv*2.);


	vec2 a =p_distr(i_uv);
	vec2 b =p_distr(vec2(c_uv.x,i_uv.y));
	vec2 c =p_distr(vec2(i_uv.x,c_uv.y));
	vec2 d =p_distr(c_uv);


   //f_uv = f_uv * f_uv * (3.0 - 2.0 * f_uv);


    vec2 offset = mix(
        mix(a, b, f_uv.x),
        mix(c, d, f_uv.x),
        f_uv.y
    );

    return uv + offset;
}

void vertex(){
w_norm = NORMAL;
w_pos = VERTEX;
}

void fragment() {
	   vec3 anorm=abs(w_norm);
	vec3 v=w_pos;
	v.x*=floor(sign(w_norm.z));
	v.z*=-floor(sign(w_norm.x));
	v.y=-v.y;
	vec2 mp =mix(v.xy,v.zy,round(anorm.x));
	mp=mix(mp,w_pos.xz*-sign(w_norm.y),round(anorm.y));

	mp*=scale;
	//mp=warped_coords(mp);


// texture(sed,vec2(a/36.+id.x*id.y/36.,0.)).x) - 0.1;
//colorize(outp*2.,vec3(1.0, 1.0, 1.0),vec3(0.5, 0.5, 0.5),vec3(1., 1., 1.),vec3(0., 0.33, 0.67))
vec3 color=vec3(0.);
vec2 iuv = floor(mp);
vec2 fuv =mp-iuv;
color += (step(.98, fuv.x) + step(.98, fuv.y));


ThreePoints res = tri_voronoi(mp);

float dist = sdSegment(fuv,res.p1,res.p2);
dist = min(dist, sdSegment(fuv,res.p2,res.p3));
dist = min(dist, sdSegment(fuv,res.p1,res.p3));


    ALBEDO = vec3(dist);//hash32(res.p1+res.p2+res.p3)+color;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
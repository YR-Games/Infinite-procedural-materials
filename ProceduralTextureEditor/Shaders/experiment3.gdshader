shader_type spatial;
uniform float xc :hint_range(0.0, 1.0, 0.01);
uniform float yc :hint_range(0.0, 1.0, 0.01);

#include "shader_modules/library.gdshaderinc"

void vertex() {
	// Called for every vertex the material is visible on.
}

float opXor( float a, float b )
{
    return max(min(a,b),-max(a,b));
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

void fragment() {
	vec2 uv = UV*64.;

	float a =bn(uv*vec2(1.,2.))*2.-1.;
	float b =bn(uv*vec2(2.,1.)+vec2(1643.,0.))*2.-1.;
	float c =bn(uv+vec2(156.,123.))*2.-1.;

	
	a=max(a,b);
	a=max(a,b);
	vec3 dis = vec3(a,b,c);
	ALBEDO=vec3(abs(a));//vec3(smoothstep(0.,0.5,a));
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

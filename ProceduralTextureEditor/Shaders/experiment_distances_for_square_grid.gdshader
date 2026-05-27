shader_type spatial;
uniform float xc :hint_range(0.0, 1.0, 0.01);
uniform float yc :hint_range(0.0, 1.0, 0.01);
uniform sampler2D buv:source_color;

#include "shader_modules/library.gdshaderinc"

void vertex() {
	// Called for every vertex the material is visible on.
}

float opXor( float a, float b )
{
    return max(min(a,b),-max(a,b));
}

float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}

float sdLine( in vec2 p, vec2 a, vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float s = (ba.x*ba.y>0.0)?1.0:-1.0;
    float h = clamp( (pa.y+s*pa.x)/(ba.y+s*ba.x), 0.0, 1.0 );
    vec2 q = abs(pa-h*ba);
    return max(q.x,q.y);
}

float sdRoundedX( in vec2 p, in float w, in float r )
{
    p = abs(p);
    return length(p-min(p.x+p.y,w)*0.5) - r;
}

void fragment() {
	vec2 uv = (UV)*1.;
	//float clearanc =uv.x; //a+b
	//float midsur =uv.y; //a-b
	vec4 t=texture(buv,uv);
	uv=t.xy;
	float a = (uv.x+uv.y)*0.5;
	float b = uv.x-a;
	//float a = sdRoundedX(uv*vec2(0.5,1.),100.,0.);//sdSegment(uv,vec2(-50.,-100.),vec2(50.,100.));
	//float b = sdRoundedX(uv*vec2(0.5,1.)+vec2(2.),100.,0.);//sdSegment(uv,vec2(-50.,50.),vec2(50.,-50.));
	
	float clrnc=a+b;
	float midsurf=a-b;
	vec2 coord = vec2(clrnc,midsurf);
	vec2 iuv= floor(coord);
	vec2 fuv= coord-iuv;

	vec3 grid = vec3((step(.95, fuv.x) + step(.95, fuv.y)));
	
	ALBEDO=vec3(step(a,0.5));//vec3(smoothstep(0.,0.5,a));
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

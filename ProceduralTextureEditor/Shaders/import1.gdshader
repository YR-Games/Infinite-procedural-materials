shader_type spatial;
render_mode unshaded;
uniform vec2 scale;
uniform float normal_power;




#include "shader_modules/cell_noise.gdshaderinc"
#include "shader_modules/library.gdshaderinc"

float sdCircle( vec2 p, float r )
{
    return length(p) - r;
}

float sdBox( in vec2 p, in vec2 b )
{
    vec2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}


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


vec3 linearPalette(float t) {
    // Linear RGB
    vec3 colors[5] = vec3[](
        vec3(0.08, 0.08, 0.065),
        vec3(0.143, 0.142, 0.131),
        vec3(0.173, 0.172, 0.184),
        vec3(0.132, 0.131, 0.143),
        vec3(0.232, 0.20, 0.24)
    );
    float f = clamp(t, 0.0, 1.0) * 4.0;
    int i = clamp(int(f), 0, 3);
    return clamp(mix(colors[i], colors[i + 1], fract(f)), 0.0, 1.0);
}



vec2 brickmap( in vec2 p, in vec2 s ){
	p*=s;
    vec2 id=round(p);
	p.x+=id.y*0.5;
	id=round(p);
    return vec2(p-id);
    }


void fragment() {

	vec2 mp=UV;

	mp=UV*scale;
	//vec3 pmap = map(mp);
	vec4 bm = brickmap(mp,vec2(0.5,1.));
	float bd = sdBox(bm.zw,vec2(0.45,0.45));
		vec2 fuv= bm.zw;

	vec3 grid = vec3((step(.95, fuv.x) + step(.95, fuv.y)));
	vec2 uv = fuv+bm.x*333.+bm.y*745.;
	uv=mix(uv,vec2(cfbm(uv,1.)),hash12(bm.xy)*0.5+0.5);

	
	ALBEDO=vec3(brickmap(mp,vec2(0.5,1.)));


}

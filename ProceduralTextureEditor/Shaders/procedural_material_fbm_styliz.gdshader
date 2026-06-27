shader_type spatial;

uniform vec2 scale;

#include "shader_modules/library.gdshaderinc"





float sdSegment( in vec2 p, vec2 a, vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float s = (ba.x*ba.y>0.0)?1.0:-1.0;
    float h = clamp( (pa.y+s*pa.x)/(ba.y+s*ba.x), 0.0, 1.0 );
    vec2 q = abs(pa-h*ba);
    return max(q.x,q.y);
}

float shape3( in vec2 p, in vec2 id ){
vec4 ends = hash42(id)*1.4-0.7;
    return sdSegment(p,-ends.xy,ends.zw);
}


vec3 map3( in vec2 p ){
   const vec2 s = vec2(1.5,1.5);
        vec2 id = round(p/s);
		vec2 id_out=vec2(0.);
        vec2 off = sign(p-s*id);

        float d = 1e20;
        for( float j=0.; j<2.; j++ )
        for( float i=0.; i<2.; i++ )
        {
            vec2 rid = id + vec2(i,j)*off;
           // rid = clamp(rid,-rep,rep); // limited repetition
            vec2 r = p - s*rid;
            //d = min( d, shape(r,rid) );
			if(d>shape3(r,rid)){
				d=shape3(r,rid);
				id_out=rid;
			}
        }
        return vec3(d,id_out);
    }

const int numOctaves = 8;
float fbm( in vec2 x, in float H )
{    
    float G = exp2(-H);
    float f = 1.0;
    float a = 0.4;
    float t = 0.0;
    for( int i=0; i<numOctaves; i++ )
    {
        t += a*map3(f*x).x;
        f *= 2.0;
        a *= G;
    }
    return t;
}

void fragment() {

	vec2 uv =UV*scale;

	float weier=fbm(uv,1.)*0.5;
    ALBEDO = vec3(weier);

}
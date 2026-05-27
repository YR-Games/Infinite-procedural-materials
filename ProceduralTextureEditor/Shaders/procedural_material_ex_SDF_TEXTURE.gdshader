shader_type spatial;
uniform float mult;
uniform float normal_power;
uniform sampler2D sed:filter_linear;
varying vec3 w_pos;
varying vec3 w_norm;


#include "shader_modules/library.gdshaderinc"

float sdLine( in vec2 p, vec2 a, vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float s = (ba.x*ba.y>0.0)?1.0:-1.0;
    float h = clamp( (pa.y+s*pa.x)/(ba.y+s*ba.x), 0.0, 1.0 );
    vec2 q = abs(pa-h*ba);
    return max(q.x,q.y);
}

float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}

vec2 sp(in vec2 id){


return random2(id);
}
float shape( in vec2 p, in vec2 id )
{
//p.y*=2.;
//float shift = mod(id.y,2.);
//float shift2=abs(bn(id+TIME));
//mat2 rot =rotate2d(id.x*PI+TIME);
vec2 ps=vec2(0.,0.5);
vec2 a =vec2(-1.,0.);
vec2 b = vec2(1.,0.);

if(mod(id.x+id.y,2.)==0.){
	a=vec2(0.,0.);
	b=vec2(0.,1.);
}

    return sdSegment(p,a,b);
}

//-----------------------------

vec3 map( in vec2 p )
{
   const float s = 1.;
    //const vec2 rep = vec2(2,1);
		//p=warped_coords(p);
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
			if(d>shape(r,rid)){
				d=shape(r,rid);
				id_out=rid;
			}
        }
        return vec3(d,id_out);
    }


vec4 mat(vec2 uv){
	vec3 mp =map(uv);
	float f_out =smoothstep(0.,0.1,mp.x);
    return vec4(floor(bn(mp.yz*64.2)*8.)/8.,0.,0.,f_out);
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

	mp*=mult;

    vec4 outp = mat(mp);

		float offset = 0.001;
		float mlp = 0.1;

		vec2 nuv = vec2(mp.x+offset,mp.y);
    vec3 fa = vec3(nuv.x, 0.0,mat(nuv).w*mlp);;

	    nuv = vec2(mp.x,mp.y-offset);
    vec3 fc = vec3(0.0, nuv.y,mat(nuv).w*mlp);

		 nuv = vec2(mp.x-offset,mp.y);
    vec3 fb = vec3(nuv.x, 0.0,mat(nuv).w*mlp);

	    nuv = vec2(mp.x,mp.y+offset);
    vec3 fd = vec3(0.0, nuv.y,mat(nuv).w*mlp);

	vec3 normal = 0.5+normalize(cross(fa-fb*vec3(1.,0.,1.), fc-fd*vec3(0.,1.,1.)))*vec3(1.,-1.,1.);

// Цветовая интерполяция между тремя точками



	//ALBEDO=vec3(mat(mp).x);


	ALBEDO=mat(mp).xxx;
	//ALBEDO=vec3(abs(col.x - col.y) + abs(col.y - col.z) + abs(col.z - col.x));
	//ALBEDO=vec3(vor(mp,0.1).y);
   // ROUGHNESS = 0.5;
	NORMAL_MAP=normal;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
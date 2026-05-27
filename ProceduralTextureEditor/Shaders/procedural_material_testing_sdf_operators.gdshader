shader_type spatial;
//render_mode depth_draw_always;
uniform vec2 scale;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;


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

/*
float shape( in vec2 p, in vec2 id ){
vec2 b = vec2(0.,0.75);
vec2 shift = vec2(0.5,0.)*mod(id.y,2.);
if(id==vec2(0.)){shift=vec2(0.,0.5);}
    return sdBoxL(p+shift,b);
}
*/


float shape( in vec2 p, in vec2 id ){

vec2 b = vec2(0.4,0.2);
vec2 shift =vec2(0.5,0.)*mod(id.y,2.);
    return sdBox(p+shift,b);
}

float shape2( in vec2 p, in vec2 id ){
float r=abs(bn(id));
p+=random2(id)*0.5;
    return sdCircle(p,r);
}

vec3 map( in vec2 p ){
   const vec2 s = vec2(1.,0.6);
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

vec3 map2( in vec2 p ){
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
			if(d>shape2(r,rid)){
				d=shape2(r,rid);
				id_out=rid;
			}
        }
        return vec3(d,id_out);
    }


float opXor( float a, float b )
{
    return max( min(a,b), -max(a,b) );
}

float sdCross( in vec2 p, in vec2 b, float r ) 
{
    p = abs(p); p = (p.y>p.x) ? p.yx : p.xy;
    vec2  q = p - b;
    float k = max(q.y,q.x);
    vec2  w = (k>0.0) ? q : vec2(b.y-p.x,-k);
    return sign(k)*length(max(w,0.0)) + r;
}


vec2 split(in vec2 uv,in float split_point, in vec2 bounds) {
vec2 new_bounds;
uv.y< split_point ? new_bounds=vec2(split_point,bounds.x) : new_bounds=vec2(split_point,bounds.y);
    return new_bounds;
}

vec3 map3( in vec2 p ){

		vec2 id_out=vec2(1.);
		/*
     	float d = sdBox(p,vec2(0.5,0.5));
	    float b = sdBox(p-vec2(0.25,0.5),vec2(0.5,0.5));
		float c = sdBox(p-vec2(0.25,0.5),vec2(0.75,0.5));
		*/
		float d = sdCross(p,vec2(2.,0.6),0.);
	    float b = sdCross(p-vec2(0.,0.5),vec2(1.,0.33),0.);
		float c = sdCross(p-vec2(0.25,0.5),vec2(1.,0.33),0.);
		d = opXor(d,b);
		//d = min(d,opXor(d,b));
		d = opXor(d,c);
		//d=opXor(opXor(d,c),b);
        return vec3(d,id_out);
    }


vec3 map4( in vec2 p ){
vec2 upper_bound = ceil(p);
vec2 lower_bound = floor(p);
vec2 fuv = fract(p);
vec4 bounds = vec4(lower_bound.x,upper_bound.x,lower_bound.y,upper_bound.y);

vec2 test = vec2(lower_bound.x,split(fuv,hash11(lower_bound.x),bounds.zw).y);
vec2 test2 = vec2(upper_bound.x,split(fuv,hash11(upper_bound.x),bounds.zw).y);

		vec2 id_out=vec2(1.);

		float d = -abs(fuv.x-hash11(upper_bound.x));
	    //float b = sdCross(p-vec2(0.,0.5),vec2(1.,0.33),0.);
		//float c = sdCross(p-vec2(0.25,0.5),vec2(1.,0.33),0.);
		d = opXor(d,abs(fuv.y-hash11(upper_bound.y)));
		//d = opXor(d,abs(length(fuv)-hash11(length(upper_bound))));
		//d = min(d,opXor(d,b));
		//d = opXor(d,c);
		//d=opXor(opXor(d,c),b);
        return vec3(d,id_out);
    }

vec3 map5( in vec2 p ){
   const vec2 s = vec2(0.5,0.5);
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
	vec3 sdf_map = map4(uv);
	vec3 color_map = vec3(sin(map4(uv).x));
	float height = smoothstep(0.0,-0.05,sdf_map.x);
	float roughness_map =0.5;//fbm(uv+sdf_map.yz);
    return vec4(abs(color_map.y)*height,0.,roughness_map,height);
}

float gain( float x, float k )
{
    float a = 0.5*pow(2.0*((x<0.5)?x:1.0-x), k);
    return (x<0.5)?a:1.0-a;
}

vec3 color2(float t){
	float gain = gain(t,0.25);
	float rand =frand(t*16.)*0.2;
	return  vec3(0.2,0.2,0.1)+gain-rand;
}

vec3 color(float t,vec3 a, vec3 b, vec3 c,vec3 d){

	return  a + b * cos(TAU*(c*t+d));
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

	ALBEDO=color2(outp.x);//colorize(outp.x,vec3(1.0, 1.0, 1.0),vec3(0.5, 0.5, 0.5),vec3(0.5, 0.5, 0.5),vec3(0., 0.1, 0.3));


	ROUGHNESS=outp.z;
	NORMAL_MAP=normal;
	NORMAL_MAP_DEPTH=normal_power;
}


/*
попробовать сгенерировать текстуру вроде хаотичных булыжник или кирпичей 
с помощью SDF операторов - XOR, union и т.д.
*/
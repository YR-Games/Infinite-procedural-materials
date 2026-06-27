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


vec4 brickmap( in vec2 p, in vec2 s ){
	p*=s;
    vec2 id=round(p);
	p.x+=id.y*0.5;
	id=round(p);
    return vec4(id,p-id);
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

	
	ALBEDO=linearPalette(fbm(uv)*smoothstep(0.05,0.,bd));


	//ROUGHNESS=outp.z;
	//NORMAL_MAP=normal;
	//NORMAL_MAP_DEPTH=normal_power;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

vec4 mat(vec2 uv){
	vec3 sdf_map = map(uv);
	vec3 color_map = map2(uv*10.)+0.5;
	float height = smoothstep(0.1,0.07,sdf_map.x+color_map.x*0.01);
	float roughness_map =0.5;//fbm(uv+sdf_map.yz);
    return vec4(bn(sdf_map.yz)*height*fract(length(color_map.yz)),0.,roughness_map,height+color_map.x*0.01);
}


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
*/
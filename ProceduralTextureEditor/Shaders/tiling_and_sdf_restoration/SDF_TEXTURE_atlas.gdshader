shader_type spatial;
uniform vec2 scale;
uniform float normal_power;
uniform sampler2D sdf:filter_linear;
varying vec3 w_pos;
varying vec3 w_norm;


#include "shader_modules/library.gdshaderinc"




float shape(in vec2 p, in vec2 id) {
	const float frames = 1./37.;
	float k = hash12(id);
	p.x=p.x*frames+frames*k*2.;
	//p+=0.125;
	p+=0.5;
	//p+=random2(id);
	//p*=rotate2d(hash12(id));
	//p+=0.5;
    return texture(sdf, p).r;
}

vec3 map( in vec2 p ){
   const float s = 0.5;
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
	vec3 sdf_map = map(uv);
	float color_map =fbm(uv*4.);
	float height = smoothstep(0.5,0.45,sdf_map.x);
	float roughness_map =0.5;//fbm(uv+sdf_map.yz);
    return vec4(bn(sdf_map.yz)*height*color_map,sdf_map.x,roughness_map,height+color_map*0.05);
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


	ALBEDO = color2(outp.x);//colorize(outp.x,vec3(1.0, 1.0, 1.0),vec3(0.5, 0.5, 0.5),vec3(0.5, 0.5, 0.5),vec3(0., 0.1, 0.3));
	ROUGHNESS = outp.z;
	NORMAL_MAP = normal;
	NORMAL_MAP_DEPTH = normal_power;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
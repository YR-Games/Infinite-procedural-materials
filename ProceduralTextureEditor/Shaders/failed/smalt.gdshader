shader_type spatial;
uniform vec2 scale;
uniform float normal_power;
uniform sampler2D img:filter_nearest;
uniform sampler2D grad:source_color;
varying vec3 w_pos;
varying vec3 w_norm;


#include "shader_modules/library.gdshaderinc"

float sdCircle( vec2 p, float r )
{
    return length(p) - r;
}


float shape( in vec2 p, in vec2 id ){
float r=0.5+bn(id);
p+=random2(id)*0.5;
    return sdCircle(p,r);
}

vec3 map( in vec2 p ){
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
			float s = shape(r,rid);
			if(d>s){
				d=s;
				id_out=rid;
			}
        }
        return vec3(d,id_out);
    }




vec4 mat(vec2 uv){
	vec3 sdf_map = map(uv);
	float randomness =bn(sdf_map.yz);
	float height = abs(bn(sdf_map.yz));//smoothstep(sdf_map.x,sdf_map.x+0.5,0.5);
	float roughness_map =height;//fbm(uv+sdf_map.yz);
    return vec4(texture(img,sdf_map.yz/vec2(256.,128.)).x,0.,roughness_map,height);//*randomness*fract(length(sdf_map.yz)+0.5)
}

float gain( float x, float k )
{

    return 1.-0.8*pow((1.-x),1./3.)-0.2;
}

vec3 colorz(float t){
	float gain = gain(t,0.25);
	float rr =frand(t*512.+25.);
	float gr =frand(t*864.+256.);
	float br =frand(t*456.+618.);
	return texture(grad,vec2(t,0.)).xyz;// vec3(0.01+rr*(0.22+gain*0.2),0.15+gr*(0.01+t*0.1),0.08+br*(0.235*(t+0.3)))+gain;
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

		float offset = 0.02;
		float mlp = 0.2;

		vec2 nuv = vec2(mp.x+offset,mp.y);
    vec3 fa = vec3(nuv.x, 0.0,mat(nuv).w*mlp);;

	    nuv = vec2(mp.x,mp.y-offset);
    vec3 fc = vec3(0.0, nuv.y,mat(nuv).w*mlp);

		 nuv = vec2(mp.x-offset,mp.y);
    vec3 fb = vec3(nuv.x, 0.0,mat(nuv).w*mlp);

	    nuv = vec2(mp.x,mp.y+offset);
    vec3 fd = vec3(0.0, nuv.y,mat(nuv).w*mlp);

	vec3 normal = 0.5+normalize(cross(fa-fb*vec3(1.,0.,1.), fc-fd*vec3(0.,1.,1.)))*vec3(1.,-1.,1.);

	ALBEDO=colorz(outp.x);//colorize(outp.x,vec3(1.0, 1.0, 1.0),vec3(0.5, 0.5, 0.5),vec3(0.5, 0.5, 0.5),vec3(0., 0.1, 0.3));
	ROUGHNESS=outp.z;
	NORMAL_MAP=normal;
	NORMAL_MAP_DEPTH=normal_power;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
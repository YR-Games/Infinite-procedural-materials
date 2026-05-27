shader_type spatial;
uniform vec2 scale;
uniform float normal_power;
uniform sampler2D sdf:filter_linear,source_color;
varying vec3 w_pos;
varying vec3 w_norm;


#include "shader_modules/library.gdshaderinc"


float sum( vec3 v ) { return v.x+v.y+v.z; }


vec3 textureNoTile( in vec2 x, float v )
{
    float k = abs(vor2(x*0.5).z); // cheap (cache friendly) lookup

    vec2 duvdx = dFdx( x );
    vec2 duvdy = dFdy( x );

    float l = k*8.0;
    float f = fract(l);

      float ia = floor(l+0.5); // suslik's method (see comments)
    float ib = floor(l);
    f = min(f, 1.0-f)*2.0;

    vec2 offa = sin(vec2(3.0,7.0)*ia); // can replace with any other hash
    vec2 offb = sin(vec2(3.0,7.0)*ib); // can replace with any other hash

    vec3 cola = textureGrad( sdf, x + v*offa, duvdx, duvdy ).xyz;
    vec3 colb = textureGrad( sdf, x + v*offb, duvdx, duvdy ).xyz;

    return mix( cola, colb, smoothstep(0.2,0.8,f-0.1*sum(cola-colb)) );
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


	//vec3 col = textureNoTile( (4.0 + 6.0)*mp, 1. );
	vec3 col =smoothstep(0.25,0.,texture(sdf,mp).xxx);


	ALBEDO =col;// smoothstep(0.32,0.35,col);//colorize(outp.x,vec3(1.0, 1.0, 1.0),vec3(0.5, 0.5, 0.5),vec3(0.5, 0.5, 0.5),vec3(0., 0.1, 0.3));
	//ROUGHNESS = outp.z;
	//NORMAL_MAP = normal;
	NORMAL_MAP_DEPTH = normal_power;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}

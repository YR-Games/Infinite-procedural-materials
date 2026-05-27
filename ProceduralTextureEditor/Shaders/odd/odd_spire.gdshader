shader_type spatial;
//render_mode world_vertex_coords;
uniform float mult;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;

#include "shader_modules/BlueNoise.gdshaderinc"
#include "shader_modules/FBMNoise.gdshaderinc"
#include "shader_modules/PerlinNoise.gdshaderinc"
#include "shader_modules/random2.gdshaderinc"
#include "shader_modules/random.gdshaderinc"
#include "shader_modules/rotate2d.gdshaderinc"
#include "shader_modules/WaveletNoise.gdshaderinc"
#include "shader_modules/voronoi.gdshaderinc"
#include "shader_modules/SmoothMins.gdshaderinc"

float pcurve( float x, float a, float b )
{
    float k = pow(a+b,a+b)/(pow(a,a)*pow(b,b));
    return k*pow(x,a)*pow(1.0-x,b);
}

/*
float hash( uint n )
{   // integer hash copied from Hugo Elias
	n = (n<<13U)^n;
    n = n*(n*n*15731U+789221U)+1376312589U;
    return float(n&uvec3(0x0fffffffU))/float(0x0fffffff);
}
*/

float hash( float p )
{
    p = fract(p * .1031);
    p *= p + 33.33;
    p *= p + p;
    return fract(p);
}

// Basic noise
float brand( in float x )
{
    // setup
    float i = floor(x);
    float f = fract(x);
    float s = sign(fract(x/2.0)-0.5);

    // use some hash to create a random value k in [0..1] from i
  //float k = hash(uint(i));
  //float k = 0.5+0.5*sin(i);
    float k = fract(i*.1731);

    // quartic polynomial
        return 0.5 * s * f * (f - 1.0) * ((16.0 * k - 4.0) * f * (f - 1.0) - 1.0) + 0.5;
}

// Traditional gradient noise
float grand( in float p )
{
    float  i = floor(p);
    float f = fract(p);
	float u = f*f*(3.0-2.0*f);

    float g0 = hash(i)*2.0-1.0;
    float g1 = hash(i+1.)*2.0-1.0;
    return 0.5 + 1.2 * mix(g0 * (f - 0.0), g1 * (f - 1.0), u);
}

////////////////////////////////////

float frand( in float x )
{
    float n = 0.0;
    float s = 1.0;
    for( int i=0; i<9; i++ )
    {
        n += s*brand(x);
        s *= 0.5;
        x *= 2.0;
        x += 0.131;
    }
    return n;
}



float Rcurve(float x){

	//uv+=fbm(uv*0.1)*4.;
	//uv.x+=floor(uv.y)*32.;
	float ix = floor(x);
    float fx = fract(x);

	float smth = fx-0.5;
	float r = abs(smth)+smoothstep(1.+brand(x),brand(x),brand(x*4.));
    float f = 1.;
	float edg = 1.0;
    	float f1 =1.-smoothstep(f-edg,f,r);
		f1 += smoothstep(f,f+edg,r);


    return f1-0.5;//min(f1,f2);
}

vec2 metric(vec2 uv){
	//uv=floor(uv);
	vec2 smth = uv-0.5;
	float r = length(smth)*2.;
	//float r = smin_cube_poly(abs(smth.x),abs(smth.y),length(uv))*2.;
	//float r = max(abs(smth.x),abs(smth.y))*2.;
	float a = atan(smth.y,smth.x);

    return vec2(a,r);

}
vec2 tile(vec2 uv,float d){
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);//+random2(iuv)*0.25;

	float r = length(smth)*2.;
	//float r = max(abs(smth.x),abs(smth.y))*2.;
	float a = atan(smth.y,smth.x);
 			float f = 0.5+bn(iuv*32.)*0.5;//frand(a+brand(length(uv))*PI)*0.6;//cos(a*2.*abs(bn(iuv)+1.)+TIME*bn(iuv));//frand(a+brand(length(uv))*PI)*0.6;
    		d=distance(f,r);
			f=1.-smoothstep(f-0.1,f,r);


    return vec2(f,d);
}

vec2 tileN(vec2 uv){
	//uv+=fbm(uv)*4.;
	vec2 f =tile(uv,0.);
	f+=tile(uv+vec2(0.5),f.y);
	//f+= tile(uv+vec2(0.5),f.y);
	//f+=tile(uv+vec2(0.5,0.),f.y);
	//f+=tile(uv+vec2(0.,0.5),f.y);
	//f=min(tile(uv+vec2(0.5)),f);
	//f=min(tile(uv+vec2(0.5,0.)),f);
	//f=min(tile(uv+vec2(0.,0.5)),f);
	//f+=tile(uv+vec2(0.5));
	//f+=tile(uv+vec2(0.5,0.));
	//f+=tile(uv+vec2(0.,0.5));
	//f=max(tile(uv+vec2(0.5)),f);
	//f=max(tile(uv+vec2(0.5,0.)),f);
	//f=max(tile(uv+vec2(0.,0.5)),f);
    return vec2(f.x);
}


vec2 tile2(vec2 uv){
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);

	float r = length(smth)*2.;
	//float r = max(abs(smth.x),abs(smth.y))*2.;
	float a = atan(smth.y,smth.x);
 			float f = cos(a*3.+TIME);
    		f=1.-smoothstep(f,f,r);

    return smth*f;

}



vec3 colorize(float t,vec3 a, vec3 b, vec3 c,vec3 d){
	return  a + b * cos(TAU*(c*t+d));
}



float lines(vec2 uv){
	//uv.x+=fbm(uv*0.01)*32.;
	//vec2 muv =mix(metric(uv),uv,bn(uv));
	vec2 muv =metric(uv);
	vec2 iuv = floor(muv);
    vec2 fuv = fract(muv);

	vec2 smth = fuv-vec2(0.5,0.5);
	float r = abs(smth.y)*2.;
    float f = cos(muv.x+muv.y+TIME);//fbm(uv);
		//float col1 = (1.-step(f,r))*abs(bn(iuv.xx));
		//	  col1 += (step(f,r))*abs(bn(floor(uv.xx+1.5)));
	    	float f1 =1.-smoothstep(f-0.9,f,r);
		f1 += smoothstep(f,f+0.9,r);

	 muv=uv;
	 iuv = floor(muv);
     fuv = fract(muv);

	smth = fuv-vec2(0.5,0.5);
	 r = abs(smth.y)*2.;
     //f = bn(uv);
		//float col1 = (1.-step(f,r))*abs(bn(iuv.xx));
		//	  col1 += (step(f,r))*abs(bn(floor(uv.xx+1.5)));
	    	float f2 =1.-smoothstep(f-0.1,f,r);
		f2 += smoothstep(f,f+0.1,r);



/*
	r = abs(smth.y)*2.;
    f = bn(iuv.yy);
		//float col1 = (1.-step(f,r))*abs(bn(iuv.xx));
		//	  col1 += (step(f,r))*abs(bn(floor(uv.xx+1.5)));
	    	float f2 =1.-smoothstep(f-0.1,f,r);
		f2 += smoothstep(f,f+0.1,r);
*/


    return f1;//min(f1,f2);
}


vec4 mat(vec2 uv){

	//uv*=rotate2d(PI*cos(TIME));
	float f_out = lines(uv);//tileN(uv);//lines(uv+lines(uv)+lines(uv));
		//f_out=vor2(uv).z;
    return vec4(f_out,0.,0.,f_out);//min(f1,f2);
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
	ALBEDO=vec3(mat(mp).x);//colorize(outp.x,vec3(1., 0.8, 0.5),vec3(0.5, 0.5, 0.3),vec3(0.5, 0.360784, 0.3), vec3(0., 0.2, 0.333333));
	//ALBEDO=vec3(bn(mp+tileN(mp)));
	//ALBEDO=vec3(mat(mp+tile2(mp)).x);
	//SPECULAR = 0.5;
	//METALLIC=0.5;
    //ROUGHNESS = 0.5;
	NORMAL_MAP=normal;
	NORMAL_MAP_DEPTH=normal_power;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
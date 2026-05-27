shader_type spatial;
//render_mode depth_draw_always;
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


float height(vec2 uv){

	uv+=bn(uv);
	float sandwaves =abs(sin(uv.x*16.));
	return abs(mix(sandwaves,1.,2.*cfbm(uv*0.1,1.)));//smoothstep(0.2,0.,sdCircle(uv,1.))
}

vec2 stdNormalMap(vec2 uv){
    float height = height(uv);
    return vec2(-dFdx(height), dFdy(height));
}

vec3 normal(in vec2 uv)
{
	const float OFFS = 0.01;
	const float DPTH = 5.5;
	float R = height( uv+vec2(OFFS,0.0));
	float L = height( uv+vec2(-OFFS,0.0));
	float D = height( uv+vec2(0.0,-OFFS));
	float U = height( uv+vec2(0.0,OFFS));
				 
	float X = (L-R) * .5;
	float Y = (U-D) * .5;

	return normalize(vec3(X, Y, 0.)+0.5);
}

void fragment() {

	vec2 uv=UV-0.5;

	uv*=scale;
	//vec3 pmap = map(mp);

	uv=mix(uv,vec2(cfbm(uv,1.)),0.5);
	vec2 fuv=fract(uv);
	vec3 grid = vec3((step(.95, fuv.x) + step(.95, fuv.y)));
	float h = height(uv);
	
	ALBEDO=vec3(linearPalette(h));//

	//ALBEDO=vec3(h);
	//ALBEDO=vec3(0.);
	//ALBEDO=vec3(stdNormalMap(uv)+vec2(0.5),0.)*0.5;
	//ALBEDO=normal(uv)*0.5;
	ROUGHNESS=1.;
	//NORMAL_MAP=normal(uv);//vec3(stdNormalMap(uv)+vec2(0.5),0.);
	//NORMAL_MAP_DEPTH=1.;
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
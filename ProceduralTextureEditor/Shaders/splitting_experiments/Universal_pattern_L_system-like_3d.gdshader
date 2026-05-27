shader_type spatial;

uniform vec2 scale;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;
uniform sampler2D sed:filter_linear;

// файл для подключения функций
#include "shader_modules/library.gdshaderinc"

//функция распределения точек в ячейках.
vec2 p_distr(vec2 uv){
	return hash22(uv);
}


//функция деформации ячеек
vec2 warped_coords(vec2 uv) {
    vec2 i_uv = floor(uv*2.);
	vec2 c_uv = i_uv+vec2(1.);
    vec2 f_uv = fract(uv*2.);


	vec2 a =p_distr(i_uv);
	vec2 b =p_distr(vec2(c_uv.x,i_uv.y));
	vec2 c =p_distr(vec2(i_uv.x,c_uv.y));
	vec2 d =p_distr(c_uv);


   //f_uv = f_uv * f_uv * (3.0 - 2.0 * f_uv);// раскомментить для кубической интерполяции


    vec2 offset = mix(
        mix(a, b, f_uv.x),
        mix(c, d, f_uv.x),
        f_uv.y
    );

    return uv + offset;
}

void vertex(){
w_norm = NORMAL;
w_pos = VERTEX;
}

float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}

vec3 split(in vec2 uv, in vec2 root, in float d){
	vec2 shift = vec2(0.);
	uv.x > root.x ? shift=vec2(1.):shift=vec2(-1.);
	shift=root+shift*random2(root+shift);
	return vec3(shift,min(d,sdSegment(uv,root,shift)));
}




vec3 split2(in vec2 uv, in vec2 root, in float d, in vec4 sh ){
	vec4 points = vec4(root,root)+sh;
	vec2 shift = vec2(0.);
	distance(uv,points.xy) < distance(uv,points.zw) ? shift=points.xy:shift = points.zw;
	float sxy = sdSegment(uv,root,points.xy);
	float szw = sdSegment(uv,root,points.zw);
	if(szw>=sxy){shift=points.xy;}else{shift=points.zw;}
	return vec3(shift,min(d, min(sxy , szw)  ));
}

vec3 split3(in vec2 uv, in vec2 root, in float d, in vec4 sh ){
	vec2 upper_bound =ceil(uv);
	vec2 lower_bound =floor(uv);
	vec2 fuv=fract(uv);

	vec4 points = vec4(root,root)+hash42(root);

	vec2 shift = vec2(0.);

	distance(fuv,points.xy) < distance(fuv,points.zw) ? shift=points.xy:shift = points.zw;

	float sxy = sdSegment(uv,root,points.xy);
	float szw = sdSegment(uv,root,points.zw);
	if(sxy<szw){shift=hash22(points.xy);}
	return vec3(shift,min(d, min(sxy , szw)  ));
}


vec3 split4(in vec2 uv, in vec2 root, in float d, in vec4 sh ){
	vec4 points = vec4(root,root)+sh;
	vec2 shift = vec2(0.);
	distance(uv,points.xy) < distance(uv,points.zw) ? shift=points.xy:shift = points.zw;
	float sxy = sdSegment(uv,root,points.xy);
	float szw = sdSegment(uv,root,points.zw);
	if(sxy<szw){shift=hash22(points.xy);}else{shift=hash22(points.zw);}
	return vec3(shift,min(d, min(sxy , szw)  ));
}


float sdCapsule( vec3 p, vec3 a, vec3 b, float r )
{
  vec3 pa = p - a, ba = b - a;
  float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
  return length( pa - ba*h ) - r;
}

float split3d(in vec3 uvw, in vec3 root, in vec3 a, in vec3 b ){
	//vec4 points = vec4(root,root)+sh;
	//vec2 shift = vec2(0.);
	//distance(uv,points.xy) < distance(uv,points.zw) ? shift=points.xy:shift = points.zw;
	//float sxy = sdSegment(uv,root,points.xy);
	//float szw = sdSegment(uv,root,points.zw);
	//if(szw>=sxy){shift=points.xy;}else{shift=points.zw;}
	return 0.;
}

void fragment() {
	// этот кусок нужен для авторазвёртки. Игнорируйте.
	   vec3 anorm=abs(w_norm);
	vec3 v=w_pos;
	v.x*=floor(sign(w_norm.z));
	v.z*=-floor(sign(w_norm.x));
	v.y=-v.y;
	vec2 mp =mix(v.xy,v.zy,round(anorm.x));
	mp=mix(mp,w_pos.xz*-sign(w_norm.y),round(anorm.y));

	mp*=scale;
float outp=10000.;
vec2 a =vec2(0.62,0.66);

vec2 fuv = fract(mp);

vec2 t =vec2(1.);

vec4 bf =vec4(0.);

vec3 test = split2(fuv,a,outp,vec4(-0.08,0.02,0.08,-0.02));

test = split2(fuv,vec2(0.54,0.68),test.z,vec4(-0.06,0.5,-0.6,0.0));

test = split2(fuv,vec2(0.7,0.64),test.z,vec4(0.0,-0.8,0.6,0.6));



	outp=step(-test.z,-0.01);
	t=hash22(t);
	vec3 grid = vec3((step(.98, fuv.x) + step(.98, fuv.y)));
    ALBEDO = vec3(test.z)+grid*vec3(.25,0.,0.);//vec3(colorize(outp*2.,vec3(1.0, 1.0, 1.0),vec3(0.5, 0.5, 0.5),vec3(1., 1., 1.),vec3(0., 0.33, 0.67)));
//vec3(test.z)*
//vec3(t,0.)*
}

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
/*
float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}
*/
float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    vec2 closest = a + ba * h;
    float dist = length(p - closest);
    float cross = pa.x * ba.y - pa.y * ba.x;
    return dist * sign(cross);
}


vec2 split(in vec2 uv,in float split_point, in vec2 bounds) {
vec2 new_bounds;
uv.y< split_point ? new_bounds=vec2(split_point,bounds.x) : new_bounds=vec2(split_point,bounds.y);
    return new_bounds;
}

float cap(in vec2 uv,in float split_point, in vec2 bounds) {
    return uv.x< split_point ? split_point : 0.;
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

vec2 fuv = fract(mp);
vec2 lower_bound = floor(mp);

vec2 upper_bound = lower_bound+1.;

vec4 bounds = vec4(lower_bound.x,upper_bound.x,lower_bound.y,upper_bound.y);

vec2 test = vec2(lower_bound.x,split(fuv,hash12(lower_bound),bounds.zw).y);
test*=cap(fuv,0.25+hash12(test)*0.25,test);


	//t=hash22(t);
	vec3 grid = vec3((step(.98, fuv.x) + step(.98, fuv.y)));
	
    ALBEDO = vec3(hash32(test*3.))+grid*vec3(1.25,0.,0.);//+grid*vec3(.25,0.,0.);//vec3(colorize(outp*2.,vec3(1.0, 1.0, 1.0),vec3(0.5, 0.5, 0.5),vec3(1., 1., 1.),vec3(0., 0.33, 0.67)));
//vec3(test.z)*
//vec3(t,0.)*
}
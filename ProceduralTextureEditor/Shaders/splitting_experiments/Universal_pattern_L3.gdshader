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


vec3 split2(in vec2 uv, in vec2 root, in float d, in vec4 sh, out vec4 bs){
	vec2 shift = vec2(0.);
	//distance(uv,points.xy) < distance(uv,points.zw) ? shift=points.xy:shift = points.zw;
	uv.x+=grand(uv.y*2.)*0.5-0.5;
	float sxy = sdSegment(uv, vec2(hash11(sh.y)*0.5,0.) , vec2(hash11(sh.w)*0.5,1.) );
	//shift=vec2(1.)*step(uv.x,0.);
	//sxy<0. ? shift.x=sh.x : shift.x=sh.z;
	sxy<0. ? bs.x=sh.x : bs.x=sh.z;
	return vec3(shift,min(d, abs(sxy)));
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
vec2 a =vec2(0.5,0.5);

vec2 fuv = fract(mp);
vec2 upper_bound = ceil(mp);
vec2 lower_bound = floor(mp);

vec2 t =vec2(5.5);

vec4 bs =vec4(0.);

vec3 test = split2(fuv,mp,outp,vec4(lower_bound,upper_bound),bs);
t*=test.xy;

//test = split2(fuv.yx,mp,test.z,vec4(lower_bound.yx,upper_bound.yx));
//t*=test.xy;

	outp=step(-test.z,-0.01);
	t=hash22(t);
	vec3 grid = vec3((step(.98, fuv.x) + step(.98, fuv.y)));
    ALBEDO = test.z+grid*vec3(.25,0.,0.);//+grid*vec3(.25,0.,0.);//vec3(colorize(outp*2.,vec3(1.0, 1.0, 1.0),vec3(0.5, 0.5, 0.5),vec3(1., 1., 1.),vec3(0., 0.33, 0.67)));
//vec3(test.z)*
//vec3(t,0.)*
}

shader_type spatial;

uniform vec2 scale;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;
uniform sampler2D sed:filter_linear;
uniform float up[8];
uniform float down[8];
uniform float left[8];
uniform float right[8];

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


vec4 split(in vec2 ouv, in vec2 uv, in vec4 bounds, out float dist, out vec2 shift) {
    uv.x += grand(ouv.y*2.+TIME) * 0.5 - 0.5;
    float x_bottom = hash11(bounds.z) * 0.5;
    float x_top = hash11(bounds.w) * 0.5;
    vec2 a = vec2(x_bottom, 0.);
    vec2 b = vec2(x_top, 1.);
    float sxy = sdSegment(uv, a, b);
    dist = abs(sxy);
    float new_id = hash11(bounds.x + bounds.y + bounds.z + bounds.w);
    vec4 new_bounds;
    if (sxy < 0.) {
        new_bounds = vec4(bounds.x, new_id, bounds.z, bounds.w);
        shift = vec2(bounds.x, 0.);
    } else {
        new_bounds = vec4(new_id, bounds.y, bounds.z, bounds.w);
        shift = vec2(bounds.y, 0.);
    }
    return new_bounds;
}


vec3 split2(in vec2 uv, in float d, in vec4 sh, in float side[8]){
	vec2 shift = vec2(0.);
	float a =uv.y;
	int ind = int(floor(a*8.));
	uv.x+= mix(side[ind],side[(ind+1)%8],smoothstep(0.,1.,fract(a*8.)));
	float sxy = sdSegment(uv, vec2(0.5,0.) , vec2(0.5,1.) );

	sxy<0. ? shift.x=-1. : shift.x=1.;
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
float outpp=10000.;
vec2 a =vec2(0.5,0.5);

vec2 fuv = fract(mp);


vec2 t =vec2(5.5);

vec2 upper_bound = ceil(mp);
vec2 lower_bound = floor(mp);
vec4 bounds = vec4(lower_bound.x,upper_bound.x,lower_bound.y,upper_bound.y);

vec3 test = -split2(fuv,outp,bounds,up);
test += split2(fuv,outp,bounds,down);
test += split2(fuv.yx,outp,bounds,left);
test += -split2(fuv.yx,outp,bounds,right);

outpp=min(outpp,outp);

    //float f = mix(boundaries[ind],boundaries[(ind+1)%16],smoothstep(0.,1.,fract(a*16.)));



	outp=step(-outpp,-0.01);
	//t=hash22(t);
	vec3 grid = vec3((step(.98, fuv.x) + step(.98, fuv.y)));
    ALBEDO = vec3(hash32(test.xy))*outp+grid*vec3(1.25,0.,0.);//+grid*vec3(.25,0.,0.);//vec3(colorize(outp*2.,vec3(1.0, 1.0, 1.0),vec3(0.5, 0.5, 0.5),vec3(1., 1., 1.),vec3(0., 0.33, 0.67)));
//vec3(test.z)*
//vec3(t,0.)*
}

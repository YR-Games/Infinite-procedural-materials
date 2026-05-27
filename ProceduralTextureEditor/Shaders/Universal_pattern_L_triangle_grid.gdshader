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
float sdTriangle( in vec2 p, in vec2 p0, in vec2 p1, in vec2 p2 )
{
    vec2 e0 = p1-p0, e1 = p2-p1, e2 = p0-p2;
    vec2 v0 = p -p0, v1 = p -p1, v2 = p -p2;
    vec2 pq0 = v0 - e0*clamp( dot(v0,e0)/dot(e0,e0), 0.0, 1.0 );
    vec2 pq1 = v1 - e1*clamp( dot(v1,e1)/dot(e1,e1), 0.0, 1.0 );
    vec2 pq2 = v2 - e2*clamp( dot(v2,e2)/dot(e2,e2), 0.0, 1.0 );
    float s = sign( e0.x*e2.y - e0.y*e2.x );
    vec2 d = min(min(vec2(dot(pq0,pq0), s*(v0.x*e0.y-v0.y*e0.x)),
                     vec2(dot(pq1,pq1), s*(v1.x*e1.y-v1.y*e1.x))),
                     vec2(dot(pq2,pq2), s*(v2.x*e2.y-v2.y*e2.x)));
    return -sqrt(d.x)*sign(d.y);
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
/*

vec3 split2(in vec2 uv, in vec2 root, in float d, in vec4 sh ){
	vec4 points = vec4(root,root)+hash42(root)*2.-1.;
	vec2 shift = vec2(0.);
	distance(uv,points.xy) < distance(uv,points.zw) ? shift=points.xy:shift = points.zw;

	return vec3(shift,min(d, min( sdSegment(uv,root,points.xy),sdSegment(uv,root,points.zw) )  ));
}
*/

vec3 split2(in vec2 uv, in vec2 root, in float d, in vec4 sh ){
	vec4 points = vec4(root,root)+sh;
	vec2 shift = vec2(0.);
	distance(uv,points.xy) < distance(uv,points.zw) ? shift=points.xy:shift = points.zw;
	float sxy = sdSegment(uv,root,points.xy);
	float szw = sdSegment(uv,root,points.zw);
	if(szw>=sxy){shift=points.xy;}else{shift=points.zw;}
	return vec3(shift,min(d, min(sxy , szw)  ));
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

vec4 bf =vec4(0.);
vec3 test =vec3(0.);

vec2 pa = vec2(0.,0.);
vec2 pb = vec2(0.0,0.5);
float t = dot(mp,(pa-pb)*rotate2d(PI*0.5)); 
vec2 pc = sign(t)*hash22((pa-pb));

t = sign(dot(mp,(pc-pb)*rotate2d(PI*0.5))); 

float trigrid= sdTriangle(mp,pa,pb,pc);

//vec3 test = split2(fuv,a,outp,vec4(-0.08,0.02,0.08,-0.02));

//test = split2(fuv,vec2(0.54,0.68),test.z,vec4(-0.06,0.5,-0.6,0.0));

//test = split2(fuv,vec2(0.7,0.64),test.z,vec4(0.0,-0.8,0.6,0.6));

test=vec3(distance(pa,mp),distance(pb,mp),distance(pc,mp));

	outp=step(abs(trigrid),0.01);
	vec3 grid = vec3((step(.98, fuv.x) + step(.98, fuv.y)));
    ALBEDO = t+outp+vec3(step(test,vec3(0.1)));//+grid*vec3(.25,0.,0.);//vec3(colorize(outp*2.,vec3(1.0, 1.0, 1.0),vec3(0.5, 0.5, 0.5),vec3(1., 1., 1.),vec3(0., 0.33, 0.67)));
//vec3(test.z)*
//vec3(t,0.)*
}

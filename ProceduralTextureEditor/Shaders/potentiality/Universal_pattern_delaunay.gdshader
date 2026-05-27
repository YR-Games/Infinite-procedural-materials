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
	mp=warped_coords(mp);
  vec2 a = floor(mp)+mod(floor(mp),2.);
  vec2 b = floor(mp)+mod(ceil(mp),2.);
  vec2 c = vec2(a.x,b.y);
  vec2 d = vec2(b.x,a.y);

  vec2 a1 = mp-a;
 vec2 b1 = mp-b;
vec2 c1 = mp-c;
vec2 d1 = mp-d;

	vec4 ps =vec4(length(a1),length(b1),length(c1),length(d1));
	vec4 ds =vec4(atan(a1.x,a1.y),atan(b1.x,b1.y),atan(c1.x,c1.y),atan(d1.x,d1.y));
	ds+=PI;
	ds/=TAU;
	vec4 tx =vec4(
		texture(sed,vec2(ds.x/36.+a.x*a.y/36.,0.)).x,
		texture(sed,vec2(ds.y/36.+b.x*b.y/36.,0.)).x,
		texture(sed,vec2(ds.z/36.+c.x*c.y/36.,0.)).x,
		texture(sed,vec2(ds.w/36.+d.x*d.y/36.,0.)).x);
	
	     ps=smoothstep(tx,tx-0.1,ps);
float outp =max(ps.x*bn(a),ps.y*bn(b));
      outp =max(outp,ps.z*bn(c));
	  outp =max(outp,ps.w*bn(d));

// texture(sed,vec2(a/36.+id.x*id.y/36.,0.)).x) - 0.1;

    ALBEDO = vec3(colorize(outp*2.,vec3(1.0, 1.0, 1.0),vec3(0.5, 0.5, 0.5),vec3(1., 1., 1.),vec3(0., 0.33, 0.67)));
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
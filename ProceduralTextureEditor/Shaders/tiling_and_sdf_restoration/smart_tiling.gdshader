shader_type spatial;
render_mode unshaded;
uniform vec2 scale;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;
uniform sampler2D sed:filter_linear,source_color;
uniform sampler2D noise:filter_linear,source_color;
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


float sdCircle( vec2 p, float r )
{
    return length(p) - r;
}

float sum( vec3 v ) { return v.x+v.y+v.z; }

vec3 textureNoTile( in vec2 x, float v )
{
    float k =texture( noise, 0.05*x ).x; // cheap (cache friendly) lookup
    
    vec2 duvdx = dFdx( x );
    vec2 duvdy = dFdy( x );
    
    float l = k*8.0;
    float f = fract(l);
    

   // float ia = floor(l); // my method
   // float ib = ia + 1.0;

    float ia = floor(l+0.5); // suslik's method (see comments)
    float ib = floor(l);
    f = min(f, 1.0-f)*2.0;
   
    
    vec2 offa = sin(vec2(3.0,7.0)*ia); // can replace with any other hash
    vec2 offb = sin(vec2(3.0,7.0)*ib); // can replace with any other hash

    vec3 cola = textureGrad( sed, x + v*offa, duvdx, duvdy ).xyz;
    vec3 colb = textureGrad( sed, x + v*offb, duvdx, duvdy ).xyz;
    
    return mix( cola, colb, smoothstep(0.2,0.8,f-0.1*sum(cola-colb)) );
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
	vec2 fuv =fract(mp);
    vec3 col = textureNoTile(mp,1.);
	vec3 grid = vec3((step(.98, fuv.x) + step(.98, fuv.y)));
    ALBEDO = vec3(col);
}
//smoothstep(0.2,0.5,col.x)
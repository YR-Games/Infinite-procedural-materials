shader_type canvas_item;
render_mode world_vertex_coords;
uniform sampler2D img:repeat_enable,filter_nearest; //
uniform float mult;
varying vec2 world_pos;
const vec4 RANDOM_SCALE = vec4(.1031, .1030, .0973, .1099);

const vec3 col_arr[] = { vec3(1.0,0.0,0.0),vec3(1.0,1.0,0.0),vec3(0.25, 0.75,0.5),vec3(0.3, 0.4,0.5),
						 vec3(0.0,1.0,0.0),vec3(0.0,1.0,1.0),vec3(0.5, 0.25,0.0),vec3(0.5, 0.4,0.3),
						 vec3(0.0,0.0,1.0),vec3(1.0,0.0,1.0),vec3(0.25, 0.5,0.0),vec3(0.5, 0.3,0.4),
						 vec3(0.0,0.0,0.0),vec3(1.0,1.0,1.0),vec3(0.5, 0.25,0.5),vec3(0.4, 0.4,0.4)};


float random(in vec2 st) {
  return -1. + 2. * fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 random2(vec2 p) {
    vec3 p3 = fract(p.xyx * RANDOM_SCALE.xyz);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.xx + p3.yz) * p3.zy);
}



// Value noise by Inigo Quilez - iq/2013
// https://www.shadertoy.com/view/lsf3WH


float bn(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    vec2 u = f*f*f*(f*(f*6.-15.)+10.);
    return mix( mix( random( i + vec2(0.0,0.0) ),
                     random( i + vec2(1.0,0.0) ), u.x),
                mix( random( i + vec2(0.0,1.0) ),
                     random( i + vec2(1.0,1.0) ), u.x), u.y);
}

mat2 rotate2d(const in float r){
    float c = cos(r);
    float s = sin(r);
    return mat2(vec2(c, -s),vec2( s, c));
}

float wavelet(vec2 p, float phase, float k) {
    float d = 0.0, s = 1.0, m=0.0, a = 0.0;
    for (float i = 0.0; i < 4.0; i++) {
        vec2 q = p*s;
        a = random(floor(q)) * 1e3;
        q = (fract(q) - 0.5) * rotate2d(a);
        d += sin(q.x * 10.0 + phase) * smoothstep(.25, 0.0, dot(q,q)) / s;
        p = p * mat2(vec2(.54,-0.84),vec2( 0.84, 0.54)) + i;
        m += 1.0 / s;
        s *= k;
    }
    return d / m;
}

float wn(vec2 p, float phase) {
    return wavelet(p, phase, 1.24);
}

#define VORONOI_RANDOM_FNC(uv) ( 0.5 + 0.5 * sin(time + TAU * random2(uv) ) );

vec3 voronoi(vec2 uv, float time) {
    vec2 i_uv = floor(uv);
    vec2 f_uv = fract(uv);
    vec3 rta = vec3(0.0, 0.0, 10.0);
    for (int j=-1; j<=1; j++ ) {
        for (int i=-1; i<=1; i++ ) {
            vec2 neighbor = vec2(float(i),float(j));
            vec2 point = VORONOI_RANDOM_FNC(i_uv + neighbor);
            point = 0.5 + 0.5 * sin(time + TAU * point);
            vec2 diff = neighbor + point - f_uv;
            float dist = length(diff);
            if ( dist < rta.z ) {
                rta.xy = point;
                rta.z = dist;
            }
        }
    }
    return rta;
}



vec3 vor2(vec2 p)  { return voronoi(p, 0.0); }
vec3 vor3(vec3 p)  { return voronoi(p.xy, p.z); }

float lines(in vec2 pos, float b){
    float scale = 5.0;
    pos *= scale;
    return smoothstep(0.0,.5+b*.5, abs((sin(pos.x*3.1415)+b*2.0))*.5);
}

float gra(vec2 uv){

	return (abs(sin(uv.x)));
}

float order(float pos){

    int p11 = 120;
	int p12 = 1;

	int p21 = 110;
	int p22 = 2;

	int p31 = 170;
	int p32 = 3;

	int p41 = 170;
	int p42 = 4;

	int p51 = 170;
	int p52 = 5;

	int posy =int(pos)%16;

    int f1 =1&( (((1+2*p11)<<p12)%65535)>>int(posy));
    int f2 =2* (1&( (((1+2*p21)<<p22)%65535)>>int(posy)));
    int f4 =4* (1&( (((1+2*p41)<<p42)%65535)>>int(posy)));
    int f5 =8* (1&( (((1+2*p51)<<p52)%65535)>>int(posy)));
    return float(f1+f2+f4+f5);
}

void vertex(){
		world_pos = VERTEX;
	}

void fragment() {

    vec2 pos =world_pos;

	vec2 mp=pos/mult;

	vec3 ou=vec3(shue(mp));
	//vec3 v3 = texture(img,mp*rotate2d(cos((mp.y+TIME)/PI))).rgb;
	//ou=v3;

	COLOR=vec4(ou,1);

}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}

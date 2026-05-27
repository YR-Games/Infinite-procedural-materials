shader_type spatial;
render_mode world_vertex_coords;
uniform sampler2D img1:repeat_enable; //
uniform sampler2D img2:repeat_enable; //
uniform float boundaries[16];
uniform float mult;
varying vec3 w_pos;
varying vec3 w_norm;
const vec4 RANDOM_SCALE = vec4(.1031, .1030, .0973, .1099);

float random(in vec2 st) {
	  return -1. + 2. * fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453);}

vec2 random2(vec2 p) {
     vec3 p3 = fract(p.xyx * RANDOM_SCALE.xyz);
     p3 += dot(p3, p3.yzx + 19.19);
     return fract((p3.xx + p3.yz) * p3.zy);}


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
    return mat2(vec2(c, -s),vec2( s, c));}


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
    return d / m;}


float wn(vec2 p, float phase) {
    return wavelet(p, phase, 1.24);}

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
    return rta;}

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

#define OCTAVES 6
float fbm (in vec2 st) {
    // Initial values
    float value = 1.;
    float amplitude = .2;
    float frequency = 2.;
    //
    // Loop of octaves
    for (int i = 0; i < OCTAVES; i++) {
        value += amplitude * bn(st);
        st *= 2.;
        amplitude *= .5;
    }
    return value;
}


float shape(vec2 uv,float y){
	//uv.x/=2.;
	//uv.x+=floor(uv.y/2.)*2.;
	//uv = random(floor(uv/3.))>0. ? uv/3.:uv;
    uv*=fbm(uv*y);
	vec2 iuv = floor(uv);  // integer
    vec2 fuv = fract(uv);
    float f_out=0.;

    		vec2 smth = fuv-vec2(0.5,0.5);
    		//float r = max(abs(smth.x),abs(smth.y))*2.;
			float r = length(smth)*2.;
    		float a = atan(smth.y,smth.x);
   		 	//a=(PI+a)/2./PI;
			//a=abs(a);
 			float f = 1.;
    		f=1.-smoothstep(f-0.,f,r);


    return f*abs(bn(vec2(r,r)*64.));

}



float tile_gen(vec2 uv,float y){
	//uv.x/=2.;
	//uv.x+=floor(uv.y/2.)*2.;
	//uv = random(floor(uv/3.))>0. ? uv/3.:uv;
    uv+=fbm(uv*y);
	vec2 iuv = floor(uv);  // integer
    vec2 fuv = fract(uv);
    float f_out=0.;

    		vec2 smth = fuv-vec2(0.5,0.5);
    		//float r = max(abs(smth.x),abs(smth.y))*2.;
			float r = length(smth)*2.;
    		float a = atan(smth.y,smth.x);
   		 	//a=(PI+a)/2./PI;
			//a=abs(a);
 			float f = 1.;
    		f=1.-smoothstep(f-0.,f,r);


    return f*abs(bn(vec2(r,r)*64.));

}






void vertex(){
	    w_norm = NORMAL;
		w_pos = VERTEX;
	}

void fragment() {


	vec2 mp =w_pos.xz;
	float y =w_pos.y;
	mp*=mult;
    //mp+=fbm(vec2(1.,1.)*mp);
	vec2 tuv=mp/2.;
    vec3 m1 = texture(img1,tuv).r*vec3(0.8,0.2,0.2);
	vec3 m2 = texture(img2,tuv).rgb;

    float schz =tile_gen(mp,y);
	//vec3 ou=mix(m2,m1,schz*schz);


		float offset = 0.0001;
		float mlp = 0.2;

		vec2 nuv = vec2(mp.x+offset,mp.y);
    vec3 fa = vec3(nuv.x, 0.0,tile_gen(nuv,y)*mlp);;
	    nuv = vec2(mp.x,mp.y-offset);
    vec3 fc = vec3(0.0, nuv.y,tile_gen(nuv,y)*mlp);


	vec3 mf=vec3(mp,schz*mlp);

	vec3 normal = 0.5+normalize(cross(fa-mf*vec3(1.,0.,1.), fc-mf*vec3(0.,1.,1.)))*vec3(1.,-1.,1.);

	ALBEDO=vec3(schz);
	//ALBEDO=normal;

	//ALBEDO=vec3(fract(mp),0.);
   // ALBEDO=ou;
    ROUGHNESS = 1.;
	NORMAL_MAP=normal;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
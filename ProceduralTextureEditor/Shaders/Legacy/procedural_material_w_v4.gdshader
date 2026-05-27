shader_type spatial;
//render_mode world_vertex_coords;
//uniform sampler2D img1:repeat_enable;
//uniform sampler2D img2:repeat_enable;
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
    float value = 0.5;
    float amplitude = .1;
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

vec2 metric(vec2 uv){
	    	vec2 smth = uv-vec2(0.5,0.5);
			float r = length(smth)*2.;//float r = max(abs(smth.x),abs(smth.y))*2.;
    		float a = atan(smth.y,smth.x);
			//a=(PI+a)/2./PI;
			//a=abs(a);
	return vec2(a,r);
}

float shape(vec2 uv){
	//uv.x/=2.;
    //uv.x+=floor(uv.y/2.)*2.;
	//uv = random(floor(uv/3.))>0. ? uv/3.:uv;
    //uv*=fbm(uv*y);

	float f_out=0.;
	vec2 iuv = floor(uv);//1 1
    vec2 fuv = fract(uv);//0 0
	float test=abs(bn(iuv));
    vec2 muv = metric(fuv);//pi/4
 			float f = 1.-abs(muv.x-bn(iuv+7.));
    		f-=smoothstep(f-0.,f,muv.y);
	 		f_out=max(f_out,f*1.);


	 /*muv+=metric(0.25,.25);
	 uv+=vec2(0.25,0.25);
	 iuv = floor(uv);// 1 1
     fuv = fract(uv);// 0.25 0.25
	 test=abs(bn(iuv*23.));
     muv = metric(fuv);
		f=f = 1.-abs(muv.x-bn(iuv+27.));;
    	f-=smoothstep(f-0.,f,muv.y);
		f_out=max(f_out,f*2.);
*/



    return f_out;

}



float tile_gen(vec2 uv){
	//uv.x/=2.;
	//uv.x+=floor(uv.y/2.)*2.;
	//uv = random(floor(uv/3.))>0. ? uv/3.:uv;

	vec2 iuv = floor(uv);  // integer
    vec2 fuv = fract(uv);
    float f_out=0.;
	  for (int j=-1; j<=1; j++ ) {
        for (int i=-1; i<=1; i++ ) {

            vec2 neighbor = vec2(float(i),float(j));
			float test = abs(bn(iuv+neighbor));
    		vec2 smth = fuv-vec2(0.5,0.5)-neighbor;
    		//float r = max(abs(smth.x),abs(smth.y))*2.;
			float r = length(smth)*2.;
    		float a = atan(smth.y,smth.x);
   		 	//a=(PI+a)/2./PI;
			//a=abs(a);
 			float f =  1.-abs(a+cos(TIME*test));
    		f-=smoothstep(f-0.1,f,r/3.);

			f_out=max(f_out,f*test);

		   }
        }


    return f_out;

}
vec3 colorize(float t,vec3 a, vec3 b, vec3 c,vec3 d){

	return  a + b * cos(TAU*(c*t+d));
}





void vertex(){
	    w_norm = NORMAL;
		w_pos = VERTEX;
	}

void fragment() {

    vec3 anorm=abs(w_norm);
	vec3 v=w_pos;
	v.x*=floor(sign(w_norm.z));
	v.z*=-floor(sign(w_norm.x));
	v.y=-v.y;
	vec2 mp =mix(v.xy,v.zy,round(anorm.x));
	mp=mix(mp,w_pos.xz*-sign(w_norm.y),round(anorm.y));
	mp*=mult;
    //mp+=fbm(vec2(1.,1.)*mp);
	vec2 tuv=mp/2.;

    float outp =tile_gen(mp);

		float offset = 0.0001;
		float mlp = 0.2;

		vec2 nuv = vec2(mp.x+offset,mp.y);
    vec3 fa = vec3(nuv.x, 0.0,shape(nuv)*mlp);;
	    nuv = vec2(mp.x,mp.y-offset);
    vec3 fc = vec3(0.0, nuv.y,shape(nuv)*mlp);


	vec3 mf=vec3(mp,outp*mlp);

	vec3 normal = 0.5+normalize(cross(fa-mf*vec3(1.,0.,1.), fc-mf*vec3(0.,1.,1.)))*vec3(1.,-1.,1.);

	//ALBEDO=colorize(outp,vec3(0.5, 0.5, 0.),vec3(0.5, 0.5, 0.5),vec3(1.0, 1.0, 0.5),vec3(0.5, 0.35, 0.3));
	ALBEDO=vec3(outp);
    ROUGHNESS = 1.-outp;
	//NORMAL_MAP=normal;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
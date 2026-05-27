shader_type spatial;
//render_mode world_vertex_coords;
//uniform sampler2D img1:repeat_enable;
//uniform sampler2D img2:repeat_enable;
uniform float a_width[16];
uniform float a_shift[16];
uniform float a_source[16];
uniform float mult;
uniform float normalsw;
varying vec3 w_pos;
varying vec3 w_norm;
const vec4 RANDOM_SCALE = vec4(.1031, .1030, .0973, .1099);

float random(in vec2 st) {
	  return -1.+ 2. * fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453);}

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



//////////////////__Support functions__/////////////////
float mod289(const in float x) { return x - floor(x * (1. / 289.)) * 289.; }
vec2 mod289_2d(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 mod289_3d(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 mod289_4d(const in vec4 x) { return x - floor(x * (1. / 289.)) * 289.; }

float permute(const in float v) { return mod289(((v * 34.0) + 1.0) * v); }
vec2 permute_2d(const in vec2 v) { return mod289_2d(((v * 34.0) + 1.0) * v); }
vec3 permute_3d(const in vec3 v) { return mod289_3d(((v * 34.0) + 1.0) * v); }
vec4 permute_4d(const in vec4 v) { return mod289_4d(((v * 34.0) + 1.0) * v); }

float taylorInvSqrt(in float r) { return 1.79284291400159 - 0.85373472095314 * r; }
vec2 taylorInvSqrt_2d(in vec2 r) { return 1.79284291400159 - 0.85373472095314 * r; }
vec3 taylorInvSqrt_3d(in vec3 r) { return 1.79284291400159 - 0.85373472095314 * r; }
vec4 taylorInvSqrt_4d(in vec4 r) { return 1.79284291400159 - 0.85373472095314 * r; }

float quintic(const in float v) { return v*v*v*(v*(v*6.0-15.0)+10.0); }
vec2  quintic_2d(const in vec2 v)  { return v*v*v*(v*(v*6.0-15.0)+10.0); }
vec3  quintic_3d(const in vec3 v)  { return v*v*v*(v*(v*6.0-15.0)+10.0); }
vec4  quintic_4d(const in vec4 v)  { return v*v*v*(v*(v*6.0-15.0)+10.0); }


//////////////////__Simplex noise__/////////////////


//
// Description : GLSL 2D simplex noise function
//      Author : Ian McEwan, Ashima Arts
//  Maintainer : ijm
//     Lastmod : 20110822 (ijm)
//     License :
//  Copyright (C) 2011 Ashima Arts. All rights reserved.
//  Distributed under the MIT License. See LICENSE file.
//  https://github.com/ashima/webgl-noise
//
float snoise(vec2 v) {

    // Precompute values for skewed triangular grid
    const vec4 C = vec4(0.211324865405187,
                        // (3.0-sqrt(3.0))/6.0
                        0.366025403784439,
                        // 0.5*(sqrt(3.0)-1.0)
                        -0.577350269189626,
                        // -1.0 + 2.0 * C.x
                        0.024390243902439);
                        // 1.0 / 41.0

    // First corner (x0)
    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);

    // Other two corners (x1, x2)
    vec2 i1 = vec2(0.0);
    i1 = (x0.x > x0.y)? vec2(1.0, 0.0):vec2(0.0, 1.0);
    vec2 x1 = x0.xy + C.xx - i1;
    vec2 x2 = x0.xy + C.zz;

    // Do some permutations to avoid
    // truncation effects in permutation
    i = mod289_2d(i);
    vec3 p = permute_3d(
            permute_3d( i.y + vec3(0.0, i1.y, 1.0))
                + i.x + vec3(0.0, i1.x, 1.0 ));

    vec3 m = max(0.5 - vec3(
                        dot(x0,x0),
                        dot(x1,x1),
                        dot(x2,x2)
                        ), 0.0);

    m = m*m ;
    m = m*m ;

    // Gradients:
    //  41 pts uniformly over a line, mapped onto a diamond
    //  The ring size 17*17 = 289 is close to a multiple
    //      of 41 (41*7 = 287)

    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;

    // Normalise gradients implicitly by scaling m
    // Approximation of: m *= inversesqrt(a0*a0 + h*h);
    m *= 1.79284291400159 - 0.85373472095314 * (a0*a0+h*h);

    // Compute final noise value at P
    vec3 g = vec3(0.0);
    g.x  = a0.x  * x0.x  + h.x  * x0.y;
    g.yz = a0.yz * vec2(x1.x,x2.x) + h.yz * vec2(x1.y,x2.y);
    return 130.0 * dot(m, g);
}

//////////////////__Perlin_noise__/////////////////

float pnoise(in vec2 P, in vec2 rep) {
    vec4 Pi = floor(P.xyxy) + vec4(0.0, 0.0, 1.0, 1.0);
    vec4 Pf = fract(P.xyxy) - vec4(0.0, 0.0, 1.0, 1.0);
    Pi = mod(Pi, rep.xyxy); // To create noise with explicit period
    Pi = mod289_4d(Pi);        // To avoid truncation effects in permutation
    vec4 ix = Pi.xzxz;
    vec4 iy = Pi.yyww;
    vec4 fx = Pf.xzxz;
    vec4 fy = Pf.yyww;

    vec4 i = permute_4d(permute_4d(ix) + iy);

    vec4 gx = fract(i * (1.0 / 41.0)) * 2.0 - 1.0 ;
    vec4 gy = abs(gx) - 0.5 ;
    vec4 tx = floor(gx + 0.5);
    gx = gx - tx;

    vec2 g00 = vec2(gx.x,gy.x);
    vec2 g10 = vec2(gx.y,gy.y);
    vec2 g01 = vec2(gx.z,gy.z);
    vec2 g11 = vec2(gx.w,gy.w);

    vec4 norm = taylorInvSqrt_4d(vec4(dot(g00, g00), dot(g01, g01), dot(g10, g10), dot(g11, g11)));
    g00 *= norm.x;
    g01 *= norm.y;
    g10 *= norm.z;
    g11 *= norm.w;

    float n00 = dot(g00, vec2(fx.x, fy.x));
    float n10 = dot(g10, vec2(fx.y, fy.y));
    float n01 = dot(g01, vec2(fx.z, fy.z));
    float n11 = dot(g11, vec2(fx.w, fy.w));

    vec2 fade_xy = quintic_2d(Pf.xy);
    vec2 n_x = mix(vec2(n00, n01), vec2(n10, n11), fade_xy.x);
    float n_xy = mix(n_x.x, n_x.y, fade_xy.y);
    return 2.3 * n_xy;
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

vec2 vor1(float x, float time) {
    float i_x = floor(x);
    float f_x = fract(x);
    vec2 rta = vec2(0.0, 10.0);
    for (int j=-1; j<=1; j++ ) {
            float point = bn(vec2(i_x + float(j)));
            point = 0.5 + 0.5 * sin(time + TAU * point);
            float diff = float(j) + point - f_x;
            float dist =diff;
            if ( dist < rta.y ) {
                rta.x = point;
                rta.y = dist;
        }
    }
    return -rta;}




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
    float amplitude = 0.25;
    float frequency = 2.;
    //
    // Loop of octaves
    for (int i = 0; i < OCTAVES; i++) {
        value += amplitude * pnoise(st,vec2(0.));//wn(st,1.)
        st *= 2.;
        amplitude *= 0.5;
    }
    return value;
}

vec2 metric(vec2 uv){
	    	vec2 smth = uv-vec2(0.5,0.5);
			float r = length(smth)*2.;
			//float r = max(abs(smth.x),abs(smth.y))*2.;
    		float a = atan(smth.y,smth.x);
			//a=(PI+a)/2./PI;
			//a=abs(a);
	return vec2(a,r);
}



float tile(vec2 uv){
	float f_out=0.;
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);

	//float r = length(smth)*2.;
	float r = max(abs(smth.y),abs(smth.y))*2.;
	float a = atan(smth.y,smth.x);
 			float f = 1.;
    		f-=smoothstep(f-0.15,f,r);
	 		f_out=max(f_out,f*1.);

		//float test = 1.-mod(iuv.x+iuv.y,5.);
		float test = 1.-round(abs(wn(iuv,0.3))+0.49);
		r = max(abs(smth.x*8.),abs(smth.y/2.5))*2.;
		f = 1.*test;
  		f-=smoothstep(f-0.5,f,r);
 		f_out=min(f_out,abs(1.-f*1.));

    return f_out;

}

float pcurve( float x, float a, float b )
{
    float k = pow(a+b,a+b)/(pow(a,a)*pow(b,b));
    return k*pow(x,a)*pow(1.0-x,b);
}






float shape(vec2 uv){
	//uv.x/=2.;
    //uv.x+=floor(uv.y/2.)*2.;
	//uv = random(floor(uv/3.))>0. ? uv/3.:uv;
    //uv*=fbm(uv*y);

	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);

	//float r = length(smth)*2.;
	float r = max(abs(smth.y),abs(smth.y))*2.;
	float a = atan(smth.y,smth.x);
	// a=(PI+a)/2./PI;
	//a=abs(a/PI);
	//r=smth.y;
	//a=abs(a/PI);
	r=abs(smth.y)*2.;
	a=fuv.x;
 	int ind = int(floor(a*15.));
	float width=mix(a_width[ind],a_width[(ind+1)],smoothstep(-0.1,1.1,fract(a*15.)));
	float shift=wn(vec2(a*2.,iuv.x),iuv.y)*sign(smth.y);
	//shift=0.;
    float f = width+shift;
    		f=1.-smoothstep(f-0.15,f,r*2.);

    return f;

}


//выкалывать точки с помощью двоичного порядка
vec2 p_distr(vec2 uv){
	int posx=int(uv.x);
	int posy=int(uv.y);

	int p11 =510;
	int p12=int(cos(TIME/8.)*32.);

	int p21 =16;
	int p22=int(cos(TIME/8.)*32.);
	;
	int f1 = 1&(511>>posx);
	int f2 = 1&(511>>posy);

	float tst=float(f1*f2);
	return vec2(0.5)+vec2(2.*tst,0);
}


//обходить дважды, стягивать точки друг к другу?
//умеем выкалывать точки и рисовать "болото".

vec3 mixm(vec2 uv){
    vec3 color = vec3(.0);
    // Tile the space
    vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
    float m_dist = 1.;  // minimum distance
    for (int y= -1; y <= 1; y++) {
        for (int x= -1; x <= 1; x++) {

            vec2 neighbor = vec2(float(x),float(y));
			float weight = round(abs(bn(iuv+neighbor)));//mod(iuv.x+neighbor.x,2.);
            vec2 point = random2(iuv + neighbor);
            vec2 diff = neighbor + point - fuv;

            //float dist = length(diff)*test;
            float dist = length(diff);
			m_dist=min(m_dist,dist-weight);
        }
    }

    // Draw the min distance (distance field)
     color.z = m_dist*m_dist*m_dist;

    // Draw cell center
    //color.y += (1.-step(.04, m_dist))*(0.5+test*0.5);
	float _radius = 0.01;
	vec2 dist = fuv-random2(iuv);
    color.g +=(1.-smoothstep(_radius-(_radius*0.01),_radius+(_radius*0.01), dot(m_dist,m_dist)*4.0));
    // Draw grid
    //color.r += (step(.98, fuv.x) + step(.98, fuv.y))*0.3;

    // Show isolines
    // color -= step(.7,abs(sin(27.0*m_dist)))*.5;
	//color.g=1.-color.g;
    return color;
}


float tile_gen(vec2 uv){
	//uv.x/=2.;
	//uv.x+=floor(uv.y);
	//uv = random(floor(uv/3.))>0. ? uv/3.:uv;
	vec2 iuv = floor(uv);  // integer
    vec2 fuv = fract(uv);
    float f_out=0.;
	  for (int j=-1; j<=1; j++ ) {
        for (int i=-1; i<=1; i++ ) {

            vec2 neighbor = vec2(float(i),float(j));
			//float test = abs(bn(iuv+neighbor));

			float shift = mod((iuv+neighbor).y,2.)*1.;
			float test2 = 1.+floor(mod(abs((iuv+neighbor).x),3.+shift)/(2.+shift));

			float test = 1./test2;
    		vec2 smth = fuv-vec2(0.5,0.5)-neighbor;
			smth.x*=test2/2.;

    		float r = max(abs(smth.x),abs(smth.y))*2.;
			//float r = length(smth)*2.;
    		float a = atan(smth.y,smth.x);
   		 	//a=(PI+a)/2./PI;
			//a=abs(a);

			//float x1 = sin(a);
			//float y1 = cos(a);
			//float z1 = sin(a);

			//float x2 = cos(a);
			//float y2 = sin(a);
			//float z2 = cos(a);

			//vec3 weird1 = vec3(x1,y1,z1);
			//vec3 weird2 = vec3(x2,y2,z2);
 			//float f = length(cross(weird1,weird2));
			//float f = dot(weird1,weird2);
			//float spl = ceil(a*4.)/4.;
			float f =1.;

			//vor2(vec2(a+length(neighbor+iuv),a)/2.+test).z;
			//fbm(vec2(a,a+test)*2.+iuv+neighbor)*1.5+test*2.;
    		f=1.-smoothstep(f-0.05,f,r);

			f_out=max(f_out,f*test);

		   }
        }


    return f_out;

}
vec3 colorize(float t,vec3 a, vec3 b, vec3 c,vec3 d){

	return  a + b * cos(TAU*(c*t+d));
}



float experimen(vec2 uv){
	// finally генератор строк
	//uv.x+=wn(uv.yy,TIME)*0.1;
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);

	vec2 smth = fuv-vec2(0.5,0.5);
	float r = length(smth.x)*2.;
	//float r = max(abs(smth.y),abs(smth.y))*2.;
	float f1=0.;
	float f2=0.;
 	for (int j=-1; j<=1; j++ ) {

	smth = fuv-vec2(0.5+float(j),0.5);
	float test = abs(0.5+bn(vec2(iuv.x+float(j))));
	float r = length(smth.x)*2.;
    float f =1.;
    	f=1.-smoothstep(f-0.9,f,r);
		f1=max(f1,f*test);
	}

	for (int j=-1; j<=1; j++ ) {

	smth = fuv-vec2(0.5,0.5+float(j));
	float test = abs(0.5+bn(vec2(iuv.y+float(j))));
	float r = length(smth.y)*2.;
    float f = 1.;
    	f=1.-smoothstep(f-0.9,f,r);
		f2=max(f2,f*test);
	}

    return max(f1,f2);
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

    float outp = experimen(mp);

		float offset = 0.0001;
		float mlp = 0.2;

		vec2 nuv = vec2(mp.x+offset,mp.y);
    vec3 fa = vec3(nuv.x, 0.0,experimen(nuv)*mlp);;
	    nuv = vec2(mp.x,mp.y-offset);
    vec3 fc = vec3(0.0, nuv.y,experimen(nuv)*mlp);


	vec3 mf=vec3(mp,outp*mlp);

	vec3 normal = 0.5+normalize(cross(fa-mf*vec3(1.,0.,1.), fc-mf*vec3(0.,1.,1.)))*vec3(1.,-1.,1.);

	ALBEDO=colorize(outp,vec3(0.1, 0.5, 0.9),vec3(1., 1., 1.),vec3(1.0, 1.0, 1.0),vec3(0., 0.33, 0.66));
	ALBEDO=vec3(outp);
    ROUGHNESS = 1.;
	NORMAL_MAP=normal*normalsw;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
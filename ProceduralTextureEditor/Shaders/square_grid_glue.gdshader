shader_type spatial;
uniform float xc :hint_range(0.0, 1.0, 0.01);
uniform float yc :hint_range(0.0, 1.0, 0.01);

#include "shader_modules/library.gdshaderinc"

void vertex() {
	// Called for every vertex the material is visible on.
}


float sdCircle( vec2 p, float r )
{
    return length(p) - r;
}

float sdBox( in vec2 p, in vec2 b )
{
    vec2 d = abs(p)-b;
    return length(max(d,0.0)) + min(max(d.x,d.y),0.0);
}



float shape( in vec2 p, in vec2 id ){

vec2 b = vec2(0.4,0.2);
vec2 shift =vec2(0.5,0.)*mod(id.y,2.);
    return sdBox(p+shift,b);
}

float shape2( in vec2 p, in vec2 id ){
float r=abs(bn(id));
p+=random2(id)*0.5;
    return sdCircle(p,r);
}

vec3 map( in vec2 p ){
   const vec2 s = vec2(1.,0.6);
        vec2 id = round(p/s);
		vec2 id_out=vec2(0.);
        vec2 off = sign(p-s*id);

        float d = 1e20;
        for( float j=0.; j<2.; j++ )
        for( float i=0.; i<2.; i++ )
        {
            vec2 rid = id + vec2(i,j)*off;
           // rid = clamp(rid,-rep,rep); // limited repetition
            vec2 r = p - s*rid;
            //d = min( d, shape(r,rid) );
			if(d>shape(r,rid)){
				d=shape(r,rid);
				id_out=rid;
			}
        }
        return vec3(d,id_out);
    }

vec3 map2( in vec2 p ){
   const vec2 s = vec2(1.5,1.5);
        vec2 id = round(p/s);
		vec2 id_out=vec2(0.);
        vec2 off = sign(p-s*id);

        float d = 1e20;
        for( float j=0.; j<2.; j++ )
        for( float i=0.; i<2.; i++ )
        {
            vec2 rid = id + vec2(i,j)*off;
           // rid = clamp(rid,-rep,rep); // limited repetition
            vec2 r = p - s*rid;
            //d = min( d, shape(r,rid) );
			if(d>shape2(r,rid)){
				d=shape2(r,rid);
				id_out=rid;
			}
        }
        return vec3(d,id_out);
    }


vec3 map3( in vec2 p ){
   const vec2 s = vec2(1.5,1.5);
        vec2 id = round(p/s);
		vec2 id_out=vec2(0.);
        vec2 off = sign(p-s*id);

        float d = shape2(p-s,id);
		float clrnc = 1e20;
		float midsurf = 1e20;
        for( float j=0.; j<2.; j++ )
        for( float i=0.; i<2.; i++ )
        {
            vec2 rid = id + vec2(i,j)*off;

            vec2 r = p - s*rid;
			float dn=shape2(r,rid);
			if(d>dn){
				clrnc = d+dn;
				midsurf = d-dn;
				d=dn;
				id_out=rid;
			}
        }
        return vec3(clrnc,midsurf,d);
    }


vec2 vcm(vec2 uv, float time) {
    vec2 i_uv = floor(uv);
    vec2 f_uv = fract(uv);
    
    float d1 = 1e5; // smallest distance
    float d2 = 1e5; // second smallest distance
    
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 neighbor = vec2(float(i), float(j));
            vec2 point = VORONOI_RANDOM_FNC(i_uv + neighbor);
            point = 0.5 + 0.5 * sin(time + TAU * point);  // as in original code
            
            vec2 diff = neighbor + point - f_uv;
            float dist = length(diff);
            
            // Update the two smallest distances
            if (dist < d1) {
                d2 = d1;
                d1 = dist;
            } else if (dist < d2) {
                d2 = dist;
            }
        }
    }
    
    float clearance = d1 + d2;
    float midsurface = d1 - d2;
    return vec2(clearance, midsurface);
}

vec2 sdfcm(in vec2 p) {
    const vec2 s = vec2(1.5, 1.5);
    vec2 id = round(p / s);
    vec2 off = sign(p - s * id);

    float d1 = 1e20; // smallest distance
    float d2 = 1e20; // second smallest

    for (float j = 0.0; j < 2.0; j++) {
        for (float i = 0.0; i < 2.0; i++) {
            vec2 rid = id + vec2(i, j) * off;
            vec2 r = p - s * rid;
            float dist = shape2(r, rid); // assume shape2 returns a scalar distance

            // Update the two smallest distances
            if (dist < d1) {
                d2 = d1;
                d1 = dist;
            } else if (dist < d2) {
                d2 = dist;
            }
        }
    }

    float clearance = d1 + d2;
    float midsurface = d1 - d2;
    return vec2(clearance, midsurface);
}


float sdSegment( in vec2 p, in vec2 a, in vec2 b )
{
    vec2 pa = p-a, ba = b-a;
    float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
    return length( pa - ba*h );
}

void fragment() {
	vec2 uv = UV*32.;

	vec2 a=vec2(0.,2.)+16.;
	vec2 b=vec2(0.,-2.)+16.;
	vec2 a1=vec2(5.,0.)+16.;
	//vec2 b1=vec2(-20.,0.)+16.;
	vec3 m =map2(uv); //vec3(sdBox(uv-16.,vec2(1.)));//vec3(sdSegment(uv,a,b));
	vec3 m2 =map2(uv);  //vec3(sdBox(uv-18.,vec2(1.,20.))); //vec3(sdSegment(uv,a1,b));//map2(uv+0.5);
	//vec3 m22 = vec3(sdSegment(uv,a1,a));//map2(uv+0.5);
	//m.x=abs(m.x);
	//m2.x=abs(m2.x);
	float clrnc =m.x+m2.x;

	float midsurf = m.x-m2.x;
	
	float tbf =(clrnc/midsurf);
	vec2 coord = sdfcm(uv).xy*vec2(4.,2.);//vec2(clrnc,midsurf);

	vec2 iuv= floor(coord);
	vec2 fuv= coord-iuv;
		vec3 grid = vec3((step(.95, fuv.x) + step(.95, fuv.y)));
	vec3 mm3 = map(coord);
	ALBEDO = vec3(grid);//vec3(sin(tbf*32.)*sin(clrnc*16.));//vec3(smoothstep(0.,0.5,a));
	//ALBEDO = vec3(bn(coord));//vec3(smoothstep(0.1,0.,mm3.x));
	//*hash32(iuv)
	//ALBEDO = vec3(smoothstep(0.1,0.,m.x)+smoothstep(0.1,0.,m2.x));//+smoothstep(0.1,0.,m22.x))
	//+hash32(iuv)
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

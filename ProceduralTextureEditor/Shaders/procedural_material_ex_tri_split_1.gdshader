shader_type spatial;
render_mode world_vertex_coords;
uniform float mult;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;
uniform sampler2D sed:filter_nearest;


#include "shader_modules/library.gdshaderinc"



vec2 p_distr(vec2 uv){


	vec2 outp=random2(uv);
	return outp;
}

bool is_in_tri(vec2 p, vec2 a, vec2 b, vec2 c) {
    vec2 v0 = b - a;
    vec2 v1 = c - a;
    vec2 v2 = p - a;

    float dot00 = dot(v0, v0);
    float dot01 = dot(v0, v1);
    float dot02 = dot(v0, v2);
    float dot11 = dot(v1, v1);
    float dot12 = dot(v1, v2);

    float inv = 1.0 / (dot00 * dot11 - dot01 * dot01);
    float u = (dot11 * dot02 - dot01 * dot12) * inv;
    float v = (dot00 * dot12 - dot01 * dot02) * inv;

    return (u >= 0.0) && (v >= 0.0) && (u + v <= 1.0);
}

vec3 tri(vec2 uv) {
    const int ITERATIONS = 3;
    const float NOISE_STRENGTH = 0.1;

    vec2 a = vec2(0.0);
    vec2 b = vec2(3.0, 0.0);
    vec2 c = vec2(1.5, 3.0);

    for(int i = 0; i < ITERATIONS; i++) {
        vec2 centroid = (a + b + c) / 3.0;
        vec2 p = centroid + random2(centroid) * NOISE_STRENGTH;

        bvec3 inside = bvec3(
            is_in_tri(uv, p, b, c),
            is_in_tri(uv, a, p, c),
            is_in_tri(uv, a, b, p)
        );

vec3 factors = vec3(inside) * 1.0; // Конвертация bool -> float

a = mix(a, p, factors.x);
b = mix(b, p, factors.y);
c = mix(c, p, factors.z);
    }

    return vec3(
        distance(uv, a),
        distance(uv, b),
        distance(uv, c)
    );
}




vec2 warped_coords(vec2 uv) {
    vec2 i_uv = floor(uv);
	vec2 c_uv = i_uv+vec2(1.);
    vec2 f_uv = fract(uv);

	vec2 a =p_distr(i_uv);
	vec2 b =p_distr(vec2(c_uv.x,i_uv.y));
	vec2 c =p_distr(vec2(i_uv.x,c_uv.y));
	vec2 d =p_distr(c_uv);

    vec2 offset = mix(
        mix(a, b, f_uv.x),
        mix(c, d, f_uv.x),
        f_uv.y
    );

    return uv + offset;
}

vec3 triang (vec2 st) {
	//st=warped_coords(st);
	vec2 px = st;
	px=fract(px)-vec2(0.5)+random2(floor(px))*0.5;

	vec2 py = st+vec2(12.5);
	py=fract(py)-vec2(0.5);

	vec2 pz = st;
	pz=fract(pz)-vec2(0.5);

	float x =length(px)*2.;
	float y =length(py)*2.;
	float z =length(pz)*2.;

	float ax =atan(px.x,px.y);
	float ay =atan(py.x,py.y);
	float az =atan(pz.x,pz.y);

	float fx =grand(ax);
	fx=smoothstep(fx+0.1,fx,x);

	float fy =grand(ay);
	fy=smoothstep(fy+0.1,fy,y);

	float fz =grand(az);
	fz=smoothstep(fz+0.1,fz,z);
//cross(cross(vec3(x,px),vec3(y,py)),vec3(z,pz))


    return vec3(fx


	);
}

float lines(vec2 uv){
	//uv=warped_coords(uv);

	vec3 smth = tri(uv)-vec3(0.5);
	float r = max(smth.x,max(abs(smth.y),abs(smth.z)))*2.; //length(smth)*2.;
	//r=length(smth);
    float f = 0.5;// abs(bn(uv))*0.5;//frand(a+bn(iuv));
	float edg =0.3;//fbm(uv);

	float	 f1 =smoothstep(f,f-edg,r);
return f1;
}



vec4 mat(vec2 uv){
	float f_out = lines(uv);
    return vec4(f_out,0.,0.,f_out);
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

    vec4 outp = mat(mp);

		float offset = 0.001;
		float mlp = 0.1;

		vec2 nuv = vec2(mp.x+offset,mp.y);
    vec3 fa = vec3(nuv.x, 0.0,mat(nuv).w*mlp);;

	    nuv = vec2(mp.x,mp.y-offset);
    vec3 fc = vec3(0.0, nuv.y,mat(nuv).w*mlp);

		 nuv = vec2(mp.x-offset,mp.y);
    vec3 fb = vec3(nuv.x, 0.0,mat(nuv).w*mlp);

	    nuv = vec2(mp.x,mp.y+offset);
    vec3 fd = vec3(0.0, nuv.y,mat(nuv).w*mlp);

	vec3 normal = 0.5+normalize(cross(fa-fb*vec3(1.,0.,1.), fc-fd*vec3(0.,1.,1.)))*vec3(1.,-1.,1.);

// Цветовая интерполяция между тремя точками



	//ALBEDO=vec3(mat(mp).x);
	vec3 col =tri(mp);
	if(col.x>1.){col.x=0.;}
	if(col.y>1.){col.y=0.;}
	if(col.z>1.){col.z=0.;}
	ALBEDO=col;//mat(mp).xxx;
	//ALBEDO=vec3(abs(col.x - col.y) + abs(col.y - col.z) + abs(col.z - col.x));
	//ALBEDO=vec3(vor(mp,0.1).y);
   // ROUGHNESS = 0.5;
	//NORMAL_MAP=normal;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
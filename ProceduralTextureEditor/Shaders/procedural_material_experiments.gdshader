shader_type spatial;
//render_mode world_vertex_coords;
uniform float mult;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;


#include "shader_modules/library.gdshaderinc"


/*
float hash( uint n )
{   // integer hash copied from Hugo Elias
	n = (n<<13U)^n;
    n = n*(n*n*15731U+789221U)+1376312589U;
    return float(n&uvec3(0x0fffffffU))/float(0x0fffffff);
}
*/




vec2 metric(vec2 uv){
	//uv=floor(uv);
	vec2 smth = uv-0.5;
	//float r = length(smth)*2.;
	float r = smin_cube_poly(abs(smth.x),abs(smth.y),2.)*2.;
	float a = atan(smth.y,smth.x);

    return vec2(a,r);

}
float tile(vec2 uv){
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);

	float r = length(smth)*2.;
	//float r = max(abs(smth.x),abs(smth.y))*2.;
	float a = atan(smth.y,smth.x);
 			float f = frand(a+brand(length(uv))*PI)*0.6;
    		f=smoothstep(f+0.1,f,r)+smoothstep(f-0.1,f,r);
			f=f-1.;
			//f=smin_cube_poly(f,r,f);
    return f;
}

float tileN(vec2 uv){
	//uv+=fbm(uv)*4.;
	float f=tile(uv);
	//f=max(tile(uv+vec2(0.5)),f);
	//f=max(tile(uv+vec2(0.5,0.)),f);
	//f=max(tile(uv+vec2(0.,0.5)),f);
    return smoothstep(0.,1.,1.-f);
}


vec2 tile2(vec2 uv){
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);

	float r = length(smth)*2.;
	//float r = max(abs(smth.x),abs(smth.y))*2.;
	float a = atan(smth.y,smth.x);
 			float f = cos(a*3.+TIME);
    		f=1.-smoothstep(f,f,r);

    return smth*f;

}





vec3 mvoronoi(vec2 uv){
    vec3 color = vec3(.0);
    // Tile the space
    vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
    float m_dist = 10.;  // minimum distance
    for (int y= -1; y <= 1; y++) {
        for (int x= -1; x <= 1; x++) {

            vec2 neighbor = vec2(float(x),float(y));
            vec2 point = tile2(floor((uv+neighbor)*1.));
            vec2 diff = neighbor + point - fuv;

            float dist = length(diff);
			m_dist=min(m_dist,dist);
        }
    }
  color.z = m_dist;

    return color*3.;//ceil(color);
}
vec3 vr2(vec2 p)  { return mvoronoi(p); }



/*
float lines(vec2 uv){

	uv+=fbm(uv*0.1);
	//uv.x+=floor(uv.y)*32.;
	//uv.x+=bn(uv.yy);
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);

	vec2 smth = fuv-vec2(0.5,0.5);
	float r = abs(smth.x)*2.;
    float f = brand(uv.y);
	float edg = fbm(uv);
    	float f1 =1.-smoothstep(f-edg,f,r);

		f1 += smoothstep(f,f+edg,r);

	r = abs(smth.y)*2.;
	f = grand(uv.x);
   	//edg = 0.1;

    	float f2 =1.-smoothstep(f-edg,f,r);
		f2 += smoothstep(f,f+edg,r);

    //float nois = fbm(uv*4.)*0.4;
    return smin_cube_poly(f1,f2,edg*0.5);
}
*/


float bi( in float x ){

	//uv+=fbm(uv*0.1)*4.;
	//uv.x+=floor(uv.y)*32.;
	uint ix = uint(x);
    float fx = fract(x);

	float smth = fx-0.5;
	float r = abs(smth)*2.;
    float f = x;
    	float f1 =smoothstep(f-0.9,f,r);
		//f1 += smoothstep(f,f+edg,r);


    return (f1-0.5);//min(f1,f2);
}





float lines(vec2 uv){
	float fra= fbm(uv*0.1)*2.;
	uv.x+=fract(fra);
	uv.y+=fract(fra);
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);

	vec2 smth = fuv-vec2(0.5,0.5);
	float r = abs(smth.x)*2.;
    float f = frand(uv.y*0.5)-0.5;
	float edg =abs(wn(uv*0.3,0.1));
		float col1 = (1.-step(f-edg,r))*abs(bn(iuv.xx));
			  col1 += (step(f+edg,r))*abs(bn(floor(uv.xx+1.5)));

	r = abs(smth.y)*2.;
    f = frand(uv.x*0.5)-0.5;
		float col2 = (1.-step(f-edg,r))*abs(bn(iuv.yy)+0.5);
			  col2 += (step(f+edg,r))*abs(bn(floor(uv.yy+1.5))+0.5);


    return col1*col2;//min(col1,col2);
}



float lines3d(vec3 uv){
	//uv.x+=fbm(uv*0.01)*32.;
	vec3 iuv = floor(uv);
    vec3 fuv = fract(uv);

	vec3 smth = fuv-vec3(0.5);
	float r = abs(smth.x)*2.;
    float f = vor3(uv).x;
		float col1 = (1.-step(f,r))*abs(bn(iuv.xx));
			  col1 += (step(f,r))*abs(bn(floor(uv.xx+1.5)));

	r = abs(smth.y)*2.;
    f = vor3(uv).y;
		float col2 = (1.-step(f,r))*abs(bn(iuv.yy));
			  col2 += (step(f,r))*abs(bn(floor(uv.yy+1.5)));

	r = abs(smth.z)*2.;
    f = vor3(uv).z;
		float col3 = (1.-step(f,r))*abs(bn(iuv.zz));
			  col3 += (step(f,r))*abs(bn(floor(uv.zz+1.5)));


    return col2*col1*col3;
}


vec4 mat(vec2 uv){

	//uv*=rotate2d(PI*cos(TIME));
	//vec3 muv = simplexGrid(uv)*32.;
	float f_out = lines(uv);//tileN(uv);//lines(uv+lines(uv)+lines(uv));
		//f_out=pseudoVoronoi(uv);
    return vec4(f_out,0.,0.,f_out);//min(f1,f2);
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


	vec4 mt =mat(mp);
	ALBEDO=vec3(mt.x);//colorize(mt.x,vec3(1., 0.8, 0.5),vec3(0.5, 0.5, 0.3),vec3(0.5, 0.360784, 0.3), vec3(0., 0.2, 0.333333));

	//ALBEDO=vec3(mat(mp+tile2(mp)).x);
	//SPECULAR = 0.5;
	//METALLIC=0.5;
    //ROUGHNESS = 0.5;
	NORMAL_MAP=normal;
	NORMAL_MAP_DEPTH=normal_power;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
shader_type spatial;
/*

//somethingalien
float tile_alien(vec2 uv){
	float worl =snoise(uv);
	uv+=worl;
	float f_out=0.;
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);

	float r = length(smth.y)*2.;
	float a = atan(smth.y,smth.x);
 			float f1 =wn(uv,bn(vec2(a,r)))+0.5;
    		f1=1.-smoothstep(f1-0.9,f1,r);

    return f1;
}


float FTN_alien (in vec2 st) {
    // Initial values
    float value = 0.5;
    float amplitude = 1.;
    //
    // Loop of octaves
    for (int i = 0; i < OCTAVES; i++) {
        value += amplitude * tile(st);//wn(st,1.)
        st *= 1.5;
        amplitude *= 0.9;
    }
    return value;
}

*/
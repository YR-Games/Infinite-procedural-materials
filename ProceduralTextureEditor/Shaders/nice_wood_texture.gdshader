shader_type spatial;
uniform float xc :hint_range(0.0, 1.0, 0.01);
uniform float yc :hint_range(0.0, 1.0, 0.01);

#include "shader_modules/library.gdshaderinc"

void vertex() {
	// Called for every vertex the material is visible on.
}

float vcm(vec2 uv, float time) {
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

            if (dist < d1) {
                d2 = d1;
                d1 = dist;
            } else if (dist < d2) {
                d2 = dist;
            }
        }
    }
    float clearance = d1 + d2;
    return clearance*d1;
}




void fragment() {
	vec2 uv = UV*vec2(8.,64.);


	float coord = vcm(uv,0.1)*6.;//vec2(clrnc,midsurf);
	float noise =bn(uv*32.);
	float w=frand(coord);
	ROUGHNESS=1.-w*0.4;
	w+=noise*0.3;
	
	ALBEDO = colorize(w,vec3(0.454,0.26666,0.203),vec3(0.1),vec3(0.2),vec3(0.3));//vec3(sin(tbf*32.)*sin(clrnc*16.));//vec3(smoothstep(0.,0.5,a));

}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

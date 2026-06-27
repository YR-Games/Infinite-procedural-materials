shader_type canvas_item;

uniform float scale = 1. ;
uniform float seed = 1. ;

vec2 hash22(vec2 p)
{
	vec3 p3 = fract(vec3(p.xyx) * vec3(.1031, .1030, .0973));
    p3 += dot(p3, p3.yzx+33.33);
    return fract((p3.xx+p3.yz)*p3.zy);

}

float vcm(vec2 uv, float time) {
    vec2 i_uv = floor(uv);
    vec2 f_uv = fract(uv);
    
    float d1 = 1e5; // smallest distance
    float d2 = 1e5; // second smallest distance
    
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 neighbor = vec2(float(i), float(j));
            vec2 point = hash22(i_uv + neighbor);
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



float CellNoiseAlt(in vec2 uv){
	return vcm(uv*scale,seed);
}


void fragment() {
	COLOR.xyz=vec3(CellNoiseAlt(UV));
}

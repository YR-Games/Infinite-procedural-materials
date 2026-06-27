shader_type canvas_item;

uniform float scale = 1. ;

	float random(in vec2 st) {
			vec3 p3  = fract(vec3(st.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
	}

float bn(vec2 st) {
    vec2 i = floor(st);
    vec2 f = fract(st);
    vec2 u = f*f*f*(f*(f*6.-15.)+10.);
    return mix( mix( random( i + vec2(0.0,0.0) ),
                     random( i + vec2(1.0,0.0) ), u.x),
                mix( random( i + vec2(0.0,1.0) ),
                     random( i + vec2(1.0,1.0) ), u.x), u.y);
}

float blueNoise(in vec2 uv){
	return bn(uv*scale);
}


void fragment() {
	COLOR.xyz=vec3(blueNoise(UV));
	//COLOR.w =1.;
}

/**/
//float random(in vec2 st) {
//	  return -1.+ 2. * fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453);}
	float random(in vec2 st) {
			vec3 p3  = fract(vec3(st.xyx) * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
	}
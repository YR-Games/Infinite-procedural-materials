const vec4 RANDOM_SCALE = vec4(.1031, .1030, .0973, .1099);

vec2 random2(vec2 p) {
     vec3 p3 = fract(p.xyx * RANDOM_SCALE.xyz);
     p3 += dot(p3, p3.yzx + 19.19);
     return fract((p3.xx + p3.yz) * p3.zy);}
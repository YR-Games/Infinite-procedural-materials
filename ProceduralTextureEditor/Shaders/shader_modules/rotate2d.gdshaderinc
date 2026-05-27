mat2 rotate2d(const in float r){
    float c = cos(r);
    float s = sin(r);
    return mat2(vec2(c, -s),vec2( s, c));}
shader_type spatial;
render_mode world_vertex_coords;
varying vec3 wpos;
//#include "shader_modules/library.gdshaderinc"
void vertex() {
	wpos=VERTEX;
	//wpos.y*=0.2;
	wpos.x*=4.;
}

vec3 texture_wood(vec3 p){
    
    p /= 2.;
    vec3 p0 = p;
    
    // Old trick to mix things up. I use it too much. 
    p = sin(p*4.3 + cos(p.yzx*6.7));
    
    float n = dot(p + sin(p*13.)*.03, vec3(3.));
    
    float grain = 1.-abs(dot(sin(p0*120.5 + n*6.283 + sin(p0.zxy*121.3)), vec3(.333)));

    
    // Smooth fract. Old trick. Like fract, but smoother.
    n = fract(n + fract(n*4.)*.1);
    n = min(n, n*(1.-n)*6.); // The final term controls the smoothing.
    
    float w = min(n*.85 + grain*.2, 1.);
    
    // Quick coloring. Needs work. 
    return mix(vec3(.5, .15, .025), vec3(.75, .3, .1)*2., w*.75 + .25)*(w*.6 + .4);
    
    //return vec3(w);
}

void fragment() {

ALBEDO=texture_wood(wpos*4.);
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}

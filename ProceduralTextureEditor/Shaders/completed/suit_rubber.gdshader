shader_type spatial;
//render_mode world_vertex_coords;
uniform float mult;
group_uniforms height;
uniform float heightmap_scale : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform int heightmap_layers : hint_range(8, 128, 1) = 32;
uniform float depthOffset : hint_range(0.0, 1.0, 0.1) = 0;
varying vec3 w_pos;
varying vec3 w_norm;
varying float curvature;
varying float edges;


#include "shader_modules/library.gdshaderinc"


void vertex(){
	    w_norm = NORMAL;
		w_pos = VERTEX;
		curvature=max(dot(NORMAL,VERTEX+vec3(0.,0.75,0.)),0.);



	}

	float tile(vec2 uv){
	vec2 iuv = floor(uv);
    vec2 fuv = fract(uv);
	vec2 smth = fuv-vec2(0.5,0.5);

	float r = max(abs(smth.x),abs(smth.y))*2.;
	float a = atan(smth.y,smth.x);
 			float f1 =1.;
    		f1=smoothstep(f1-0.6,f1,r);

    return (1.-f1)*0.1;
}



float height(vec3 pos){

	return wn3(pos,1.24)*0.2;
}


vec3 normalFromHeight(vec3 position, float offset, float mlp) {
    // Calculate neighboring positions based on the 3D coordinates
    vec3 nuvRight = vec3(position.x + offset, position.y, position.z);
    vec3 fa = vec3(nuvRight.x, nuvRight.y, height(nuvRight) * mlp);

    vec3 nuvLeft = vec3(position.x - offset, position.y, position.z);
    vec3 fb = vec3(nuvLeft.x, nuvLeft.y, height(nuvLeft) * mlp);

    vec3 nuvDown = vec3(position.x, position.y - offset, position.z);
    vec3 fc = vec3(nuvDown.x, nuvDown.y, height(nuvDown) * mlp);

    vec3 nuvUp = vec3(position.x, position.y + offset, position.z);
    vec3 fd = vec3(nuvUp.x, nuvUp.y, height(nuvUp) * mlp);

    // Calculate the vectors for the cross product
    vec3 rightVector = fa - fb; // Vector along the x-axis
    vec3 upVector = fc - fd;    // Vector along the y-axis

    // Calculate the normal using the cross product
    vec3 normal = 0.5+normalize(cross(rightVector, upVector));

    // Flip the normal if necessary (depends on the coordinate system)
    return normal;
}


void fragment() {
	vec3 mp = w_pos*mult;
	vec3 normal = normalFromHeight(mp,0.001,0.1);
	float pointiness=max(w_norm.y,0.);
	ALBEDO=vec3(0.3,0.4,0.1);
	vec3 dX =dFdx(w_norm);
	vec3 dY =dFdy(w_norm);
	//edges = length(dX)+length(dY);

	ALBEDO=vec3(curvature);
	//SPECULAR =1.519;
//	ROUGHNESS =0.6;
	//NORMAL_MAP=normal;



	//SPECULAR =1.180;
}

//void light() {
	// Called for every pixel for every light affecting the CanvasItem.
	// Uncomment to replace the default light processing function with this one.
//}
/*

*/
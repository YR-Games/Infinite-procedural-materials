shader_type canvas_item;

uniform float scale = 1. ;
uniform float chaos = 1.;
uniform int numOctaves = 1;

float sphereGrid(vec2 uv) {
    vec2 squaregrid = fract(uv) - .5; //rectangular grid with center in the middle
    float spheregrid = dot(squaregrid, squaregrid); //squared distance form scenter
    return spheregrid;
}

#define cos1            1.0049000034 //cos((pi * 24.)/180.)*1.1
#define sin1            0.4474103074 //sin((pi * 24.)/180.)*1.1


float cellTiling(vec2 uv) {
    float c = sphereGrid(uv);// first grid
        
    mat2 m = mat2(vec2(cos1, -sin1),vec2(sin1, cos1)); // rotation/scale matric
    
    uv *= m; //each iteration gets rotated and scaled one addional time
    //c = smin_cube_poly(c, sphereGrid(uv),0.0); // blending the voronoi with
     c = min(c, sphereGrid(uv));
    uv *= m; //each iteration gets rotated and scaled one addional time
    //c = smin_cube_poly(c, sphereGrid(uv),0.0); // blending the voronoi with 
    c = min(c, sphereGrid(uv));
    return c; //sqrt for center distance, 1.5 for 0-1 range
}

float cfbm( in vec2 x, in float H, in int numOct )
{    
    float G = exp2(-H);
    float f = 1.0;
    float a = 1.0;
    float t = 0.0;
    for( int i=0; i<numOct; i++ )
    {
        t += a*cellTiling(f*x);
        f *= 2.;
        a *= G;
    }
    return t;
}



float cellNoise(in vec2 uv){
	return cfbm(uv*scale,chaos,numOctaves);
}


void fragment() {
	COLOR.xyz=vec3(cellNoise(UV));
	//COLOR.w =1.;
}

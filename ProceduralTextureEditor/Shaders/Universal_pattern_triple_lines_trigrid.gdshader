shader_type spatial;

uniform vec2 scale;
uniform float normal_power;
varying vec3 w_pos;
varying vec3 w_norm;
uniform sampler2D sed:filter_linear;


#include "shader_modules/library.gdshaderinc"


void vertex(){
w_norm = NORMAL;
w_pos = VERTEX;
}


void fragment() {
	   vec3 anorm=abs(w_norm);
	vec3 v=w_pos;
	v.x*=floor(sign(w_norm.z));
	v.z*=-floor(sign(w_norm.x));
	v.y=-v.y;
	vec2 mp =mix(v.xy,v.zy,round(anorm.x));
	mp=mix(mp,w_pos.xz*-sign(w_norm.y),round(anorm.y));

	mp*=scale;

mp.y*=1.1547;
vec3 trigrid = vec3(mp.x+0.5*mp.y, mp.y,mp.x-0.5*mp.y);

vec3 id =floor(trigrid);
vec3 fuv =fract(trigrid);
bool tri_type = (fuv.x + fuv.y) < 1.0; // false => the other diagonal
vec3 v0 = id;
vec3 v1 = id + vec3(1, 0, 0);
vec3 v2 = tri_type ? (id + vec3(0, 1, 0)) : (id + vec3(0, 0, 1));

// Barycentric coordinates for the two triangles
vec3 bary;
if (tri_type) {
    bary = vec3(1.0 - fuv.x - fuv.y, fuv.x, fuv.y);
} else {
    bary = vec3(fuv.z, 1.0 - fuv.z - fuv.y, fuv.y);
}

// Per‑vertex random offset (controllable strength)
float jitter_strength = 0.1; // uniform
vec3 jitter0 = hash33(v0) * jitter_strength;
vec3 jitter1 = hash33(v1) * jitter_strength;
vec3 jitter2 = hash33(v2) * jitter_strength;

// Interpolate offset at the fragment position
vec3 offset = bary.x * jitter0 + bary.y * jitter1 + bary.z * jitter2;

// Apply the offset to the original world position (or to mp)
// Option 1: offset mp directly
vec2 mp_jittered = mp + offset.xy;   // use only XY, or keep 3D

// Recompute trigrid with jittered mp
vec3 trigrid_jittered = vec3(mp_jittered.x + 0.5 * mp_jittered.y,
                             mp_jittered.y,
                             mp_jittered.x - 0.5 * mp_jittered.y);
vec3 fuv_jittered = fract(trigrid_jittered);

	vec3 grid = vec3((step(.98, fuv.x) + step(.98, fuv.y)) + step(.98, fuv.z));
	
    ALBEDO = grid*hash33(id);
}

shader_type spatial;

void vertex() {
	float thet=1.;
	mat3 rot = mat3(
		vec3(1.,0.,0.),
		vec3(0.,cos(thet),-sin(thet)),
		vec3(0.,sin(thet),cos(thet)));
		VERTEX*=rot;
}

void fragment() {
	ALBEDO=vec3(1.,0.,0.);
}

//void light() {
	// Called for every pixel for every light affecting the material.
	// Uncomment to replace the default light processing function with this one.
//}

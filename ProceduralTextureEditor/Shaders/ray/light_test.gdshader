shader_type spatial;
render_mode world_vertex_coords;
varying vec3 w_norm;
varying vec3 w_pos;
varying vec3 lgh;
uniform sampler2D txtr;
uniform sampler2D lit;
void vertex(){
	    w_norm = NORMAL;
		w_pos = VERTEX;
	}

void fragment() {
	float mult =2.;
	vec3 anorm=abs(w_norm);
	vec3 v=w_pos;
	v.x*=floor(sign(w_norm.z));
	v.z*=-floor(sign(w_norm.x));
	v.y=-v.y;
	vec2 mp =mix(v.xy,v.zy,round(anorm.x));
	mp=mix(mp,w_pos.xz*-sign(w_norm.y),round(anorm.y));
	mp*=mult;

	vec3 l_pos = vec3(0.,1.5,0.);
	vec3 dir =w_pos-l_pos;
	//vec2 sphr = vec2(acos(dir.y)/PI,sign(dir.z)*acos(dir.x/length(dir.xz))/TAU);
	//float test = texture(lit,sphr).r*3.;
	//test=abs(length(dir)-test);
	//if(test<0.1){test=1.;}else{test=0.;} //smoothstep(test,test+0.1,1.);
	float test =1.;
	//test =smoothstep(length(dir),length(dir)+0.5,1.);
	// посчитать один отскок и получится просто имба, спойлер - не получилась
	//LIGHT_VERTEX=vec3(0.);
	ALBEDO=texture(txtr,mp).rgb;
	//EMISSION +=clamp(dot(NORMAL, (VIEW_MATRIX*vec4(1.,0.,0.,0.)).xyz), 0.0, 1.0) * vec3(1.)*ALBEDO;
	//IRRADIANCE = vec4(1.,0.,0.,1.);
	//IRRADIANCE.rgb=clamp(dot(NORMAL, (VIEW_MATRIX*vec4(1.,0.,0.,0.)).xyz), 0.0, 1.0) * vec3(1.)*test*ALBEDO;
	//RADIANCE = vec4(0.,1.,0.,1.);
	//if(length(EMISSION)<0.01){EMISSION=vec3(-10.);}
	//EMISSION += LIGHT_VERTEX;
}
/**/
void light() {
	vec3 l_pos = vec3(-1.,1.5,4.);
	float test = 0.;
	vec3 dir =w_pos-l_pos;
	float aten=1./length(dir);
	//test= smoothstep(length(dir),length(dir)+0.5,1.);
 //DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR;
 //DIFFUSE_LIGHT += clamp(dot(NORMAL,(VIEW_MATRIX*vec4(-dir,0.)).xyz), 0.0, 1.0)* (1.-ATTENUATION) *aten * LIGHT_COLOR*0.5;
   DIFFUSE_LIGHT=vec3(ATTENUATION);
}

extends MultiMeshInstance3D

#var ter_mat = preload("res://terrain_mat.tres")
# Called when the node enters the scene tree for the first time.
var squarePos =[Vector3(-1.5,0,-1.5),Vector3(-1.5,0,-0.5),Vector3(-1.5,0,0.5),Vector3(-1.5,0,1.5),
				Vector3(-0.5,0,-1.5),Vector3(-0.5,0,1.5),
				Vector3(0.5,0,-1.5),Vector3(0.5,0,1.5),
				Vector3(1.5,0,-1.5),Vector3(1.5,0,-0.5),Vector3(1.5,0,0.5),Vector3(1.5,0,1.5)
					]
var pointsArray =[];

func _ready():
	multimesh.visible_instance_count=-1;
	#pointsArray.resize(266342400);
	#for i in 266342400:
	#	pointsArray[i] = Vector3(0.,randf()/8.,0.);
	#multimesh.mesh.surface_get_material(0).set_shader_parameter("arr", pointsArray)
	
	
	
	var tr = Transform3D()
	
	
	tr.basis = Basis(Vector3(16., 0., 0.),Vector3( 0., 1., 0.),Vector3( 0., 0., 16.))
	for i in 2:
		for j in 2:
			tr.origin =Vector3(-8+j*16,0,-8+i*16)
			multimesh.set_instance_transform(i+j*4,tr)
			
#Луковые колечки
	var s=8;
	for r in range(1,8):
		s=s*2
		tr.basis = Basis(Vector3(s, 0., 0.),Vector3( 0., 1., 0.),Vector3( 0., 0., s))
		for k in 12:
			tr.origin =squarePos[k]*s
			multimesh.set_instance_transform(12*r+k,tr)

	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

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
	
	
	tr.basis = Basis(Vector3(64., 0., 0.),Vector3( 0., 1., 0.),Vector3( 0., 0., 64.))
	#tr=tr.rotated(Vector3(1.,0.,0.),-PI/2.)
	for i in 4:
		for j in 4:
			tr.origin =Vector3(i*64,0,j*64)
			multimesh.set_instance_transform(i+j*4,tr)
			
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

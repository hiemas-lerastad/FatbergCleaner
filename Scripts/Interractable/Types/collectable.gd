extends interractable

var collectable_cleared: bool

func _physics_process(delta):
	if(collectable_cleared):
		pass
	else:
		super._physics_process(delta)

func _on_exposed():
	'''TBD, potentially sound ques/FX?'''
	pass # Replace with function body.


func _on_selected():
	$MeshInstance3D.material_override = load("res://Assets/Materials/test_material.tres")
	
func _on_deselected():
	$MeshInstance3D.material_override = null

func _on_cleared():
	'''Re-enable physics once cleared'''
	collectable_cleared = true
	freeze = false
	sleeping = false
	mass = 2
	set_collision_layer(3)
	set_collision_mask_value(3,true)
	set_collision_layer(4)
	set_collision_mask_value(4,true)

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


func _on_cleared():
	'''Re-enable physics once cleared'''
	collectable_cleared = true
	freeze = false
	sleeping = false
	mass = 2
	collision_layer = 3
	collision_mask = 3

extends interractable

var collectable_cleared: bool
var grav = Vector3(0,9.8,0)


func _on_exposed():
	pass # Replace with function body.


func _on_cleared():
	freeze = false
	sleeping = false
	mass = 2
	collision_layer = 3
	collision_mask = 3

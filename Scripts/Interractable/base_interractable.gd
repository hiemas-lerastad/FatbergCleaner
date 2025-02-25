extends RigidBody3D
class_name interractable

signal exposed
signal cleared

@export var holding_area: Area3D
@export var visible_area: VisibleOnScreenNotifier3D
@export var parent_checker_raycast: RayCast3D ## raycaster which will check if it can "see" the player (and as such some of the chunk around the object has been removed)

var has_been_seen: bool # set to true once interractable has been reveiled
var has_been_exposed: bool # same but for having all space around cleared
func _physics_process(delta):
	#holding_area.force
	holding_area.collision_layer = 3
	
	if(visible_area.is_on_screen()): #TODO: This may need a cull distance adding so we dont just have hundreds of active raycasts 
		parent_checker_raycast.target_position = parent_checker_raycast.to_local(get_tree().root.get_node("Main/Player").global_position)
		parent_checker_raycast.force_raycast_update()
		var surrounding_bodies: Array = holding_area.get_overlapping_bodies()
		var RayCheckCollider = parent_checker_raycast.get_collider() # may be type StaticBody or Characterbody so dont type it, only used for one check
		
		
		if(has_been_seen and len(surrounding_bodies) == 0):
			if(has_been_exposed != true):
				''' cleared for 1st time'''
				has_been_exposed = true
				emit_signal("cleared")
		elif((RayCheckCollider is CharacterBody3D and RayCheckCollider.name == "Player") or len(surrounding_bodies) > 0):
			''' has a path to outside fatberg'''
			if(has_been_seen != true):
				''' seen for 1st time'''
				emit_signal("exposed")
				has_been_seen = true
		elif(RayCheckCollider is StaticBody3D):
			''' object inside fatberg TBD: Potential sound effects to hint at hidden object?'''
			pass
		else:
			''' any other situation i havent thought of'''
			pass
		

func _ready():
	pass

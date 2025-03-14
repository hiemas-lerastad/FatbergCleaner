class_name Player
extends CharacterBody3D

@export_group("Settings")
@export var speed: float = 5.0;
@export var jump_velocity: float = 4.5;
@export var mouse_sensitivity: float = 0.002;

@export_group("Nodes")
@export var camera: Camera3D;
@export var interact_cast: RayCast3D;
@export var carve_indicator: MeshInstance3D;

@export_group("Debug")
@export var collision_test_scene: PackedScene;

var last_interractable_selected: interractable

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED;

func physics_player_interraction() -> void:
	if interact_cast.is_colliding() and interact_cast.get_collider() is StaticBody3D and interact_cast.get_collider().name != "Floor": ## if looking at fatberg
		
		if(last_interractable_selected != null):
			last_interractable_selected._on_deselected()
			last_interractable_selected = null
		
		if not carve_indicator.visible == true:
			carve_indicator.visible = true;
		carve_indicator.global_position = interact_cast.get_collision_point()
	elif(interact_cast.get_collider() is interractable): ## if looking at interractable
		if(last_interractable_selected == null):
			carve_indicator.visible = false
			var looking_at: interractable = interact_cast.get_collider()
			looking_at._on_selected()
			last_interractable_selected = looking_at
	else:
		if(last_interractable_selected != null):
			last_interractable_selected._on_deselected()
			last_interractable_selected = null
		carve_indicator.visible = false;

func _physics_process(delta: float) -> void:
	if not is_on_floor() and not Globals.debug:
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("move_jump") and (is_on_floor() or Globals.debug):
		velocity.y = jump_velocity

	if Input.is_action_just_released("move_jump") and Globals.debug:
		velocity.y = 0 
		
	if Input.is_action_just_released("move_down") and Globals.debug:
		velocity.y = 0 
		
	if Input.is_action_just_pressed("move_down") and Globals.debug:
		velocity.y = -jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()

	physics_player_interraction()

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -deg_to_rad(70), deg_to_rad(70))

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		interact_cast.force_raycast_update()
		if interact_cast.is_colliding():
			var collider = interact_cast.get_collider()
			if(collider is StaticBody3D and collider.name != "Floor"):
				collider.parent.carve_around_point((interact_cast.get_collision_point()), 4.0);
			elif(collider is interractable):
				print("HI")
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and Globals.debug:
		interact_cast.force_raycast_update()
		if interact_cast.is_colliding():
			var collider: StaticBody3D = interact_cast.get_collider()
			collider.parent.add_around_point((interact_cast.get_collision_point()), 4.0);

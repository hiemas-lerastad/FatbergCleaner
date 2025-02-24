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

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED;

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("move_jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

	move_and_slide()
	
	if interact_cast.is_colliding():
		if not carve_indicator.visible == true:
			carve_indicator.visible = true;
		carve_indicator.global_position = interact_cast.get_collision_point()
	elif carve_indicator.visible == true:
		carve_indicator.visible = false;

func _input(event):
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		camera.rotate_x(-event.relative.y * mouse_sensitivity)
		camera.rotation.x = clampf(camera.rotation.x, -deg_to_rad(70), deg_to_rad(70))

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		interact_cast.force_raycast_update()
		if interact_cast.is_colliding():
			
			var collider = interact_cast.get_collider()
			if(collider is StaticBody3D):
				collider.parent.carve_around_point((interact_cast.get_collision_point()), 4.0);

class_name Level
extends Node3D

@export var speed: float = 1.0;
@export var pivot: Node3D;

@export var fatbergs: Array[MarchingCubeInstance];

func _ready() -> void:
	Globals.level = self;

func _process(delta: float) -> void:
	pivot.rotate_y(delta * speed)

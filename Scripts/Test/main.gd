class_name Level
extends Node3D

@export var debug: bool = false;

func _ready() -> void:
	Globals.level = self;
	Globals.debug = debug;

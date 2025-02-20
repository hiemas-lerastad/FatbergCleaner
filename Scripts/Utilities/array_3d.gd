class_name Array3D

var values: PackedFloat32Array;
var x_max: int;
var y_max: int;
var z_max: int;

func initialise_size(x_size: int, y_size: int, z_size: int) -> void:
	var size = x_size * y_size * z_size;
	x_max = x_size;
	y_max = y_size;
	z_max = z_size;

	values.resize(size);
	
func get_index_from_coord(x: int, y: int, z: int) -> int:
	return (z * x_max * y_max) + (y * x_max) + x;

func get_coord_from_index(index: int) -> Vector3:
	var z: int = int(float(index) / (x_max * y_max));
	var new_index: int = index - (z * x_max * y_max);
	var y = int(float(new_index) / x_max);
	var x = new_index % x_max;
	
	return Vector3(x, y, z);

func set_value(x: int, y: int, z: int, value):
	values[get_index_from_coord(x, y, z)] = value;

func get_value(x: int, y: int, z: int):
	return values[get_index_from_coord(x, y, z)]

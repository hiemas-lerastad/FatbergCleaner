class_name Array3D
## Array3D works the same as a triple nested array [[[]]] but is actually a 1D array

var values: Array;
var x_max: int;
var y_max: int;
var z_max: int;

## This defines the size of the 1D array
## This is useful to avoid errors when assigning to particular indices
func initialise_size(x_size: int, y_size: int, z_size: int) -> void:
	var size = x_size * y_size * z_size;
	x_max = x_size;
	y_max = y_size;
	z_max = z_size;

	values.resize(size);

## This takes the 3D coordinates and converts them to the relevant index in the 1D array
func get_index_from_coord(x: int, y: int, z: int) -> int:
	return (z * x_max * y_max) + (y * x_max) + x;

## This takes the 1D index and converts them to the relevant coordinates in the 3D array
func get_coord_from_index(index: int) -> Vector3:
	var z: int = int(float(index) / (x_max * y_max));
	var new_index: int = index - (z * x_max * y_max);
	var y = int(float(new_index) / x_max);
	var x = new_index % x_max;
	
	return Vector3(x, y, z);

## Allows for setting a value at a particular coordinate
func set_value(x: int, y: int, z: int, value):
	if get_index_from_coord(x, y, z) < values.size():
		values[get_index_from_coord(x, y, z)] = value;

## Allows for setting a value at a particular index
func set_value_index(index: int, value):
	values[index] = value;

## Allows for getting a value at a particular coordinate
func get_value(x: int, y: int, z: int):
	return values[get_index_from_coord(x, y, z)]
	
## Allows for getting a value at a particular index
func get_value_index(index: int):
	return values[index];

## The below is a mirror of base Array functions so they can be called on the class directly rather than its child property
func size() -> int:
	return values.size();

func fill(value) -> void:
	values.fill(value);
	
func append(value) -> void:
	values.append(value);
	
func append_array(value) -> void:
	values.append_array(value);

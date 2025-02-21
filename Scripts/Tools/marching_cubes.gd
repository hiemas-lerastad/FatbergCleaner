@tool
class_name MarchingCubeInstance;
extends Node3D;

@export_category('Settings')
@export var regenerate: bool:
	set(value):
		generate();

@export_range(0, 50) var size: int = 1:
	set(value):
		size = value;
		init_matrix()
		generate();
		
@export_range(1, 10, 1) var resolution: int = 1:
	set(value):
		resolution = value;
		init_matrix()
		generate();
		
@export_range(-1, 1, 0.1) var cutoff: float = 0.0:
	set(value):
		cutoff = value;
		generate();
		
@export var show_points: bool:
	set(value):
		show_points = value
		if points_node:
			points_node.visible = value;
		
@export var show_grid: bool:
	set(value):
		show_grid = value
		if cubes_node:
			cubes_node.visible = value;
		
@export var show_mesh: bool = true:
	set(value):
		show_mesh = value
		if triangles_node:
			triangles_node.visible = value;
		
@export_category("Nodes")
@export var points_node: MeshInstance3D;
@export var cubes_node: MeshInstance3D;
@export var triangles_node: MeshInstance3D;
@export var low_collision_node: CollisionShape3D;
@export var high_collision_node: CollisionShape3D;

@export_category("Assets")
@export var texture: CompressedTexture2D;
@export var chunk_scene: PackedScene = preload("res://Scenes/chunk.tscn");
@export var test_material: StandardMaterial3D;
		
var center_mesh: Node;
var cube_mesh: Node;
var triangle_mesh: Node;
var matrix: Array3D;
var chunks: Array3D;
		
func _ready() -> void:
	init_matrix();
	generate();

## This initialises and fills the matrix object (an Array3D) with its default values
## currently this is a cube shape
func init_matrix() -> void:
	var matrix_size = size * resolution;
	matrix = Array3D.new();
	matrix.initialise_size(matrix_size, matrix_size, matrix_size);
	
	for x in range(matrix_size):
		for y in range(matrix_size):
			for z in range(matrix_size):
				# Plane
				#if y < float(matrix_size) / 2 or y == 0:
					#matrix.set_value(x, y, z, -1)
				#else:
					#matrix.set_value(x, y, z, 1)
				
				# Cube
				if x == 0 or z == 0 or y == 0 or x == matrix_size -1 or y == matrix_size -1 or z == matrix_size -1:
					matrix.set_value(x, y, z, -1)
				else:
					matrix.set_value(x, y, z, 1)

## This reads the matrix object and based on the values it calculates three meshes
## a points mesh, to display the matrix values
## a cubes mesh, to show the boundry for each marching cube
## a triangles mesh, the final mesh within the cubes, made of triangles
func generate() -> void:
	if not matrix:
		init_matrix()
	
	var matrix_size = size * resolution;
	var mesh_points = ImmediateMesh.new();
	mesh_points.surface_begin(Mesh.PRIMITIVE_POINTS);
	
	var mesh_cubes: ImmediateMesh = ImmediateMesh.new();
	mesh_cubes.surface_begin(Mesh.PRIMITIVE_LINES);
	
	var mesh_triangles: ImmediateMesh = ImmediateMesh.new();
	mesh_triangles.surface_begin(Mesh.PRIMITIVE_TRIANGLES);
	var valid_surface: bool = false;
	
	for x in range(0, matrix_size):
		for y in range(0, matrix_size):
			for z in range(0, matrix_size):
				var point: Vector3 = Vector3(float(x) / float(resolution), float(y) / float(resolution), float(z) / float(resolution));
				var point_value: float = matrix.get_value(x, y, z);
				
				var point_color: Color = Color(
					float(point_value),
					float(point_value),
					float(point_value)
				);
				
				mesh_points.surface_set_color(point_color);
				mesh_points.surface_add_vertex(point);

				if x < matrix_size - 1 and y < matrix_size - 1 and z < matrix_size - 1:
					var cube_vertices: Array[Vector3] = _create_cube_vertices(point);
					var cube_values: Array[float] = _get_cube_values(matrix, Vector3(int(x), int(y), int(z)));
				
					if _validate_cube(cube_values):
						_add_cube_vertices(mesh_cubes, cube_vertices);

					var lookup_index : int = _get_lookup_index(cube_values);
				
					var triangles: Array = Constants.marching_triangles[lookup_index];
					
					var color: Color = Color(
						float(point.x + size) / float(size * 2), 
						float(point.y + size) / float(size * 2), 
						float(point.z + size) / float(size * 2)
					);

					for index in range(0, triangles.size(), 3):
						var point_1: int = triangles[index];
						if point_1 == -1: continue;
						
						var point_2: int = triangles[index + 1];
						if point_2 == -1: continue;
						
						var point_3: int = triangles[index + 2];
						if point_3 == -1: continue;
						
						var a0: int = Constants.cornerIndexAFromEdge[triangles[index]];
						var b0: int = Constants.cornerIndexBFromEdge[triangles[index]];

						var a1: int = Constants.cornerIndexAFromEdge[triangles[index+1]];
						var b1: int = Constants.cornerIndexBFromEdge[triangles[index+1]];

						var a2: int = Constants.cornerIndexAFromEdge[triangles[index+2]];
						var b2: int = Constants.cornerIndexBFromEdge[triangles[index+2]];

						var vertex1: Vector3 = _interpolate(cube_vertices[a0], cube_values[a0], cube_vertices[b0], cube_values[b0]);
						var vertex3: Vector3 = _interpolate(cube_vertices[a1], cube_values[a1], cube_vertices[b1], cube_values[b1]);
						var vertex2: Vector3 = _interpolate(cube_vertices[a2], cube_values[a2], cube_vertices[b2], cube_values[b2]);
						
						var vector_a: Vector3 = Vector3(
							vertex3.x - vertex1.x,
							vertex3.y - vertex1.y,
							vertex3.z - vertex1.z,
						)
						var vector_b: Vector3 = Vector3(
							vertex2.x - vertex1.x,
							vertex2.y - vertex1.y,
							vertex2.z - vertex1.z,
						)

						var vector_normal: Vector3 = Vector3(
							vector_a.y * vector_b.z - vector_a.z * vector_b.y,
							vector_a.z * vector_b.x - vector_a.x * vector_b.z,
							vector_a.x * vector_b.y - vector_a.y * vector_b.x,
						)

						mesh_triangles.surface_set_color(color);
						mesh_triangles.surface_set_normal(vector_normal);
						if vertex1 and vertex2 and vertex3:
							valid_surface = true;
							mesh_triangles.surface_add_vertex(vertex1);
							mesh_triangles.surface_add_vertex(vertex2);
							mesh_triangles.surface_add_vertex(vertex3);

	mesh_points.surface_end();
	mesh_cubes.surface_end();
	if valid_surface:
		mesh_triangles.surface_end();
	
	var material_points: StandardMaterial3D = StandardMaterial3D.new();
	material_points.vertex_color_use_as_albedo = true;
	material_points.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;
	material_points.use_point_size = true;
	material_points.point_size = 8;
	
	var material_cubes: StandardMaterial3D = StandardMaterial3D.new();
	material_cubes.vertex_color_use_as_albedo = true;
	material_cubes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;
	
	#var material_triangles: StandardMaterial3D = test_material;
	var material_triangles: StandardMaterial3D = StandardMaterial3D.new();
	material_triangles.vertex_color_use_as_albedo = true;
	
	mesh_points.surface_set_material(0, material_points);
	if points_node:
		points_node.mesh = mesh_points;
		points_node.visible = show_points;
		
	mesh_cubes.surface_set_material(0, material_cubes);
	if cubes_node:
		cubes_node.mesh = mesh_cubes;
		cubes_node.visible = show_grid;

	if valid_surface:
		mesh_triangles.surface_set_material(0, material_triangles);
		if triangles_node:
			triangles_node.visible = show_mesh;
			triangles_node.mesh = mesh_triangles;

			if mesh_triangles.create_trimesh_shape():
				low_collision_node.shape = null;
				low_collision_node.set_shape(mesh_triangles.create_convex_shape());
				high_collision_node.set_shape(mesh_triangles.create_trimesh_shape());
	else:
		if triangles_node:
			triangles_node.visible = false;
			low_collision_node.disabled = true;
			high_collision_node.disabled = true;

func _create_cube_vertices(point_position: Vector3) -> Array[Vector3]:
	var offset: float = 1.0 / float(resolution)

	return [
		Vector3(point_position.x, point_position.y, point_position.z),
		Vector3(point_position.x + offset, point_position.y, point_position.z),
		Vector3(point_position.x + offset,  point_position.y + offset, point_position.z),
		Vector3(point_position.x, point_position.y + offset, point_position.z),
		Vector3(point_position.x, point_position.y, point_position.z + offset),
		Vector3(point_position.x + offset, point_position.y, point_position.z + offset),
		Vector3(point_position.x + offset,  point_position.y + offset, point_position.z + offset),
		Vector3(point_position.x, point_position.y + offset, point_position.z + offset),
	]
	
func _get_cube_values(values_matrix: Array3D, point: Vector3) -> Array[float]:
	var x: int = int(point.x)
	var y: int = int(point.y)
	var z: int = int(point.z)

	return [
		values_matrix.get_value(x, y, z),
		values_matrix.get_value(x + 1, y, z),
		values_matrix.get_value(x + 1,  y + 1, z),
		values_matrix.get_value(x, y + 1, z),
		values_matrix.get_value(x, y, z + 1),
		values_matrix.get_value(x + 1, y, z + 1),
		values_matrix.get_value(x + 1,  y + 1, z + 1),
		values_matrix.get_value(x, y + 1, z + 1),
	]

func _add_cube_vertices(mesh: ImmediateMesh, cube_vertices: Array[Vector3]) -> void:
	mesh.surface_add_vertex(cube_vertices[0]);
	mesh.surface_add_vertex(cube_vertices[1]);
	
	mesh.surface_add_vertex(cube_vertices[1]);
	mesh.surface_add_vertex(cube_vertices[2]);
	
	mesh.surface_add_vertex(cube_vertices[2]);
	mesh.surface_add_vertex(cube_vertices[3]);
	
	mesh.surface_add_vertex(cube_vertices[0]);
	mesh.surface_add_vertex(cube_vertices[3]);
	
	mesh.surface_add_vertex(cube_vertices[0]);
	mesh.surface_add_vertex(cube_vertices[4]);
	
	mesh.surface_add_vertex(cube_vertices[2]);
	mesh.surface_add_vertex(cube_vertices[6]);
	
	mesh.surface_add_vertex(cube_vertices[5]);
	mesh.surface_add_vertex(cube_vertices[6]);
	
	mesh.surface_add_vertex(cube_vertices[5]);
	mesh.surface_add_vertex(cube_vertices[4]);
	
	mesh.surface_add_vertex(cube_vertices[5]);
	mesh.surface_add_vertex(cube_vertices[1]);
	
	mesh.surface_add_vertex(cube_vertices[6]);
	mesh.surface_add_vertex(cube_vertices[7]);
	
	mesh.surface_add_vertex(cube_vertices[4]);
	mesh.surface_add_vertex(cube_vertices[7]);
	
	mesh.surface_add_vertex(cube_vertices[3]);
	mesh.surface_add_vertex(cube_vertices[7]);

func _get_lookup_index(cube_values: Array[float]) -> int:
	var cube_index : int = 0
	if cube_values[0] < cutoff: cube_index |= 1
	if cube_values[1] < cutoff: cube_index |= 2
	if cube_values[2] < cutoff: cube_index |= 4
	if cube_values[3] < cutoff: cube_index |= 8
	if cube_values[4] < cutoff: cube_index |= 16
	if cube_values[5] < cutoff: cube_index |= 32
	if cube_values[6] < cutoff: cube_index |= 64
	if cube_values[7] < cutoff: cube_index |= 128

	return cube_index

func _interpolate(vertex1: Vector3, value1: float, vertex2: Vector3, value2: float) -> Vector3:
	var t: float = (cutoff - value1) / (value2 - value1);
	return Vector3(
		vertex1.x + t * (vertex2.x - vertex1.x),
		vertex1.y + t * (vertex2.y - vertex1.y),
		vertex1.z + t * (vertex2.z - vertex1.z)
	)

func _get_triangle_normal(a, b, c):
	var side1 = b - a
	var side2 = c - a
	var normal = side2.cross(side1)
	return normal

func _validate_cube(values: Array[float]) -> bool:
	var valid: bool = true;
	for index in values.size():
		var value: float = values[index];
		if values[0] < cutoff:
			if value > cutoff:
				valid = false;
		elif values[0] > cutoff:
			if value < cutoff:
				valid = false;
	return valid;
		
func carve_around_point(global_point: Vector3, radius: float) -> void:
	var local_point: Vector3 = (global_point - position) * resolution;
	var points: Array[Vector3] = _get_points_in_sphere(local_point, radius);

	for point in points:
		var distance: float = point.distance_to(local_point);
		var distance_normalised: float = 0 - (1 - (distance / radius));
		matrix.set_value(point.x, point.y, point.z, distance_normalised);

	generate();

func _get_points_in_sphere(center_point: Vector3, radius: float) -> Array[Vector3]:
	var points: Array[Vector3] = [];
	
	for x_index in range(center_point.x - radius, center_point.x + radius):
		for y_index in range(center_point.y - radius, center_point.y + radius):
			for z_index in range(center_point.z - radius, center_point.z + radius):
				if x_index >= matrix.x_max or y_index >= matrix.y_max or z_index >= matrix.z_max or x_index < 0 or y_index < 0 or z_index < 0:
					continue;

				if pow((x_index) - center_point.x, 2) + pow((y_index) - center_point.y, 2) + pow((z_index) - center_point.z, 2) < pow(radius, 2):
					points.append(Vector3(int(x_index), int(y_index), int(z_index)));

	return points;

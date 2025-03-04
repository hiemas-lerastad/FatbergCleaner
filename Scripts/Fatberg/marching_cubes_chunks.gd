@tool
class_name MarchingCubesInstance;
extends Node3D;

@export_category('Settings')
@export var regenerate: bool:
	set(value):
		_generate();

@export_range(0, 50) var size: int = 1:
	set(value):
		size = value;
		#init_matrix()
		#generate();
		
@export_range(0, 50) var chunk_size: int = 1:
	set(value):
		chunk_size = value;
		#init_matrix()
		#generate();
		
@export_range(1, 10, 1) var resolution: int = 1:
	set(value):
		resolution = value;
		#init_matrix()
		#generate();
		
@export_range(-1, 1, 0.1) var cutoff: float = 0.0:
	set(value):
		cutoff = value;
		#generate();
		#
#@export var show_points: bool:
	#set(value):
		#show_points = value
		#if points_node:
			#points_node.visible = value;
		
#@export var show_grid: bool:
	#set(value):
		#show_grid = value
		#if cubes_node:
			#cubes_node.visible = value;
		#
@export var show_mesh: bool = true:
	set(value):
		show_mesh = value
		if triangles_node:
			triangles_node.visible = value;
			
@export var initial_matrix: Matrix;
		
@export_category("Nodes")
@export var points_node: MeshInstance3D;
@export var cubes_node: MeshInstance3D;
@export var triangles_node: MeshInstance3D;
@export var chunk_container: Node3D;

@export_category("Assets")
@export var texture: CompressedTexture2D;
@export var chunk_scene: PackedScene = preload("res://Scenes/chunk.tscn");
@export var test_material: Material;
@export var test_material_2: Material;
		
var center_mesh: Node;
var cube_mesh: Node;
var triangle_mesh: Node;
var matrix: Array3D;
var chunks: Array3D;

var cubes: Array3D;
var _triangles: Array;
var _vertexes: Array;
		
func _ready() -> void:
	init_matrix();
	_generate();
	
func _physics_process(delta: float) -> void:
	if InputMap.has_action("interact_debug_print") and Globals.debug:
		if Input.is_action_just_pressed("interact_debug_print"):
			print('output to matrix.txt')
			var save_file = FileAccess.open("res://Debug/matrix.txt", FileAccess.WRITE)
			save_file.store_line(str(matrix.values))

## This initialises and fills the matrix object (an Array3D) with its default values
## currently this is a cube shape
func init_matrix() -> void:
	if initial_matrix:
		size = initial_matrix.size;
		resolution = initial_matrix.resolution;

	var matrix_size = size * resolution;
	matrix = Array3D.new();
	matrix.initialise_size(matrix_size, matrix_size, matrix_size);
	chunks = Array3D.new();
	chunks.initialise_size((size * resolution) / chunk_size, (size * resolution) / chunk_size, (size * resolution) / chunk_size);

	cubes = Array3D.new();
	cubes.initialise_size(matrix_size - 1, matrix_size - 1, matrix_size - 1);
	cubes.fill([]);

	if initial_matrix:
		matrix.values = initial_matrix.values;
	else:
		for x in range(matrix_size):
			for y in range(matrix_size):
				for z in range(matrix_size):
					if x == 0 or z == 0 or y == 0 or x == matrix_size -1 or y == matrix_size -1 or z == matrix_size -1:
						matrix.set_value(x, y, z, -1)
					else:
						matrix.set_value(x, y, z, 1)

## This reads the matrix object and based on the values it calculates three meshes
## a points mesh, to display the matrix values
## a cubes mesh, to show the boundry for each marching cube
## a triangles mesh, the final mesh within the cubes, made of triangles
func _generate() -> void:
	if not matrix:
		init_matrix()
		
	var adjacencies: Dictionary;
		
	var vertexes: Array[Dictionary] = [];
	
	var matrix_size = size * resolution;
	#var mesh_points = ImmediateMesh.new();
	#mesh_points.surface_begin(Mesh.PRIMITIVE_POINTS);
	#
	#var mesh_cubes: ImmediateMesh = ImmediateMesh.new();
	#mesh_cubes.surface_begin(Mesh.PRIMITIVE_LINES);
	
	var chunk_meshes: Array3D = Array3D.new();
	chunk_meshes.initialise_size(chunks.x_max, chunks.y_max, chunks.z_max);
	var valid_chunks: Array3D = Array3D.new();
	valid_chunks.initialise_size(chunks.x_max, chunks.y_max, chunks.z_max);
	
	chunk_meshes.fill(null);
	valid_chunks.fill(null);
	
	var first = true;
	
	for x in range(0, matrix_size):
		for y in range(0, matrix_size):
			for z in range(0, matrix_size):
				var point: Vector3 = Vector3(float(x) / float(resolution), float(y) / float(resolution), float(z) / float(resolution));
				var point_value: float = matrix.get_value(x, y, z);

				var chunk_index: Vector3 = _get_chunk_index(x, y, z);

				if not chunk_meshes.get_value(chunk_index.x, chunk_index.y, chunk_index.z):
					var chunk_mesh: ImmediateMesh = ImmediateMesh.new();
					chunk_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES);
					chunk_meshes.set_value(chunk_index.x, chunk_index.y, chunk_index.z, chunk_mesh);

				var point_color: Color = Color(
					float(point_value),
					float(point_value),
					float(point_value)
				);

				#mesh_points.surface_set_color(point_color);
				#mesh_points.surface_add_vertex(point);

				if x < matrix_size - 1 and y < matrix_size - 1 and z < matrix_size - 1:
					var cube_vertices: Array[Vector3] = _create_cube_vertices(point);
					var cube_values: Array[float] = _get_cube_values(matrix, Vector3(int(x), int(y), int(z)));

					#if _validate_cube(cube_values):
						#_add_cube_vertices(mesh_cubes, cube_vertices);

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
						
						if vertex1 and vertex2 and vertex3:
							
							valid_chunks.set_value(chunk_index.x, chunk_index.y, chunk_index.z, true);

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
							
							var uvs: Array[Vector2] = _get_uvs(vertex1, vertex2, vertex3, vector_normal);
							
							# Add to vertex array
							var index1: int;
							if not _vertexes.has(vertex1):
								_vertexes.append(vertex1)
								index1 = _vertexes.size() - 1;
							else:
								index1 = _vertexes.find(vertex1);
								
							var index2: int;
							if not _vertexes.has(vertex2):
								_vertexes.append(vertex2)
								index2 = _vertexes.size() - 1;
							else:
								index2 = _vertexes.find(vertex2);
								
							var index3: int;
							if not _vertexes.has(vertex3):
								_vertexes.append(vertex3)
								index3 = _vertexes.size() - 1;
							else:
								index3 = _vertexes.find(vertex3);
								
							# Add to triangles array
							var cube_index: int = cubes.get_index_from_coord(x, y, z);
							if (cube_index < cubes.size()):
								_triangles.append({
									'indexes': [index1, index2, index3],
									'uvs': uvs,
									'chunk_index': chunk_index,
									'cube_index': cube_index,
									'normal': vector_normal
								})
							
								# Add to cubes matrix
								var cube_value = cubes.get_value(x, y, z);
								cube_value.append(_triangles.size() - 1);
								cubes.set_value(x, y, z, cube_value);
								
							
							#
							#var vertex1String: String = str(snapped(vertex1.x, 0.01)) + str(snapped(vertex1.y, 0.01)) + str(snapped(vertex1.z, 0.01));
							#vertexes.append({
								#'vertex': vertex1,
								#'uvs': uvs[0],
								#'chunk_index': chunk_index,
								#'string': vertex1String
							#})
#
							#if not adjacencies.has(vertex1String):
								#adjacencies[vertex1String] = [vector_normal];
							#else:
								#adjacencies[vertex1String].append(vector_normal);
							#
							#var vertex2String: String = str(snapped(vertex2.x, 0.01)) + str(snapped(vertex2.y, 0.01)) + str(snapped(vertex2.z, 0.01));
							#vertexes.append({
								#'vertex': vertex2,
								#'uvs': uvs[1],
								#'chunk_index': chunk_index,
								#'string': vertex2String
							#})
#
							#if not adjacencies.has(vertex2String):
								#adjacencies[vertex2String] = [vector_normal];
							#else:
								#adjacencies[vertex2String].append(vector_normal);
		#
							#var vertex3String: String = str(snapped(vertex3.x, 0.01)) + str(snapped(vertex3.y, 0.01)) + str(snapped(vertex3.z, 0.01));
							#vertexes.append({
								#'vertex': vertex3,
								#'uvs': uvs[2],
								#'chunk_index': chunk_index,
								#'string': vertex3String
							#})
#
							#if not adjacencies.has(vertex3String):
								#adjacencies[vertex3String] = [vector_normal];
							#else:
								#adjacencies[vertex3String].append(vector_normal);

							#var chunk_mesh: ImmediateMesh = chunk_meshes.get_value(chunk_index.x, chunk_index.y, chunk_index.z);
							#chunk_mesh.surface_set_color(color);
							#chunk_mesh.surface_set_normal(vector_normal);

							#valid_chunks.set_value(chunk_index.x, chunk_index.y, chunk_index.z, true);
							#chunk_mesh.surface_set_uv(uvs[0])
							#chunk_mesh.surface_add_vertex(vertex1);
							#chunk_mesh.surface_set_uv(uvs[1])
							#chunk_mesh.surface_add_vertex(vertex2);
							#chunk_mesh.surface_set_uv(uvs[2])
							#chunk_mesh.surface_add_vertex(vertex3);
							#chunk_meshes.set_value(chunk_index.x, chunk_index.y, chunk_index.z, chunk_mesh);

	for triangle in _triangles:
		var chunk_mesh: ImmediateMesh = chunk_meshes.get_value(triangle.chunk_index.x, triangle.chunk_index.y, triangle.chunk_index.z);
		var normals: Array[Vector3] = _calculate_normals(triangle);
		
		for index in range(0, triangle.indexes.size() - 1):
			var vertex_index: int = triangle.indexes[index];
			var vertex: Vector3 = _vertexes[vertex_index];
			chunk_mesh.surface_set_normal(normals[index]);
			chunk_mesh.surface_set_uv(triangle.uvs[index])
			chunk_mesh.surface_add_vertex(vertex);
			chunk_meshes.set_value(triangle.chunk_index.x, triangle.chunk_index.y, triangle.chunk_index.z, chunk_mesh);
	#for vertex in vertexes:
		#var chunk_mesh: ImmediateMesh = chunk_meshes.get_value(vertex.chunk_index.x, vertex.chunk_index.y, vertex.chunk_index.z);
		##chunk_mesh.surface_set_normal(vector_normal);
		#
		#var normals: Array = adjacencies[vertex.string];
		#var normal_sum: Vector3 = Vector3(0.0, 0.0, 0.0);
		#for normal in normals:
			#normal_sum += normal;
#
		#chunk_mesh.surface_set_normal(normal_sum.normalized());
		#chunk_mesh.surface_set_uv(vertex.uvs)
		#chunk_mesh.surface_add_vertex(vertex.vertex);
		#chunk_meshes.set_value(vertex.chunk_index.x, vertex.chunk_index.y, vertex.chunk_index.z, chunk_mesh);

	#mesh_points.surface_end();
	#mesh_cubes.surface_end();
	
	#var material_points: StandardMaterial3D = StandardMaterial3D.new();
	#material_points.vertex_color_use_as_albedo = true;
	#material_points.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;
	#material_points.use_point_size = true;
	#material_points.point_size = 8;
	#
	#var material_cubes: StandardMaterial3D = StandardMaterial3D.new();
	#material_cubes.vertex_color_use_as_albedo = true;
	#material_cubes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED;
	
	var material_triangles: Material = test_material;
	#var material_triangles: StandardMaterial3D = StandardMaterial3D.new();
	#material_triangles.vertex_color_use_as_albedo = true;
	#material_triangles.next_pass = test_material_2
	
	#mesh_points.surface_set_material(0, material_points);
	#if points_node:
		#points_node.mesh = mesh_points;
		#points_node.visible = show_points;
		#
	#mesh_cubes.surface_set_material(0, material_cubes);
	#if cubes_node:
		#cubes_node.mesh = mesh_cubes;
		#cubes_node.visible = show_grid;

	#else:
	if triangles_node:
		triangles_node.visible = false;
		#collision_node.disabled = true;
			
	for index in chunk_meshes.size():
		var chunk_index: Vector3 = chunk_meshes.get_coord_from_index(index);
		if valid_chunks.get_value(chunk_index.x, chunk_index.y, chunk_index.z):
			var chunk_mesh: ImmediateMesh = chunk_meshes.get_value(chunk_index.x, chunk_index.y, chunk_index.z);
			chunk_mesh.surface_end();
			
			chunk_mesh.surface_set_material(0, material_triangles);

			var chunk: Chunk = chunk_scene.instantiate();
			
			chunk.visible = show_mesh;
			chunk.mesh_node.mesh = chunk_mesh;
			#chunk.shell_mesh_node.mesh = chunk_mesh;
			#chunk.shell_mesh_node.position = chunk.mesh_node.position * 0.5;

			chunk.parent = self;
			var collision_shape: ConvexPolygonShape3D = chunk_mesh.create_convex_shape();
			if collision_shape:
				chunk.low_collision.set_shape(collision_shape);
				
				chunks.set_value(chunk_index.x, chunk_index.y, chunk_index.z, chunk);
				
				chunk_container.add_child(chunk)

func _generate_chunks(affected_chunks: Array[Vector3]) -> void:
	var matrix_size = size * resolution;
	
	var adjacencies: Dictionary;

	for chunk in affected_chunks:
		var chunk_mesh: ImmediateMesh = ImmediateMesh.new();
		chunk_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES);
		var valid_chunk: bool = false;
		var vertexes: Array[Dictionary] = [];

		for x in range(chunk.x * chunk_size, (chunk.x * chunk_size) + chunk_size):
			for y in range(chunk.y * chunk_size,(chunk.y * chunk_size) + chunk_size):
				for z in range(chunk.z * chunk_size, (chunk.z * chunk_size) + chunk_size):
					var point: Vector3 = Vector3(float(x) / float(resolution), float(y) / float(resolution), float(z) / float(resolution));

					if x < matrix_size - 1 and y < matrix_size - 1 and z < matrix_size - 1:
						var cube_vertices: Array[Vector3] = _create_cube_vertices(point);
						var cube_values: Array[float] = _get_cube_values(matrix, Vector3(int(x), int(y), int(z)));

						var lookup_index : int = _get_lookup_index(cube_values);
						var triangles: Array = Constants.marching_triangles[lookup_index];

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
							if vertex1 and vertex2 and vertex3:
								valid_chunk = true;
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
								
								var uvs: Array[Vector2] = _get_uvs(vertex1, vertex2, vertex3, vector_normal);
								
								var vertex1String: String = str(snapped(vertex1.x, 0.01)) + str(snapped(vertex1.y, 0.01)) + str(snapped(vertex1.z, 0.01));
								vertexes.append({
									'vertex': vertex1,
									'uvs': uvs[0],
									'chunk_index': chunk,
									'string': vertex1String
								})

								if not adjacencies.has(vertex1String):
									adjacencies[vertex1String] = [vector_normal];
								else:
									adjacencies[vertex1String].append(vector_normal);
								
								var vertex2String: String = str(snapped(vertex2.x, 0.01)) + str(snapped(vertex2.y, 0.01)) + str(snapped(vertex2.z, 0.01));
								vertexes.append({
									'vertex': vertex2,
									'uvs': uvs[1],
									'chunk_index': chunk,
									'string': vertex2String
								})

								if not adjacencies.has(vertex2String):
									adjacencies[vertex2String] = [vector_normal];
								else:
									adjacencies[vertex2String].append(vector_normal);
			
								var vertex3String: String = str(snapped(vertex3.x, 0.01)) + str(snapped(vertex3.y, 0.01)) + str(snapped(vertex3.z, 0.01));
								vertexes.append({
									'vertex': vertex3,
									'uvs': uvs[2],
									'chunk_index': chunk,
									'string': vertex3String
								})

								if not adjacencies.has(vertex3String):
									adjacencies[vertex3String] = [vector_normal];
								else:
									adjacencies[vertex3String].append(vector_normal);
							
							#var color: Color = Color(
								#float(point.x + size) / float(size * 2), 
								#float(point.y + size) / float(size * 2), 
								#float(point.z + size) / float(size * 2)
							#);
#
							#chunk_mesh.surface_set_color(color);
							#chunk_mesh.surface_set_normal(vector_normal);
#
							#if vertex1 and vertex2 and vertex3:
								#valid_chunk = true;
								#chunk_mesh.surface_set_uv(uvs[0]);
								#chunk_mesh.surface_add_vertex(vertex1);
								#chunk_mesh.surface_set_uv(uvs[1]);
								#chunk_mesh.surface_add_vertex(vertex2);
								#chunk_mesh.surface_set_uv(uvs[2]);
								#chunk_mesh.surface_add_vertex(vertex3);
								
		for vertex in vertexes:
			#var chunk_mesh: ImmediateMesh = chunk_meshes.get_value(vertex.chunk_index.x, vertex.chunk_index.y, vertex.chunk_index.z);
			#chunk_mesh.surface_set_normal(vector_normal);

			var normals: Array = adjacencies[vertex.string];
			var normal_sum: Vector3 = Vector3(0.0, 0.0, 0.0);
			for normal in normals:
				normal_sum += normal;

			chunk_mesh.surface_set_normal(normal_sum.normalized());
			chunk_mesh.surface_set_uv(vertex.uvs)
			chunk_mesh.surface_add_vertex(vertex.vertex);
			#chunk_meshes.set_value(vertex.chunk_index.x, vertex.chunk_index.y, vertex.chunk_index.z, chunk_mesh);

		if valid_chunk:
			chunk_mesh.surface_end();
			var new_chunk: Chunk = chunk_scene.instantiate();
			var material_triangles: Material = test_material;
			chunk_mesh.surface_set_material(0, material_triangles);
			new_chunk.visible = show_mesh;
			new_chunk.mesh_node.mesh = chunk_mesh;
			new_chunk.parent = self;

			var collision_shape: ConvexPolygonShape3D = chunk_mesh.create_convex_shape();
			if collision_shape:
				new_chunk.low_collision.set_shape(collision_shape);

				chunk_container.add_child(new_chunk);
				chunks.set_value(chunk.x, chunk.y, chunk.z, new_chunk);

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
		snapped(vertex1.x + t * (vertex2.x - vertex1.x), 0.0001),
		snapped(vertex1.y + t * (vertex2.y - vertex1.y), 0.0001),
		snapped(vertex1.z + t * (vertex2.z - vertex1.z), 0.0001)
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

	var affected_chunks: Array[Vector3] = _get_affected_chunks(points);

	for chunk in affected_chunks:
		if chunks.get_value(chunk.x, chunk.y, chunk.z):
			chunks.get_value(chunk.x, chunk.y, chunk.z).queue_free()
			chunks.set_value(chunk.x, chunk.y, chunk.z, null);

	_generate_chunks(affected_chunks);
	
func add_around_point(global_point: Vector3, radius: float) -> void:
	var local_point: Vector3 = (global_point - position) * resolution;
	var points: Array[Vector3] = _get_points_in_sphere(local_point, radius);

	for point in points:
		var distance: float = point.distance_to(local_point);
		var distance_normalised: float = 0 + (1 - (distance / radius));
		matrix.set_value(point.x, point.y, point.z, distance_normalised);

	var affected_chunks: Array[Vector3] = _get_affected_chunks(points);

	for chunk in affected_chunks:
		if chunks.get_value(chunk.x, chunk.y, chunk.z):
			chunks.get_value(chunk.x, chunk.y, chunk.z).queue_free()
			chunks.set_value(chunk.x, chunk.y, chunk.z, null);

	_generate_chunks(affected_chunks);

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

func _get_chunk_index(x: int, y: int, z: int) -> Vector3:
	var x_remainder: int = x % chunk_size;
	var y_remainder: int = y % chunk_size;
	var z_remainder: int = z % chunk_size;
	
	var chunk_x: int = (x - x_remainder) / chunk_size;
	var chunk_y: int = (y - y_remainder) / chunk_size;
	var chunk_z: int = (z - z_remainder) / chunk_size;
	
	return Vector3(chunk_x, chunk_y, chunk_z);

func _get_affected_chunks(points: Array[Vector3]) -> Array[Vector3]:
	var affected_chunks: Array[Vector3] = [];
	var x_max = chunks.x_max * chunk_size;
	var y_max = chunks.y_max * chunk_size;
	var z_max = chunks.z_max * chunk_size;
	for point in points:
		for x_modifier in range(-1, 1):
			for y_modifier in range(-1, 1):
				for z_modifier in range(-1, 1):
					if point.x + x_modifier < x_max and point.x + x_modifier >= 0 and point.y + y_modifier < y_max and point.y + y_modifier >= 0 and point.z + z_modifier < z_max and point.z + z_modifier >= 0:
						var chunk: Vector3 = _get_chunk_index(point.x + x_modifier, point.y + y_modifier, point.z + z_modifier);
						if not affected_chunks.has(chunk):
							affected_chunks.append(chunk);

	return affected_chunks;

func _get_uvs(vertex_a: Vector3, vertex_b: Vector3, vertex_c: Vector3, normal: Vector3) -> Array[Vector2]:
	var uvs: Array[Vector2] = [];
	uvs.resize(3);
	
	if normal.x > normal.z and normal.x >= normal.y:
		uvs[0] = Vector2(vertex_a.z, vertex_a.y);
		uvs[1] = Vector2(vertex_b.z, vertex_b.y);
		uvs[2] = Vector2(vertex_c.z, vertex_c.y);
	elif normal.z >= normal.x and normal.z >= normal.y:
		uvs[0] = Vector2(vertex_a.z, vertex_a.y);
		uvs[1] = Vector2(vertex_b.z, vertex_b.y);
		uvs[2] = Vector2(vertex_c.z, vertex_c.y);
	elif normal.y >= normal.x and normal.y >= normal.z:
		uvs[0] = Vector2(vertex_a.x, vertex_a.z);
		uvs[1] = Vector2(vertex_b.x, vertex_b.z);
		uvs[2] = Vector2(vertex_c.x, vertex_c.z);

	return uvs;
	
func _calculate_normals(triangle: Dictionary) -> Array[Vector3]:
	var triangle_list: Array = [];
	var normals: Array[Vector3] = [];
	var cube_coords: Vector3 = cubes.get_coord_from_index(triangle.cube_index);
	for x in range(-1, 1):
		for y in range(-1, 1):
			for z in range(-1, 1):
				var cube_value: Array = cubes.get_value(cube_coords.x + x, cube_coords.y + y, cube_coords.z + z);
				triangle_list.append_array(cube_value)

	for index in triangle.indexes:
		var vertex: Vector3 = _vertexes[index];
		var normal_sum: Vector3 = Vector3(0, 0, 0);
		for item in triangle_list:
			if _triangles[item].has(vertex):
				normal_sum += item.normal
		normals.append(normal_sum.normalized());
	return normals;

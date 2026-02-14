class_name DungeonGenerator
extends Node

## Main dungeon generator using Random Room Walker algorithm
## Generates a meta grid of rooms and corridors

signal generation_complete(grid: Array)
signal generation_failed(reason: String)

## Configuration
@export var grid_width: int = 20
@export var grid_height: int = 20
@export var min_grid_elements: int = 50  # Minimum number of filled tiles
@export var max_attempts_per_placement: int = 10
@export var available_rooms: Array[MetaRoom] = []

## Runtime data
var meta_grid: Array = []  # 2D array of MetaTileType
var placed_room_positions: Array = []  # Array of Vector2i for room centers
var filled_tiles_count: int = 0

## Walker state
var walker_x: int = 0
var walker_y: int = 0

func _ready():
	pass

## Initialize the meta grid with empty cells
func _initialize_grid() -> void:
	meta_grid = []
	for y in range(grid_height):
		var row = []
		for x in range(grid_width):
			row.append(null)
		meta_grid.append(row)
	
	placed_room_positions.clear()
	filled_tiles_count = 0

## Start dungeon generation
func generate_dungeon() -> void:
	_initialize_grid()
	
	if available_rooms.is_empty():
		generation_failed.emit("No rooms available for generation")
		return
	
	# Start walker at center
	walker_x = grid_width / 2
	walker_y = grid_height / 2
	
	# Generate rooms until we reach minimum grid elements
	var iterations = 0
	var max_iterations = 1000  # Safety limit
	
	while filled_tiles_count < min_grid_elements and iterations < max_iterations:
		iterations += 1
		
		var placed = _try_place_room_at_walker()
		
		if not placed:
			# After max_attempts_per_placement failures, pick random existing room
			if not placed_room_positions.is_empty():
				var random_pos = placed_room_positions[randi() % placed_room_positions.size()]
				walker_x = random_pos.x
				walker_y = random_pos.y
			else:
				# If no rooms placed yet, try random position
				walker_x = randi() % grid_width
				walker_y = randi() % grid_height
	
	if filled_tiles_count >= min_grid_elements:
		generation_complete.emit(meta_grid)
	else:
		generation_failed.emit("Could not reach minimum grid elements after %d iterations" % iterations)

## Try to place a room at the walker's current position
## Returns true if successful
func _try_place_room_at_walker() -> bool:
	var attempts = 0
	
	while attempts < max_attempts_per_placement:
		attempts += 1
		
		# Select random room
		var room = _select_random_room()
		if room == null:
			continue
		
		# Try to place at walker position (with some offset variation)
		var offset_x = randi_range(-2, 2)
		var offset_y = randi_range(-2, 2)
		var try_x = walker_x + offset_x
		var try_y = walker_y + offset_y
		
		# Clamp to grid bounds
		try_x = clampi(try_x, 0, grid_width - room.width)
		try_y = clampi(try_y, 0, grid_height - room.height)
		
		if room.can_place_at(meta_grid, grid_width, grid_height, try_x, try_y):
			# Place the room
			if room.place_on_grid(meta_grid, try_x, try_y):
				# Update filled tiles count
				for dy in range(room.height):
					for dx in range(room.width):
						if room.get_tile(dx, dy) != null:
							filled_tiles_count += 1
				
				# Record room position (center)
				var center_x = try_x + room.width / 2
				var center_y = try_y + room.height / 2
				placed_room_positions.append(Vector2i(center_x, center_y))
				
				# Move walker to new room
				walker_x = center_x
				walker_y = center_y
				
				return true
	
	# Failed to place after max attempts
	# Move walker randomly
	var dir = randi() % 4
	match dir:
		0:  # North
			walker_y = max(0, walker_y - 1)
		1:  # East
			walker_x = min(grid_width - 1, walker_x + 1)
		2:  # South
			walker_y = min(grid_height - 1, walker_y + 1)
		3:  # West
			walker_x = max(0, walker_x - 1)
	
	return false

## Select a random room based on weights
func _select_random_room() -> MetaRoom:
	if available_rooms.is_empty():
		return null
	
	# Calculate total weight
	var total_weight = 0.0
	for room in available_rooms:
		total_weight += room.weight
	
	# Random selection
	var random_value = randf() * total_weight
	var current_weight = 0.0
	
	for room in available_rooms:
		current_weight += room.weight
		if random_value <= current_weight:
			return room
	
	# Fallback
	return available_rooms[0]

## Get the generated grid
func get_grid() -> Array:
	return meta_grid

## Get statistics about the generation
func get_stats() -> Dictionary:
	return {
		"filled_tiles": filled_tiles_count,
		"rooms_placed": placed_room_positions.size(),
		"grid_size": Vector2i(grid_width, grid_height)
	}

## Debug: Print grid to console
func print_grid() -> void:
	print("\n=== Dungeon Grid ===")
	for y in range(grid_height):
		var line = ""
		for x in range(grid_width):
			var cell = meta_grid[y][x]
			if cell == null:
				line += " ."
			else:
				# Use first character of type name
				var char = cell.type_name.substr(0, 1).to_upper()
				line += " " + char
		print(line)
	print("===================\n")

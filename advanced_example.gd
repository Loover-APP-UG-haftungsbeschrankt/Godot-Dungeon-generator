extends Node

## Advanced example showing MetaPrefab usage with placement conditions
## Demonstrates door placement between corridors

@onready var generator: DungeonGenerator = $DungeonGenerator

var wall_type: MetaTileType
var corridor_type: MetaTileType
var room_type: MetaTileType
var door_type: MetaTileType

func _ready():
	_create_tile_types()
	var rooms = _create_rooms()
	
	# Configure generator
	generator.available_rooms = rooms
	generator.grid_width = 40
	generator.grid_height = 40
	generator.min_grid_elements = 150
	generator.max_attempts_per_placement = 10
	
	# Connect signals
	generator.generation_complete.connect(_on_generation_complete)
	generator.generation_failed.connect(_on_generation_failed)
	
	print("=== Advanced Dungeon Generator Example ===")
	print("Starting generation with prefab conditions...")
	generator.generate_dungeon()

func _create_tile_types():
	wall_type = MetaTileType.new("wall", "Solid wall")
	corridor_type = MetaTileType.new("corridor", "Corridor/hallway")
	room_type = MetaTileType.new("room", "Room floor")
	door_type = MetaTileType.new("door", "Door connecting areas")

func _create_rooms() -> Array[MetaRoom]:
	var rooms: Array[MetaRoom] = []
	
	# Various room sizes with different weights
	rooms.append(_create_rectangular_room(3, 3, "TinyRoom", 4.0))
	rooms.append(_create_rectangular_room(5, 5, "SmallRoom", 2.0))
	rooms.append(_create_rectangular_room(7, 7, "MediumRoom", 1.0))
	rooms.append(_create_rectangular_room(9, 9, "LargeRoom", 0.5))
	
	# Corridors
	rooms.append(_create_corridor(3, 1, "ShortCorridorH", 5.0))
	rooms.append(_create_corridor(5, 1, "MediumCorridorH", 3.0))
	rooms.append(_create_corridor(1, 3, "ShortCorridorV", 5.0))
	rooms.append(_create_corridor(1, 5, "MediumCorridorV", 3.0))
	
	# Special shapes
	rooms.append(_create_t_junction())
	rooms.append(_create_cross_junction())
	rooms.append(_create_l_corridor())
	
	return rooms

func _create_rectangular_room(width: int, height: int, name: String, weight: float) -> MetaRoom:
	var room = MetaRoom.new(name, width, height)
	room.weight = weight
	
	for y in range(height):
		for x in range(width):
			# Walls on edges, room floor inside
			if x == 0 or x == width - 1 or y == 0 or y == height - 1:
				room.set_tile(x, y, wall_type)
			else:
				room.set_tile(x, y, room_type)
	
	return room

func _create_corridor(width: int, height: int, name: String, weight: float) -> MetaRoom:
	var corridor = MetaRoom.new(name, width, height)
	corridor.weight = weight
	
	for y in range(height):
		for x in range(width):
			corridor.set_tile(x, y, corridor_type)
	
	return corridor

func _create_t_junction() -> MetaRoom:
	# T-shaped corridor junction
	var t_room = MetaRoom.new("TJunction", 3, 3)
	t_room.weight = 1.0
	
	# Pattern:
	#  C
	# CCC
	#  C
	t_room.set_tile(1, 0, corridor_type)
	t_room.set_tile(0, 1, corridor_type)
	t_room.set_tile(1, 1, corridor_type)
	t_room.set_tile(2, 1, corridor_type)
	t_room.set_tile(1, 2, corridor_type)
	
	return t_room

func _create_cross_junction() -> MetaRoom:
	# Cross-shaped corridor junction
	var cross = MetaRoom.new("CrossJunction", 3, 3)
	cross.weight = 0.8
	
	# Pattern:
	#  C
	# CCC
	#  C
	cross.set_tile(1, 0, corridor_type)
	cross.set_tile(0, 1, corridor_type)
	cross.set_tile(1, 1, corridor_type)
	cross.set_tile(2, 1, corridor_type)
	cross.set_tile(1, 2, corridor_type)
	
	return cross

func _create_l_corridor() -> MetaRoom:
	# L-shaped corridor
	var l_corridor = MetaRoom.new("LCorridor", 3, 3)
	l_corridor.weight = 2.0
	
	# Pattern:
	# CC
	#  C
	#  C
	l_corridor.set_tile(0, 0, corridor_type)
	l_corridor.set_tile(1, 0, corridor_type)
	l_corridor.set_tile(1, 1, corridor_type)
	l_corridor.set_tile(1, 2, corridor_type)
	
	return l_corridor

func _on_generation_complete(grid: Array):
	print("\n✓ Generation complete!")
	
	var stats = generator.get_stats()
	print("\n=== Generation Statistics ===")
	print("Grid Size: %dx%d" % [stats.grid_size.x, stats.grid_size.y])
	print("Filled Tiles: %d" % stats.filled_tiles)
	print("Rooms Placed: %d" % stats.rooms_placed)
	print("Fill Percentage: %.1f%%" % (stats.filled_tiles * 100.0 / (stats.grid_size.x * stats.grid_size.y)))
	
	# Print the grid
	generator.print_grid()
	
	# Example: Try to place a door prefab in the generated grid
	_try_place_door_prefabs(grid)

func _on_generation_failed(reason: String):
	print("\n✗ Generation failed: ", reason)

func _try_place_door_prefabs(grid: Array):
	print("\n=== Attempting Door Placement ===")
	
	# Create a door prefab that needs corridors above and below
	var door_prefab = MetaPrefab.new("DoorNS", 1, 1)
	door_prefab.tile_type = door_type
	door_prefab.set_neighbor_condition(MetaPrefab.Direction.NORTH, corridor_type)
	door_prefab.set_neighbor_condition(MetaPrefab.Direction.SOUTH, corridor_type)
	door_prefab.allow_rotation = true
	
	var doors_placed = 0
	var positions_checked = 0
	
	# Scan grid for valid door positions
	for y in range(1, generator.grid_height - 1):
		for x in range(1, generator.grid_width - 1):
			positions_checked += 1
			
			# Try all rotations
			for rotation in [0, 90, 180, 270]:
				if door_prefab.can_place_at(grid, generator.grid_width, generator.grid_height, x, y, rotation):
					doors_placed += 1
					print("  Valid door position found at (%d, %d) with rotation %d°" % [x, y, rotation])
					
					# Only print first 5 to avoid spam
					if doors_placed >= 5:
						break
			
			if doors_placed >= 5:
				break
		
		if doors_placed >= 5:
			break
	
	print("\nDoor placement scan complete:")
	print("  Positions checked: %d" % positions_checked)
	print("  Valid placements found: %d+ (stopped at 5)" % doors_placed)
	print("\nThis demonstrates how MetaPrefab conditions work!")
	print("Doors can only be placed where corridor tiles are adjacent.")

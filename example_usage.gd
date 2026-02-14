extends Node

## Example usage of the Dungeon Generator
## This demonstrates how to set up and use the generator

@onready var generator: DungeonGenerator = $DungeonGenerator

func _ready():
	# Create tile types
	var wall_type = MetaTileType.new("wall", "A solid wall")
	var corridor_type = MetaTileType.new("corridor", "A corridor/hallway")
	var room_type = MetaTileType.new("room", "A room floor")
	var door_type = MetaTileType.new("door", "A door")
	
	# Create example rooms
	var rooms = _create_example_rooms(wall_type, corridor_type, room_type)
	
	# Configure generator
	generator.available_rooms = rooms
	generator.grid_width = 30
	generator.grid_height = 30
	generator.min_grid_elements = 80
	generator.max_attempts_per_placement = 10
	
	# Connect signals
	generator.generation_complete.connect(_on_generation_complete)
	generator.generation_failed.connect(_on_generation_failed)
	
	print("Starting dungeon generation...")
	generator.generate_dungeon()

func _create_example_rooms(wall_type: MetaTileType, corridor_type: MetaTileType, room_type: MetaTileType) -> Array[MetaRoom]:
	var rooms: Array[MetaRoom] = []
	
	# Small room (3x3)
	var small_room = MetaRoom.new("SmallRoom", 3, 3)
	small_room.weight = 2.0
	for y in range(3):
		for x in range(3):
			if x == 0 or x == 2 or y == 0 or y == 2:
				small_room.set_tile(x, y, wall_type)
			else:
				small_room.set_tile(x, y, room_type)
	rooms.append(small_room)
	
	# Corridor horizontal (3x1)
	var corridor_h = MetaRoom.new("CorridorH", 3, 1)
	corridor_h.weight = 3.0
	for x in range(3):
		corridor_h.set_tile(x, 0, corridor_type)
	rooms.append(corridor_h)
	
	# Corridor vertical (1x3)
	var corridor_v = MetaRoom.new("CorridorV", 1, 3)
	corridor_v.weight = 3.0
	for y in range(3):
		corridor_v.set_tile(0, y, corridor_type)
	rooms.append(corridor_v)
	
	# Medium room (5x5)
	var medium_room = MetaRoom.new("MediumRoom", 5, 5)
	medium_room.weight = 1.0
	for y in range(5):
		for x in range(5):
			if x == 0 or x == 4 or y == 0 or y == 4:
				medium_room.set_tile(x, y, wall_type)
			else:
				medium_room.set_tile(x, y, room_type)
	rooms.append(medium_room)
	
	# L-shaped corridor
	var l_corridor = MetaRoom.new("LCorridor", 3, 3)
	l_corridor.weight = 1.5
	l_corridor.set_tile(0, 0, corridor_type)
	l_corridor.set_tile(1, 0, corridor_type)
	l_corridor.set_tile(0, 1, corridor_type)
	l_corridor.set_tile(0, 2, corridor_type)
	rooms.append(l_corridor)
	
	return rooms

func _on_generation_complete(grid: Array):
	print("Generation complete!")
	var stats = generator.get_stats()
	print("Stats: ", stats)
	generator.print_grid()

func _on_generation_failed(reason: String):
	print("Generation failed: ", reason)

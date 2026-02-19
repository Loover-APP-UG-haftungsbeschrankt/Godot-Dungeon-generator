extends Node

## Test script to validate the connector room system
## This script creates test rooms and validates atomic placement logic

func _ready():
	print("=== Testing Connector Room System ===\n")
	
	# Test 1: Create a connector room
	test_connector_room_creation()
	
	# Test 2: Validate rotation preserves required flag
	test_rotation_preserves_required()
	
	# Test 3: Test atomic placement simulation
	test_atomic_placement_logic()
	
	print("\n=== All Tests Completed ===")
	get_tree().quit()


func test_connector_room_creation():
	print("Test 1: Connector Room Creation")
	print("--------------------------------")
	
	# Create a simple T-room with required connections
	var t_room = MetaRoom.new()
	t_room.width = 3
	t_room.height = 3
	t_room.room_name = "T_Connector"
	t_room.cells.clear()
	
	# Fill with floor cells
	for i in range(9):
		var cell = MetaCell.new()
		cell.cell_type = MetaCell.CellType.FLOOR
		t_room.cells.append(cell)
	
	# Top connection (required)
	var top_cell = t_room.get_cell(1, 0)
	top_cell.connection_up = true
	top_cell.connection_required = true
	
	# Left connection (required)
	var left_cell = t_room.get_cell(0, 1)
	left_cell.connection_left = true
	left_cell.connection_required = true
	
	# Right connection (required)
	var right_cell = t_room.get_cell(2, 1)
	right_cell.connection_right = true
	right_cell.connection_required = true
	
	print("Created T-room with 3 required connections:")
	print("  - UP at (1,0)")
	print("  - LEFT at (0,1)")
	print("  - RIGHT at (2,1)")
	
	var conn_points = t_room.get_connection_points()
	var required_conn_points = t_room.get_required_connection_points()
	
	print("\nTotal connections: %d" % conn_points.size())
	print("Required connections: %d" % required_conn_points.size())
	print("Is connector piece: %s" % t_room.is_connector_piece())
	
	var pass_test = (conn_points.size() == 3 and 
	                 required_conn_points.size() == 3 and 
	                 t_room.is_connector_piece())
	print("\nTest Result: %s\n" % ("PASS" if pass_test else "FAIL"))


func test_rotation_preserves_required():
	print("Test 2: Rotation Preserves Required Flag")
	print("-----------------------------------------")
	
	# Create a simple room with one required connection
	var room = MetaRoom.new()
	room.width = 3
	room.height = 3
	room.room_name = "TestRoom"
	room.cells.clear()
	
	for i in range(9):
		var cell = MetaCell.new()
		cell.cell_type = MetaCell.CellType.FLOOR
		room.cells.append(cell)
	
	# Top connection (required)
	var top_cell = room.get_cell(1, 0)
	top_cell.connection_up = true
	top_cell.connection_required = true
	
	# Right connection (NOT required)
	var right_cell = room.get_cell(2, 1)
	right_cell.connection_right = true
	right_cell.connection_required = false
	
	print("Original room:")
	print("  UP at (1,0): required=true")
	print("  RIGHT at (2,1): required=false")
	
	# Rotate 90 degrees
	var rotated = RoomRotator.rotate_room(room, RoomRotator.Rotation.DEG_90)
	
	print("\nAfter 90° rotation:")
	var rotated_conns = rotated.get_connection_points()
	var rotated_required = rotated.get_required_connection_points()
	
	print("Total connections: %d" % rotated_conns.size())
	print("Required connections: %d" % rotated_required.size())
	
	for conn in rotated_conns:
		var cell = rotated.get_cell(conn.x, conn.y)
		var dir_name = ["UP", "RIGHT", "BOTTOM", "LEFT"][conn.direction]
		print("  %s at (%d,%d): required=%s" % [dir_name, conn.x, conn.y, conn.is_required])
	
	var pass_test = (rotated_conns.size() == 2 and 
	                 rotated_required.size() == 1 and
	                 rotated.is_connector_piece())
	print("\nTest Result: %s\n" % ("PASS" if pass_test else "FAIL"))


func test_atomic_placement_logic():
	print("Test 3: Atomic Placement Logic Simulation")
	print("------------------------------------------")
	
	# Create a generator instance
	var generator = DungeonGenerator.new()
	
	# Create simple room templates
	var straight_corridor = _create_straight_corridor()
	var t_connector = _create_t_connector()
	
	generator.room_templates = [straight_corridor, t_connector]
	generator.generation_seed = 12345
	generator.num_walkers = 1
	generator.max_rooms_per_walker = 10
	generator.target_meta_cell_count = 50
	
	print("Created generator with:")
	print("  - 1 straight corridor (no required connections)")
	print("  - 1 T-connector (2 required connections)")
	
	# Run generation
	print("\nRunning generation...")
	var success = generator.generate()
	
	print("Generation result: %s" % ("SUCCESS" if success else "FAILED"))
	print("Rooms placed: %d" % generator.placed_rooms.size())
	print("Cells placed: %d" % generator._count_total_cells())
	
	# Check if any connector rooms were placed
	var connector_count = 0
	for placed in generator.placed_rooms:
		if placed.room.is_connector_piece():
			connector_count += 1
			print("  Found connector at position %s" % placed.position)
	
	print("\nConnector rooms placed: %d" % connector_count)
	print("\nTest Result: %s\n" % ("PASS" if success else "FAIL"))
	
	generator.free()


func _create_straight_corridor() -> MetaRoom:
	var room = MetaRoom.new()
	room.width = 3
	room.height = 1
	room.room_name = "Straight_Corridor"
	room.cells.clear()
	
	for i in range(3):
		var cell = MetaCell.new()
		cell.cell_type = MetaCell.CellType.FLOOR
		room.cells.append(cell)
	
	# Left connection (not required)
	room.get_cell(0, 0).connection_left = true
	room.get_cell(0, 0).connection_required = false
	
	# Right connection (not required)
	room.get_cell(2, 0).connection_right = true
	room.get_cell(2, 0).connection_required = false
	
	return room


func _create_t_connector() -> MetaRoom:
	var room = MetaRoom.new()
	room.width = 3
	room.height = 3
	room.room_name = "T_Connector"
	room.cells.clear()
	
	# Create a T shape
	for y in range(3):
		for x in range(3):
			var cell = MetaCell.new()
			# Only middle column and middle row are walkable
			if x == 1 or y == 1:
				cell.cell_type = MetaCell.CellType.FLOOR
			else:
				cell.cell_type = MetaCell.CellType.BLOCKED
			room.cells.append(cell)
	
	# Top connection (required)
	room.get_cell(1, 0).connection_up = true
	room.get_cell(1, 0).connection_required = true
	
	# Bottom connection (required)
	room.get_cell(1, 2).connection_bottom = true
	room.get_cell(1, 2).connection_required = true
	
	# Left connection (not required - allows more flexibility)
	room.get_cell(0, 1).connection_left = true
	room.get_cell(0, 1).connection_required = false
	
	# Right connection (not required)
	room.get_cell(2, 1).connection_right = true
	room.get_cell(2, 1).connection_required = false
	
	return room

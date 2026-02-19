extends Node

## Debug test to understand why T-rooms aren't placing
## This creates a scenario where a T-room SHOULD be placeable

func _ready() -> void:
	print("\n" + "=".repeat(60))
	print("DEBUG TEST: T-Room Placement")
	print("=".repeat(60) + "\n")
	
	test_t_room_placement_scenario()
	
	print("\n" + "=".repeat(60))
	print("DEBUG TEST COMPLETE")
	print("=".repeat(60) + "\n")


func test_t_room_placement_scenario() -> void:
	print("Creating scenario where T-room should be placeable...\n")
	
	# Create a dungeon generator
	var generator = DungeonGenerator.new()
	
	# Create a normal room template (3x3 with connections on all sides)
	var normal_room = MetaRoom.new()
	normal_room.width = 3
	normal_room.height = 3
	normal_room._initialize_cells()
	normal_room.room_name = "Normal Room"
	
	# Add connections on all sides
	var top_cell = normal_room.get_cell(1, 0)
	top_cell.cell_type = MetaCell.CellType.BLOCKED
	top_cell.connection_up = true
	
	var right_cell = normal_room.get_cell(2, 1)
	right_cell.cell_type = MetaCell.CellType.BLOCKED
	right_cell.connection_right = true
	
	var bottom_cell = normal_room.get_cell(1, 2)
	bottom_cell.cell_type = MetaCell.CellType.BLOCKED
	bottom_cell.connection_bottom = true
	
	var left_cell = normal_room.get_cell(0, 1)
	left_cell.cell_type = MetaCell.CellType.BLOCKED
	left_cell.connection_left = true
	
	# Create a T-room template (simplified version for testing)
	var t_room = MetaRoom.new()
	t_room.width = 5
	t_room.height = 4
	t_room._initialize_cells()
	t_room.room_name = "T-Room"
	
	# Set all cells to blocked first
	for y in range(t_room.height):
		for x in range(t_room.width):
			var cell = t_room.get_cell(x, y)
			cell.cell_type = MetaCell.CellType.BLOCKED
	
	# Create the T shape with floor cells
	t_room.get_cell(1, 1).cell_type = MetaCell.CellType.FLOOR
	t_room.get_cell(2, 1).cell_type = MetaCell.CellType.FLOOR
	t_room.get_cell(3, 1).cell_type = MetaCell.CellType.FLOOR
	t_room.get_cell(2, 2).cell_type = MetaCell.CellType.FLOOR
	
	# Add required connections
	var t_left = t_room.get_cell(0, 1)
	t_left.connection_left = true
	t_left.connection_required = true
	
	var t_right = t_room.get_cell(4, 1)
	t_right.connection_right = true
	t_right.connection_required = true
	
	var t_bottom = t_room.get_cell(2, 3)
	t_bottom.connection_bottom = true
	t_bottom.connection_required = true
	
	# Verify T-room is identified as connection room
	print("1. T-room is_connection_room(): ", t_room.is_connection_room())
	assert(t_room.is_connection_room(), "T-room should be identified as connection room")
	
	# Check required connection points
	var required_conns = t_room.get_required_connection_points()
	print("2. T-room required connections: ", required_conns.size())
	for conn in required_conns:
		print("   - (", conn.x, ", ", conn.y, ") direction ", conn.direction)
	assert(required_conns.size() == 3, "T-room should have 3 required connections")
	
	# Now place three normal rooms to create a T-junction
	print("\n3. Placing three normal rooms to create T-junction...")
	
	# Room A at LEFT position (-3, -1)
	var room_a = normal_room.clone()
	room_a.room_name = "Room A (LEFT)"
	var placement_a = generator.PlacedRoom.new(room_a, Vector2i(-3, -1), 0, normal_room)
	generator.placed_rooms.append(placement_a)
	for y in range(placement_a.room.height):
		for x in range(placement_a.room.width):
			var world_pos = placement_a.get_cell_world_pos(x, y)
			generator.occupied_cells[world_pos] = placement_a
	print("   - Room A placed at (-3, -1)")
	
	# Room B at RIGHT position (5, -1)
	var room_b = normal_room.clone()
	room_b.room_name = "Room B (RIGHT)"
	var placement_b = generator.PlacedRoom.new(room_b, Vector2i(5, -1), 0, normal_room)
	generator.placed_rooms.append(placement_b)
	for y in range(placement_b.room.height):
		for x in range(placement_b.room.width):
			var world_pos = placement_b.get_cell_world_pos(x, y)
			generator.occupied_cells[world_pos] = placement_b
	print("   - Room B placed at (5, -1)")
	
	# Room C at BOTTOM position (0, 3)
	var room_c = normal_room.clone()
	room_c.room_name = "Room C (BOTTOM)"
	var placement_c = generator.PlacedRoom.new(room_c, Vector2i(0, 3), 0, normal_room)
	generator.placed_rooms.append(placement_c)
	for y in range(placement_c.room.height):
		for x in range(placement_c.room.width):
			var world_pos = placement_c.get_cell_world_pos(x, y)
			generator.occupied_cells[world_pos] = placement_c
	print("   - Room C placed at (0, 3)")
	
	print("\n4. Testing T-room placement at origin (0, 0)...")
	
	# T-room at (0, 0) should have:
	# - LEFT connection at (0, 1) → adjacent (-1, 1) should be part of Room A
	# - RIGHT connection at (4, 1) → adjacent (5, 1) should be part of Room B
	# - BOTTOM connection at (2, 3) → adjacent (2, 4) should be part of Room C
	
	# Check manually what's at each position
	print("\n5. Checking adjacent positions for T-room at (0, 0):")
	
	var t_pos = Vector2i(0, 0)
	for conn in required_conns:
		var conn_world = t_pos + Vector2i(conn.x, conn.y)
		var adjacent = conn_world + generator._get_direction_offset(conn.direction)
		var has_room = generator.occupied_cells.has(adjacent)
		print("   Connection at (", conn.x, ", ", conn.y, ") dir ", conn.direction)
		print("     World pos: ", conn_world, " → Adjacent: ", adjacent)
		if has_room:
			var room_there = generator.occupied_cells[adjacent]
			print("     Room: ", room_there.room.room_name, " is_connection=", room_there.room.is_connection_room())
		else:
			print("     Room: NONE (empty)")
	
	# Now test validation
	print("\n6. Testing validation WITHOUT connecting_via:")
	var can_place_no_conn = generator._can_fulfill_required_connections(t_room, t_pos, null)
	print("   Result: ", can_place_no_conn)
	
	print("\n7. Testing validation WITH connecting_via (LEFT connection):")
	var left_conn = MetaRoom.ConnectionPoint.new(0, 1, MetaCell.Direction.LEFT)
	var can_place_with_left = generator._can_fulfill_required_connections(t_room, t_pos, left_conn)
	print("   Result: ", can_place_with_left)
	print("   (Should be TRUE if RIGHT and BOTTOM have normal rooms)")
	
	print("\n8. Testing validation WITH connecting_via (RIGHT connection):")
	var right_conn = MetaRoom.ConnectionPoint.new(4, 1, MetaCell.Direction.RIGHT)
	var can_place_with_right = generator._can_fulfill_required_connections(t_room, t_pos, right_conn)
	print("   Result: ", can_place_with_right)
	print("   (Should be TRUE if LEFT and BOTTOM have normal rooms)")
	
	print("\n9. Testing validation WITH connecting_via (BOTTOM connection):")
	var bottom_conn = MetaRoom.ConnectionPoint.new(2, 3, MetaCell.Direction.BOTTOM)
	var can_place_with_bottom = generator._can_fulfill_required_connections(t_room, t_pos, bottom_conn)
	print("   Result: ", can_place_with_bottom)
	print("   (Should be TRUE if LEFT and RIGHT have normal rooms)")


func assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("ASSERTION FAILED: " + message)
		print("✗ FAILED: ", message)
	else:
		print("✓ PASSED: ", message)

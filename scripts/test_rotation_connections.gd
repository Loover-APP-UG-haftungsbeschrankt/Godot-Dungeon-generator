extends Node

## Test script to verify connections are detected after rotation

func _ready() -> void:
	print("\n" + "=".repeat(70))
	print("TEST: Connection Detection After Rotation")
	print("=".repeat(70) + "\n")
	
	test_l_room_rotation()
	test_t_room_rotation()
	
	print("\n" + "=".repeat(70))
	print("ALL TESTS COMPLETE")
	print("=".repeat(70) + "\n")


func test_l_room_rotation() -> void:
	print("Test 1: L-Room connections after rotation")
	print("-".repeat(60))
	
	# Create L-room template
	var l_room = MetaRoom.new()
	l_room.width = 4
	l_room.height = 4
	l_room._initialize_cells()
	l_room.room_name = "L-Corridor"
	
	# Add required connections at edge positions
	# RIGHT connection at (3, 1)
	var right_cell = l_room.get_cell(3, 1)
	right_cell.cell_type = MetaCell.CellType.BLOCKED
	right_cell.connection_right = true
	right_cell.connection_required = true
	
	# BOTTOM connection at (1, 3)
	var bottom_cell = l_room.get_cell(1, 3)
	bottom_cell.cell_type = MetaCell.CellType.BLOCKED
	bottom_cell.connection_bottom = true
	bottom_cell.connection_required = true
	
	# Test original room
	print("\n  Original L-room (0°):")
	var conns_0 = l_room.get_connection_points()
	var req_conns_0 = l_room.get_required_connection_points()
	print("    Total connections: ", conns_0.size())
	print("    Required connections: ", req_conns_0.size())
	assert(conns_0.size() == 2, "Should have 2 connections")
	assert(req_conns_0.size() == 2, "Should have 2 required connections")
	
	# Test 90° rotation
	print("\n  L-room after 90° rotation:")
	var l_room_90 = RoomRotator.rotate_room(l_room, RoomRotator.Rotation.DEG_90)
	var conns_90 = l_room_90.get_connection_points()
	var req_conns_90 = l_room_90.get_required_connection_points()
	print("    Total connections: ", conns_90.size())
	print("    Required connections: ", req_conns_90.size())
	for conn in req_conns_90:
		print("      - At (", conn.x, ", ", conn.y, ") direction ", conn.direction)
	assert(conns_90.size() == 2, "Should have 2 connections after 90° rotation")
	assert(req_conns_90.size() == 2, "Should have 2 required connections after 90° rotation")
	
	# Test 180° rotation
	print("\n  L-room after 180° rotation:")
	var l_room_180 = RoomRotator.rotate_room(l_room, RoomRotator.Rotation.DEG_180)
	var conns_180 = l_room_180.get_connection_points()
	var req_conns_180 = l_room_180.get_required_connection_points()
	print("    Total connections: ", conns_180.size())
	print("    Required connections: ", req_conns_180.size())
	assert(conns_180.size() == 2, "Should have 2 connections after 180° rotation")
	assert(req_conns_180.size() == 2, "Should have 2 required connections after 180° rotation")
	
	# Test 270° rotation
	print("\n  L-room after 270° rotation:")
	var l_room_270 = RoomRotator.rotate_room(l_room, RoomRotator.Rotation.DEG_270)
	var conns_270 = l_room_270.get_connection_points()
	var req_conns_270 = l_room_270.get_required_connection_points()
	print("    Total connections: ", conns_270.size())
	print("    Required connections: ", req_conns_270.size())
	assert(conns_270.size() == 2, "Should have 2 connections after 270° rotation")
	assert(req_conns_270.size() == 2, "Should have 2 required connections after 270° rotation")
	
	print("\n  ✓ L-room connections detected in ALL rotations!")
	print()


func test_t_room_rotation() -> void:
	print("Test 2: T-Room connections after rotation")
	print("-".repeat(60))
	
	# Create T-room template (simplified 5x4)
	var t_room = MetaRoom.new()
	t_room.width = 5
	t_room.height = 4
	t_room._initialize_cells()
	t_room.room_name = "T-Room"
	
	# Add required connections
	# LEFT connection at (0, 1)
	var left_cell = t_room.get_cell(0, 1)
	left_cell.cell_type = MetaCell.CellType.BLOCKED
	left_cell.connection_left = true
	left_cell.connection_required = true
	
	# RIGHT connection at (4, 1)
	var right_cell = t_room.get_cell(4, 1)
	right_cell.cell_type = MetaCell.CellType.BLOCKED
	right_cell.connection_right = true
	right_cell.connection_required = true
	
	# BOTTOM connection at (2, 3)
	var bottom_cell = t_room.get_cell(2, 3)
	bottom_cell.cell_type = MetaCell.CellType.BLOCKED
	bottom_cell.connection_bottom = true
	bottom_cell.connection_required = true
	
	# Test original room
	print("\n  Original T-room (0°):")
	var conns_0 = t_room.get_connection_points()
	var req_conns_0 = t_room.get_required_connection_points()
	print("    Total connections: ", conns_0.size())
	print("    Required connections: ", req_conns_0.size())
	assert(conns_0.size() == 3, "Should have 3 connections")
	assert(req_conns_0.size() == 3, "Should have 3 required connections")
	
	# Test 90° rotation
	print("\n  T-room after 90° rotation:")
	var t_room_90 = RoomRotator.rotate_room(t_room, RoomRotator.Rotation.DEG_90)
	var conns_90 = t_room_90.get_connection_points()
	var req_conns_90 = t_room_90.get_required_connection_points()
	print("    Total connections: ", conns_90.size())
	print("    Required connections: ", req_conns_90.size())
	for conn in req_conns_90:
		print("      - At (", conn.x, ", ", conn.y, ") direction ", conn.direction)
	assert(conns_90.size() == 3, "Should have 3 connections after 90° rotation")
	assert(req_conns_90.size() == 3, "Should have 3 required connections after 90° rotation")
	
	# Test 180° rotation
	print("\n  T-room after 180° rotation:")
	var t_room_180 = RoomRotator.rotate_room(t_room, RoomRotator.Rotation.DEG_180)
	var conns_180 = t_room_180.get_connection_points()
	var req_conns_180 = t_room_180.get_required_connection_points()
	print("    Total connections: ", conns_180.size())
	print("    Required connections: ", req_conns_180.size())
	assert(conns_180.size() == 3, "Should have 3 connections after 180° rotation")
	assert(req_conns_180.size() == 3, "Should have 3 required connections after 180° rotation")
	
	# Test 270° rotation
	print("\n  T-room after 270° rotation:")
	var t_room_270 = RoomRotator.rotate_room(t_room, RoomRotator.Rotation.DEG_270)
	var conns_270 = t_room_270.get_connection_points()
	var req_conns_270 = t_room_270.get_required_connection_points()
	print("    Total connections: ", conns_270.size())
	print("    Required connections: ", req_conns_270.size())
	assert(conns_270.size() == 3, "Should have 3 connections after 270° rotation")
	assert(req_conns_270.size() == 3, "Should have 3 required connections after 270° rotation")
	
	print("\n  ✓ T-room connections detected in ALL rotations!")
	print()


func assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("ASSERTION FAILED: " + message)
		print("  ✗ FAILED: ", message)
	else:
		print("  ✓ PASSED: ", message)

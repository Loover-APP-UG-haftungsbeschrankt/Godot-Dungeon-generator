extends Node

## Comprehensive test script to validate connection room logic
## Run this from Godot command line with: godot --headless --script test_connection_logic.gd

func _ready():
	print("=== TESTING CONNECTION ROOM LOGIC ===\n")
	
	# Load room templates
	var t_room = load("res://resources/rooms/t_room.tres") as MetaRoom
	var l_room = load("res://resources/rooms/l_corridor.tres") as MetaRoom
	
	if t_room == null or l_room == null:
		print("ERROR: Failed to load room templates!")
		get_tree().quit(1)
		return
	
	print("✓ Room templates loaded successfully\n")
	
	# Test 1: Verify is_connection_room()
	print("TEST 1: is_connection_room()")
	print("-" * 50)
	var t_is_conn = t_room.is_connection_room()
	var l_is_conn = l_room.is_connection_room()
	print("  T-Room is_connection_room: ", t_is_conn)
	print("  L-Corridor is_connection_room: ", l_is_conn)
	if t_is_conn and l_is_conn:
		print("  ✓ PASS: Both rooms correctly identified as connection rooms\n")
	else:
		print("  ✗ FAIL: Rooms should be identified as connection rooms\n")
		get_tree().quit(1)
		return
	
	# Test 2: Verify get_connection_points()
	print("TEST 2: get_connection_points()")
	print("-" * 50)
	var t_connections = t_room.get_connection_points()
	var l_connections = l_room.get_connection_points()
	print("  T-Room connections: ", t_connections.size())
	for conn in t_connections:
		print("    - Cell (", conn.x, ", ", conn.y, ") direction: ", conn.direction)
	print("  L-Corridor connections: ", l_connections.size())
	for conn in l_connections:
		print("    - Cell (", conn.x, ", ", conn.y, ") direction: ", conn.direction)
	
	if t_connections.size() == 3 and l_connections.size() == 2:
		print("  ✓ PASS: Correct number of connections found\n")
	else:
		print("  ✗ FAIL: Expected 3 T-Room connections and 2 L-Corridor connections\n")
		get_tree().quit(1)
		return
	
	# Test 3: Verify get_required_connection_points()
	print("TEST 3: get_required_connection_points()")
	print("-" * 50)
	var t_required = t_room.get_required_connection_points()
	var l_required = l_room.get_required_connection_points()
	print("  T-Room required connections: ", t_required.size())
	for conn in t_required:
		print("    - Cell (", conn.x, ", ", conn.y, ") direction: ", conn.direction)
	print("  L-Corridor required connections: ", l_required.size())
	for conn in l_required:
		print("    - Cell (", conn.x, ", ", conn.y, ") direction: ", conn.direction)
	
	if t_required.size() == 3 and l_required.size() == 2:
		print("  ✓ PASS: All connections are marked as required\n")
	else:
		print("  ✗ FAIL: Expected all connections to be required\n")
		get_tree().quit(1)
		return
	
	# Test 4: Verify that get_connection_points() == get_required_connection_points()
	print("TEST 4: Verify all connections are required")
	print("-" * 50)
	if t_connections.size() == t_required.size() and l_connections.size() == l_required.size():
		print("  ✓ PASS: All connections are marked as required (as expected)\n")
	else:
		print("  ✗ FAIL: Not all connections are required!\n")
		get_tree().quit(1)
		return
	
	# Test 5: Test connection_required flag on cells
	print("TEST 5: Verify connection_required flag on cells")
	print("-" * 50)
	var t_required_cells = 0
	var l_required_cells = 0
	
	for y in range(t_room.height):
		for x in range(t_room.width):
			var cell = t_room.get_cell(x, y)
			if cell != null and cell.connection_required:
				t_required_cells += 1
				print("  T-Room cell (", x, ", ", y, ") has connection_required=true")
				print("    Connections: UP=", cell.connection_up, " RIGHT=", cell.connection_right, 
					  " BOTTOM=", cell.connection_bottom, " LEFT=", cell.connection_left)
	
	for y in range(l_room.height):
		for x in range(l_room.width):
			var cell = l_room.get_cell(x, y)
			if cell != null and cell.connection_required:
				l_required_cells += 1
				print("  L-Corridor cell (", x, ", ", y, ") has connection_required=true")
				print("    Connections: UP=", cell.connection_up, " RIGHT=", cell.connection_right, 
					  " BOTTOM=", cell.connection_bottom, " LEFT=", cell.connection_left)
	
	print("  T-Room cells with connection_required: ", t_required_cells)
	print("  L-Corridor cells with connection_required: ", l_required_cells)
	
	if t_required_cells == 3 and l_required_cells == 2:
		print("  ✓ PASS: Correct number of cells with connection_required flag\n")
	else:
		print("  ✗ FAIL: Expected 3 T-Room cells and 2 L-Corridor cells with connection_required\n")
		get_tree().quit(1)
		return
	
	# Test 6: Rotation test - verify connections are preserved after rotation
	print("TEST 6: Test rotation preserves connections")
	print("-" * 50)
	var rotations = [
		RoomRotator.Rotation.DEG_90,
		RoomRotator.Rotation.DEG_180,
		RoomRotator.Rotation.DEG_270
	]
	
	for rotation in rotations:
		var rotated_t = RoomRotator.rotate_room(t_room, rotation)
		var rotated_l = RoomRotator.rotate_room(l_room, rotation)
		
		var t_conn_after = rotated_t.get_connection_points()
		var l_conn_after = rotated_l.get_connection_points()
		var t_req_after = rotated_t.get_required_connection_points()
		var l_req_after = rotated_l.get_required_connection_points()
		
		print("  After ", rotation, " rotation:")
		print("    T-Room connections: ", t_conn_after.size(), " (required: ", t_req_after.size(), ")")
		print("    L-Corridor connections: ", l_conn_after.size(), " (required: ", l_req_after.size(), ")")
		
		if t_conn_after.size() != 3 or l_conn_after.size() != 2:
			print("  ✗ FAIL: Connection count changed after rotation!\n")
			get_tree().quit(1)
			return
		
		if t_req_after.size() != 3 or l_req_after.size() != 2:
			print("  ✗ FAIL: Required connection count changed after rotation!\n")
			get_tree().quit(1)
			return
	
	print("  ✓ PASS: Connections preserved after all rotations\n")
	
	print("\n=== ALL TESTS PASSED ===")
	print("The connection room detection logic is working correctly.")
	print("The bug must be in the placement validation logic in dungeon_generator.gd")
	
	get_tree().quit(0)

extends Node

## Test script for Connection Room functionality
## Run this script in Godot to validate the connection room system

func _ready() -> void:
	print("=== Connection Room System Tests ===")
	print()
	
	test_is_connection_room()
	test_get_required_connection_points()
	test_connection_room_placement()
	test_starting_room_is_normal()
	
	print()
	print("=== All Tests Complete ===")


## Test 1: is_connection_room() method
func test_is_connection_room() -> void:
	print("Test 1: is_connection_room()")
	
	# Test with a room that has no required connections
	var normal_room = MetaRoom.new()
	normal_room.width = 3
	normal_room.height = 3
	normal_room._initialize_cells()
	
	# Add a connection but not required
	var edge_cell = normal_room.get_cell(0, 1)
	edge_cell.connection_left = true
	edge_cell.connection_required = false
	
	assert(not normal_room.is_connection_room(), "Normal room should not be a connection room")
	print("  ✓ Normal room correctly identified as non-connection room")
	
	# Test with a connection room (has required connection)
	var connection_room = MetaRoom.new()
	connection_room.width = 3
	connection_room.height = 3
	connection_room._initialize_cells()
	
	# Add a required connection
	var required_cell = connection_room.get_cell(1, 0)
	required_cell.connection_up = true
	required_cell.connection_required = true
	
	assert(connection_room.is_connection_room(), "Room with required connection should be a connection room")
	print("  ✓ Connection room correctly identified")
	
	print()


## Test 2: get_required_connection_points() method
func test_get_required_connection_points() -> void:
	print("Test 2: get_required_connection_points()")
	
	# Create a T-shaped room with 3 required connections
	var t_room = MetaRoom.new()
	t_room.width = 5
	t_room.height = 4
	t_room._initialize_cells()
	
	# Add required connections (LEFT, RIGHT, BOTTOM like a T)
	var left_cell = t_room.get_cell(0, 1)
	left_cell.connection_left = true
	left_cell.connection_required = true
	
	var right_cell = t_room.get_cell(4, 1)
	right_cell.connection_right = true
	right_cell.connection_required = true
	
	var bottom_cell = t_room.get_cell(2, 3)
	bottom_cell.connection_bottom = true
	bottom_cell.connection_required = true
	
	var required_connections = t_room.get_required_connection_points()
	
	assert(required_connections.size() == 3, "T-room should have 3 required connections")
	print("  ✓ Found correct number of required connections: ", required_connections.size())
	
	# Verify the directions
	var has_left = false
	var has_right = false
	var has_bottom = false
	
	for conn in required_connections:
		if conn.direction == MetaCell.Direction.LEFT:
			has_left = true
		elif conn.direction == MetaCell.Direction.RIGHT:
			has_right = true
		elif conn.direction == MetaCell.Direction.BOTTOM:
			has_bottom = true
	
	assert(has_left and has_right and has_bottom, "Should have all three required directions")
	print("  ✓ All required connection directions present")
	
	print()


## Test 3: Connection room placement validation
func test_connection_room_placement() -> void:
	print("Test 3: Connection room placement validation")
	
	# Create a simple dungeon generator setup
	var generator = DungeonGenerator.new()
	
	# Create a normal room template
	var normal_room = MetaRoom.new()
	normal_room.width = 3
	normal_room.height = 3
	normal_room._initialize_cells()
	normal_room.room_name = "Normal Room"
	
	# Add connections
	normal_room.get_cell(1, 0).connection_up = true
	normal_room.get_cell(2, 1).connection_right = true
	normal_room.get_cell(1, 2).connection_bottom = true
	normal_room.get_cell(0, 1).connection_left = true
	
	# Create a connection room template (L-shape)
	var l_room = MetaRoom.new()
	l_room.width = 3
	l_room.height = 3
	l_room._initialize_cells()
	l_room.room_name = "L-Room (Connection)"
	
	# Add required connections
	l_room.get_cell(2, 1).connection_right = true
	l_room.get_cell(2, 1).connection_required = true
	
	l_room.get_cell(1, 2).connection_bottom = true
	l_room.get_cell(1, 2).connection_required = true
	
	generator.room_templates = [normal_room, l_room]
	
	# Place the first normal room
	var first_placement = generator.PlacedRoom.new(
		normal_room.clone(),
		Vector2i.ZERO,
		0,  # Rotation
		normal_room
	)
	generator.placed_rooms.append(first_placement)
	
	# Mark cells as occupied
	for y in range(first_placement.room.height):
		for x in range(first_placement.room.width):
			var world_pos = first_placement.get_cell_world_pos(x, y)
			generator.occupied_cells[world_pos] = first_placement
	
	print("  ✓ Test setup complete")
	print("  - Normal room placed at origin")
	print("  - Connection room has 2 required connections")
	
	# Test that the validation method exists and can be called
	# After the fix: The L-room at position (3, 0) should FAIL validation
	# because there's no normal room at the required connection positions (they're empty)
	var can_fulfill = generator._can_fulfill_required_connections(l_room, Vector2i(3, 0))
	assert(not can_fulfill, "L-room should NOT be placeable at (3, 0) - required connections point to empty space")
	print("  ✓ _can_fulfill_required_connections() correctly returns false when adjacent positions are empty")
	
	# Now place another normal room to satisfy one of the L-room's required connections
	var second_normal = normal_room.clone()
	var second_placement = generator.PlacedRoom.new(
		second_normal,
		Vector2i(6, 1),  # Place to the right of where L-room would be
		0,
		normal_room
	)
	generator.placed_rooms.append(second_placement)
	
	# Mark cells as occupied
	for y in range(second_placement.room.height):
		for x in range(second_placement.room.width):
			var world_pos = second_placement.get_cell_world_pos(x, y)
			generator.occupied_cells[world_pos] = second_placement
	
	# Still should fail because only ONE required connection is satisfied (not all)
	var can_fulfill_partial = generator._can_fulfill_required_connections(l_room, Vector2i(3, 0))
	assert(not can_fulfill_partial, "L-room should NOT be placeable - only one required connection satisfied")
	print("  ✓ _can_fulfill_required_connections() correctly requires ALL connections to be satisfied")
	
	print()


## Test 4: Starting room is always a normal room
func test_starting_room_is_normal() -> void:
	print("Test 4: Starting room is never a connection room")
	
	# Create a generator with both normal and connection room templates
	var generator = DungeonGenerator.new()
	
	# Create a normal room
	var normal_room = MetaRoom.new()
	normal_room.width = 3
	normal_room.height = 3
	normal_room._initialize_cells()
	normal_room.room_name = "Normal Room"
	normal_room.get_cell(1, 0).connection_up = true
	normal_room.get_cell(2, 1).connection_right = true
	normal_room.get_cell(1, 2).connection_bottom = true
	normal_room.get_cell(0, 1).connection_left = true
	
	# Create a connection room (L-room)
	var l_room = MetaRoom.new()
	l_room.width = 3
	l_room.height = 3
	l_room._initialize_cells()
	l_room.room_name = "L-Room (Connection)"
	l_room.get_cell(2, 1).connection_right = true
	l_room.get_cell(2, 1).connection_required = true
	l_room.get_cell(1, 2).connection_bottom = true
	l_room.get_cell(1, 2).connection_required = true
	
	# Set templates
	generator.room_templates = [normal_room, l_room]
	
	# Test _get_random_room_with_connections multiple times
	print("  Testing _get_random_room_with_connections() 20 times...")
	for i in range(20):
		var start_room = generator._get_random_room_with_connections()
		assert(start_room != null, "Should return a valid room")
		assert(not start_room.is_connection_room(), "Starting room should NEVER be a connection room")
		assert(start_room.room_name == "Normal Room", "Starting room should be the normal room")
	
	print("  ✓ Starting room is always a normal room (tested 20 times)")
	
	# Test with only connection rooms (should return null)
	generator.room_templates = [l_room]
	var no_valid_start = generator._get_random_room_with_connections()
	assert(no_valid_start == null, "Should return null when only connection rooms are available")
	print("  ✓ Returns null when no normal rooms with connections are available")
	
	print()


## Helper assert function with better error messages
func assert(condition: bool, message: String) -> void:
	if not condition:
		push_error("ASSERTION FAILED: " + message)
	else:
		# Assertion passed, do nothing
		pass

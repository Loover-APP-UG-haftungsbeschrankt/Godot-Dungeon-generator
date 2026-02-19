extends SceneTree

# Test script to validate rotation functionality

func _init():
	print("=== Testing Room Rotation System ===\n")
	
	# Test 1: Connection rotation
	test_connection_rotation()
	
	# Test 2: Position rotation
	test_position_rotation()
	
	# Test 3: Full room rotation with connection_required flag
	test_room_rotation_with_required()
	
	print("\n=== All Tests Completed ===")
	quit()

func test_connection_rotation():
	print("Test 1: Connection Direction Rotation")
	print("--------------------------------------")
	
	var cell = MetaCell.new()
	cell.connection_up = true
	cell.connection_right = true
	cell.connection_required = true
	
	print("Original: UP=true, RIGHT=true, BOTTOM=false, LEFT=false, required=true")
	
	# Test 90° rotation
	var cell_90 = cell.clone()
	RoomRotator._rotate_cell_connections(cell_90, RoomRotator.Rotation.DEG_90)
	print("After 90°: UP=%s, RIGHT=%s, BOTTOM=%s, LEFT=%s, required=%s" % [
		cell_90.connection_up, cell_90.connection_right, 
		cell_90.connection_bottom, cell_90.connection_left,
		cell_90.connection_required
	])
	
	# Expected: UP=false, RIGHT=true (was UP), BOTTOM=true (was RIGHT), LEFT=false
	var pass_90 = (!cell_90.connection_up and cell_90.connection_right and 
	               cell_90.connection_bottom and !cell_90.connection_left and
	               cell_90.connection_required)
	print("90° rotation: %s" % ("PASS" if pass_90 else "FAIL"))
	
	# Test 180° rotation
	var cell_180 = cell.clone()
	RoomRotator._rotate_cell_connections(cell_180, RoomRotator.Rotation.DEG_180)
	print("After 180°: UP=%s, RIGHT=%s, BOTTOM=%s, LEFT=%s" % [
		cell_180.connection_up, cell_180.connection_right, 
		cell_180.connection_bottom, cell_180.connection_left
	])
	
	# Expected: UP=false (was BOTTOM), RIGHT=false (was LEFT), BOTTOM=true (was UP), LEFT=true (was RIGHT)
	var pass_180 = (!cell_180.connection_up and !cell_180.connection_right and 
	                cell_180.connection_bottom and cell_180.connection_left)
	print("180° rotation: %s" % ("PASS" if pass_180 else "FAIL"))
	
	# Test 270° rotation
	var cell_270 = cell.clone()
RoomRotator._rotate_cell_connections(cell_270, RoomRotator.Rotation.DEG_270)
print("After 270°: UP=%s, RIGHT=%s, BOTTOM=%s, LEFT=%s" % [
cell_270.connection_up, cell_270.connection_right, 
cell_270.connection_bottom, cell_270.connection_left
])

# Expected: UP=true (was RIGHT), RIGHT=false, BOTTOM=false, LEFT=true (was UP)
var pass_270 = (cell_270.connection_up and !cell_270.connection_right and 
                !cell_270.connection_bottom and cell_270.connection_left)
print("270° rotation: %s\n" % ("PASS" if pass_270 else "FAIL"))

func test_position_rotation():
	print("Test 2: Position Rotation in 3x3 Grid")
	print("--------------------------------------")

# Test position (1, 0) - top middle
var pos = Vector2i(1, 0)
print("Original position: (1, 0) - top middle")

var pos_90 = RoomRotator._rotate_position(pos.x, pos.y, 3, 3, RoomRotator.Rotation.DEG_90)
print("After 90°: %s (expected (0, 1) - middle left)" % pos_90)
var pass_90 = (pos_90 == Vector2i(0, 1))

var pos_180 = RoomRotator._rotate_position(pos.x, pos.y, 3, 3, RoomRotator.Rotation.DEG_180)
print("After 180°: %s (expected (1, 2) - bottom middle)" % pos_180)
var pass_180 = (pos_180 == Vector2i(1, 2))

var pos_270 = RoomRotator._rotate_position(pos.x, pos.y, 3, 3, RoomRotator.Rotation.DEG_270)
print("After 270°: %s (expected (2, 1) - middle right)" % pos_270)
var pass_270 = (pos_270 == Vector2i(2, 1))

print("Position rotation: %s\n" % ("PASS" if (pass_90 and pass_180 and pass_270) else "FAIL"))

func test_room_rotation_with_required():
print("Test 3: Full Room Rotation with connection_required Flag")
print("---------------------------------------------------------")

# Create a simple 3x3 room with required connections
var room = MetaRoom.new()
room.width = 3
room.height = 3
room.room_name = "TestRoom"
room.cells.clear()

# Fill with floor cells
for i in range(9):
var cell = MetaCell.new()
cell.cell_type = MetaCell.CellType.FLOOR
room.cells.append(cell)

# Set connections on edges with required flag
# Top middle (1,0) has UP connection (required)
var top_cell = room.get_cell(1, 0)
top_cell.connection_up = true
top_cell.connection_required = true

# Right middle (2,1) has RIGHT connection (not required)
var right_cell = room.get_cell(2, 1)
right_cell.connection_right = true
right_cell.connection_required = false

print("Original room:")
print("  Top middle (1,0): UP connection, required=true")
print("  Right middle (2,1): RIGHT connection, required=false")

# Rotate 90°
var rotated_90 = RoomRotator.rotate_room(room, RoomRotator.Rotation.DEG_90)

# After 90° rotation of 3x3:
# (1,0) -> (0,1) and UP -> LEFT
# (2,1) -> (1,2) and RIGHT -> BOTTOM

var rotated_left_cell = rotated_90.get_cell(0, 1)
var rotated_bottom_cell = rotated_90.get_cell(1, 2)

print("\nAfter 90° rotation:")
print("  Position (0,1) should have LEFT connection, required=true")
print("    Actual: LEFT=%s, required=%s" % [rotated_left_cell.connection_left, rotated_left_cell.connection_required])
print("  Position (1,2) should have BOTTOM connection, required=false")
print("    Actual: BOTTOM=%s, required=%s" % [rotated_bottom_cell.connection_bottom, rotated_bottom_cell.connection_required])

var pass_required = (rotated_left_cell.connection_left and rotated_left_cell.connection_required and
                     rotated_bottom_cell.connection_bottom and !rotated_bottom_cell.connection_required)

print("\nRequired flag preservation: %s" % ("PASS" if pass_required else "FAIL"))

# Check connection points
var conn_points = rotated_90.get_connection_points()
print("\nConnection points after rotation: %d" % conn_points.size())
for cp in conn_points:
var cell = rotated_90.get_cell(cp.x, cp.y)
print("  (%d,%d) direction=%d required=%s" % [cp.x, cp.y, cp.direction, cell.connection_required])


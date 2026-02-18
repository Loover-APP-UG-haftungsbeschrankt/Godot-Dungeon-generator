class_name RoomRotator
extends RefCounted

## RoomRotator provides static methods for rotating MetaRoom instances.
## Supports 0°, 90°, 180°, and 270° rotations.

## Rotation angles enum
enum Rotation {
	DEG_0 = 0,
	DEG_90 = 1,
	DEG_180 = 2,
	DEG_270 = 3
}


## Rotates a room by the specified angle and returns a new rotated room
static func rotate_room(room: MetaRoom, rotation: Rotation) -> MetaRoom:
	if rotation == Rotation.DEG_0:
		return room.clone()
	
	var rotated_room = MetaRoom.new()
	rotated_room.room_name = room.room_name + "_rot" + str(rotation * 90)
	
	# Calculate new dimensions based on rotation
	if rotation == Rotation.DEG_90 or rotation == Rotation.DEG_270:
		rotated_room.width = room.height
		rotated_room.height = room.width
	else:
		rotated_room.width = room.width
		rotated_room.height = room.height
	
	# Initialize the rotated cells array
	rotated_room.cells.clear()
	for i in range(rotated_room.width * rotated_room.height):
		rotated_room.cells.append(null)
	
	# Copy and rotate required_connections
	rotated_room.required_connections.clear()
	for direction in room.required_connections:
		var rotated_dir = rotate_direction(direction, rotation)
		rotated_room.required_connections.append(rotated_dir)
	
	# Rotate each cell
	for y in range(room.height):
		for x in range(room.width):
			var original_cell = room.get_cell(x, y)
			if original_cell == null:
				continue
			
			var rotated_cell = original_cell.clone()
			_rotate_cell_connections(rotated_cell, rotation)
			
			var new_pos = _rotate_position(x, y, room.width, room.height, rotation)
			rotated_room.set_cell(new_pos.x, new_pos.y, rotated_cell)
	
	return rotated_room


## Rotates a position in a grid
static func _rotate_position(x: int, y: int, grid_width: int, grid_height: int, rotation: Rotation) -> Vector2i:
	match rotation:
		Rotation.DEG_0:
			return Vector2i(x, y)
		Rotation.DEG_90:
			# 90° clockwise: (x, y) -> (y, width - 1 - x)
			return Vector2i(y, grid_width - 1 - x)
		Rotation.DEG_180:
			# 180°: (x, y) -> (width - 1 - x, height - 1 - y)
			return Vector2i(grid_width - 1 - x, grid_height - 1 - y)
		Rotation.DEG_270:
			# 270° clockwise (90° counter-clockwise): (x, y) -> (height - 1 - y, x)
			return Vector2i(grid_height - 1 - y, x)
	
	return Vector2i(x, y)


## Rotates the connection directions of a cell
static func _rotate_cell_connections(cell: MetaCell, rotation: Rotation) -> void:
	if rotation == Rotation.DEG_0:
		return
	
	# Store original connections
	var up = cell.connection_up
	var right = cell.connection_right
	var bottom = cell.connection_bottom
	var left = cell.connection_left
	
	match rotation:
		Rotation.DEG_90:
			# 90° clockwise: UP->RIGHT, RIGHT->BOTTOM, BOTTOM->LEFT, LEFT->UP
			cell.connection_up = left
			cell.connection_right = up
			cell.connection_bottom = right
			cell.connection_left = bottom
		
		Rotation.DEG_180:
			# 180°: UP->BOTTOM, RIGHT->LEFT, BOTTOM->UP, LEFT->RIGHT
			cell.connection_up = bottom
			cell.connection_right = left
			cell.connection_bottom = up
			cell.connection_left = right
		
		Rotation.DEG_270:
			# 270° clockwise: UP->LEFT, RIGHT->UP, BOTTOM->RIGHT, LEFT->BOTTOM
			cell.connection_up = right
			cell.connection_right = bottom
			cell.connection_bottom = left
			cell.connection_left = up


## Rotates a direction by the specified rotation
static func rotate_direction(direction: MetaCell.Direction, rotation: Rotation) -> MetaCell.Direction:
	var steps = int(rotation)
	var new_direction = (int(direction) + steps) % 4
	return new_direction as MetaCell.Direction


## Returns all possible rotations
static func get_all_rotations() -> Array[Rotation]:
	var rotations: Array[Rotation] = [
		Rotation.DEG_0,
		Rotation.DEG_90,
		Rotation.DEG_180,
		Rotation.DEG_270
	]
	return rotations

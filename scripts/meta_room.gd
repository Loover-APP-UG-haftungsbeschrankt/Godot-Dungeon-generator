@tool
class_name MetaRoom
extends Resource

## MetaRoom represents a room template composed of a grid of MetaCells.
## Rooms can be rotated and connected to form a dungeon.

## Width of the room in cells
@export var width: int = 3

## Height of the room in cells
@export var height: int = 3

## Grid of cells stored as a flat array (row-major order)
## Access using: cells[y * width + x]
@export var cells: Array[MetaCell] = []

## Name identifier for this room template
@export var room_name: String = "Room"


func _init() -> void:
	# Initialize with empty cells if needed
	if cells.is_empty() and width > 0 and height > 0:
		_initialize_cells()


## Initialize the cells array with default floor cells
func _initialize_cells() -> void:
	cells.clear()
	for y in range(height):
		for x in range(width):
			var cell = MetaCell.new()
			cell.cell_type = MetaCell.CellType.FLOOR
			cells.append(cell)


## Gets the cell at the specified grid position
## Returns null if position is out of bounds
func get_cell(x: int, y: int) -> MetaCell:
	if x < 0 or x >= width or y < 0 or y >= height:
		return null
	
	var index = y * width + x
	if index < 0 or index >= cells.size():
		return null
	
	return cells[index]


## Sets the cell at the specified grid position
func set_cell(x: int, y: int, cell: MetaCell) -> void:
	if x < 0 or x >= width or y < 0 or y >= height:
		return
	
	var index = y * width + x
	if index >= 0 and index < cells.size():
		cells[index] = cell


## Connection point structure
class ConnectionPoint:
	var x: int
	var y: int
	var direction: MetaCell.Direction
	
	func _init(p_x: int, p_y: int, p_direction: MetaCell.Direction):
		x = p_x
		y = p_y
		direction = p_direction


## Returns all available connection points in this room
## A connection point is a cell that has a connection leading outside the room
func get_connection_points() -> Array[ConnectionPoint]:
	var connections: Array[ConnectionPoint] = []
	
	for y in range(height):
		for x in range(width):
			var cell = get_cell(x, y)
			if cell == null:
				continue
			
			# Check all connections on all cells
			# Original room designs place connections on edge cells, but rotation moves
			# these cells to new positions. By checking all cells regardless of edge position,
			# we ensure rotated rooms have their connections properly detected.
			
			# Check UP connection
			if cell.connection_up:
				connections.append(ConnectionPoint.new(x, y, MetaCell.Direction.UP))
			
			# Check RIGHT connection
			if cell.connection_right:
				connections.append(ConnectionPoint.new(x, y, MetaCell.Direction.RIGHT))
			
			# Check BOTTOM connection
			if cell.connection_bottom:
				connections.append(ConnectionPoint.new(x, y, MetaCell.Direction.BOTTOM))
			
			# Check LEFT connection
			if cell.connection_left:
				connections.append(ConnectionPoint.new(x, y, MetaCell.Direction.LEFT))
	
	return connections


## Returns true if this room has at least one connection point
func has_connection_points() -> bool:
	return not get_connection_points().is_empty()


## Returns true if this room is a connection room (has any required connections)
## Connection rooms are special rooms like L, T, I shapes that must have all their
## required connections fulfilled when placed
func is_connection_room() -> bool:
	for y in range(height):
		for x in range(width):
			var cell = get_cell(x, y)
			# A cell with connection_required should have at least one connection
			# If connection_required is true but no connections exist, it's a data error
			if cell != null and cell.connection_required:
				return true
	return false


## Returns only the connection points that are marked as required
## These connections must be fulfilled for connection rooms to be placed
func get_required_connection_points() -> Array[ConnectionPoint]:
	var required_connections: Array[ConnectionPoint] = []
	
	for y in range(height):
		for x in range(width):
			var cell = get_cell(x, y)
			if cell == null or not cell.connection_required:
				continue
			
			# For cells with connection_required, add ALL their connections
			# Same logic as get_connection_points() - rotation moves required connection
			# cells away from original edge positions, so we check all cells
			
			# Check UP connection
			if cell.connection_up:
				required_connections.append(ConnectionPoint.new(x, y, MetaCell.Direction.UP))
			
			# Check RIGHT connection
			if cell.connection_right:
				required_connections.append(ConnectionPoint.new(x, y, MetaCell.Direction.RIGHT))
			
			# Check BOTTOM connection
			if cell.connection_bottom:
				required_connections.append(ConnectionPoint.new(x, y, MetaCell.Direction.BOTTOM))
			
			# Check LEFT connection
			if cell.connection_left:
				required_connections.append(ConnectionPoint.new(x, y, MetaCell.Direction.LEFT))
	
	return required_connections


## Creates a deep copy of this room
func clone() -> MetaRoom:
	var new_room = MetaRoom.new()
	new_room.width = width
	new_room.height = height
	new_room.room_name = room_name
	new_room.cells.clear()
	
	for cell in cells:
		if cell != null:
			new_room.cells.append(cell.clone())
		else:
			new_room.cells.append(null)
	
	return new_room


## Validates that the room data is consistent
func validate() -> bool:
	if width <= 0 or height <= 0:
		push_error("MetaRoom: Invalid dimensions")
		return false
	
	if cells.size() != width * height:
		push_error("MetaRoom: Cell array size doesn't match dimensions")
		return false
	
	return true

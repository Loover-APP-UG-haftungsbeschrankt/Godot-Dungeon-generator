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

## Array of connection directions that MUST be connected to other rooms
## Example: [Direction.UP, Direction.LEFT, Direction.RIGHT] for a T-room
## Empty array means no required connections (all are optional)
@export var required_connections: Array[MetaCell.Direction] = []


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
			#if cell == null or cell.cell_type == MetaCell.CellType.BLOCKED:
			#	continue
			
			# Check UP connection (y = 0)
			if y == 0 and cell.connection_up:
				connections.append(ConnectionPoint.new(x, y, MetaCell.Direction.UP))
			
			# Check RIGHT connection (x = width - 1)
			if x == width - 1 and cell.connection_right:
				connections.append(ConnectionPoint.new(x, y, MetaCell.Direction.RIGHT))
			
			# Check BOTTOM connection (y = height - 1)
			if y == height - 1 and cell.connection_bottom:
				connections.append(ConnectionPoint.new(x, y, MetaCell.Direction.BOTTOM))
			
			# Check LEFT connection (x = 0)
			if x == 0 and cell.connection_left:
				connections.append(ConnectionPoint.new(x, y, MetaCell.Direction.LEFT))
	
	return connections


## Returns true if this room has at least one connection point
func has_connection_points() -> bool:
	return not get_connection_points().is_empty()


## Creates a deep copy of this room
func clone() -> MetaRoom:
	var new_room = MetaRoom.new()
	new_room.width = width
	new_room.height = height
	new_room.room_name = room_name
	new_room.required_connections = required_connections.duplicate()
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

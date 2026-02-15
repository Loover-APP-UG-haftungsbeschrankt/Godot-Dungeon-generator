@tool
class_name MetaCell
extends Resource

## MetaCell represents a single cell in a dungeon room.
## It defines the cell type and its connections to adjacent cells.

## Direction enum for cell connections
enum Direction {
	UP = 0,
	RIGHT = 1,
	BOTTOM = 2,
	LEFT = 3
}

## Cell type enum defining what kind of cell this is
enum CellType {
	BLOCKED = 0,  ## Cannot be walked through
	FLOOR = 1,    ## Regular walkable floor
	DOOR = 2      ## Connection point to other rooms
}

## The type of this cell
@export var cell_type: CellType = CellType.FLOOR

## Whether this cell has a connection upward
@export var connection_up: bool = false

## Whether this cell has a connection to the right
@export var connection_right: bool = false

## Whether this cell has a connection downward
@export var connection_bottom: bool = false

## Whether this cell has a connection to the left
@export var connection_left: bool = false

## Whether the up connection is required (must be connected)
@export var connection_up_required: bool = false

## Whether the right connection is required (must be connected)
@export var connection_right_required: bool = false

## Whether the bottom connection is required (must be connected)
@export var connection_bottom_required: bool = false

## Whether the left connection is required (must be connected)
@export var connection_left_required: bool = false


## Returns true if this cell has any connections
func has_any_connection() -> bool:
	return connection_up or connection_right or connection_bottom or connection_left


## Returns true if this cell has a connection in the specified direction
func has_connection(direction: Direction) -> bool:
	match direction:
		Direction.UP:
			return connection_up
		Direction.RIGHT:
			return connection_right
		Direction.BOTTOM:
			return connection_bottom
		Direction.LEFT:
			return connection_left
	return false


## Sets the connection state for a specific direction
func set_connection(direction: Direction, value: bool) -> void:
	match direction:
		Direction.UP:
			connection_up = value
		Direction.RIGHT:
			connection_right = value
		Direction.BOTTOM:
			connection_bottom = value
		Direction.LEFT:
			connection_left = value


## Returns true if a connection in the specified direction is required
func is_connection_required(direction: Direction) -> bool:
	match direction:
		Direction.UP:
			return connection_up_required
		Direction.RIGHT:
			return connection_right_required
		Direction.BOTTOM:
			return connection_bottom_required
		Direction.LEFT:
			return connection_left_required
	return false


## Sets the required state for a connection in a specific direction
func set_connection_required(direction: Direction, value: bool) -> void:
	match direction:
		Direction.UP:
			connection_up_required = value
		Direction.RIGHT:
			connection_right_required = value
		Direction.BOTTOM:
			connection_bottom_required = value
		Direction.LEFT:
			connection_left_required = value


## Returns the opposite direction
static func opposite_direction(direction: Direction) -> Direction:
	match direction:
		Direction.UP:
			return Direction.BOTTOM
		Direction.RIGHT:
			return Direction.LEFT
		Direction.BOTTOM:
			return Direction.UP
		Direction.LEFT:
			return Direction.RIGHT
	return Direction.UP


## Creates a deep copy of this cell
func clone() -> MetaCell:
	var new_cell = MetaCell.new()
	new_cell.cell_type = cell_type
	new_cell.connection_up = connection_up
	new_cell.connection_right = connection_right
	new_cell.connection_bottom = connection_bottom
	new_cell.connection_left = connection_left
	new_cell.connection_up_required = connection_up_required
	new_cell.connection_right_required = connection_right_required
	new_cell.connection_bottom_required = connection_bottom_required
	new_cell.connection_left_required = connection_left_required
	return new_cell

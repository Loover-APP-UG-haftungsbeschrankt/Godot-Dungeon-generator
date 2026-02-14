class_name MetaPrefab
extends Resource

## Represents a prefab that can be placed on the meta grid
## Defines size, placement conditions for neighbors, and supports rotation

enum Direction {
	NORTH = 0,  # Up
	EAST = 1,   # Right
	SOUTH = 2,  # Down
	WEST = 3    # Left
}

## Size of the prefab in meta grid units
@export var width: int = 1
@export var height: int = 1

## Name/ID for this prefab
@export var prefab_name: String = ""

## Conditions for surrounding tiles
## Dictionary with Direction keys and MetaTileType values
## Only checks single-tile neighbors (not all cells around multi-tile prefabs)
@export var neighbor_conditions: Dictionary = {}

## Can this prefab be rotated?
@export var allow_rotation: bool = true

## The actual tile type this prefab represents when placed
@export var tile_type: MetaTileType

func _init(p_name: String = "", p_width: int = 1, p_height: int = 1):
	prefab_name = p_name
	width = p_width
	height = p_height
	neighbor_conditions = {}

## Set a condition for a specific direction
func set_neighbor_condition(direction: Direction, required_type: MetaTileType) -> void:
	neighbor_conditions[direction] = required_type

## Get the condition for a specific direction (returns null if none)
func get_neighbor_condition(direction: Direction) -> MetaTileType:
	return neighbor_conditions.get(direction, null)

## Check if conditions match for placement at given position
## grid: 2D array of MetaTileType
## x, y: position to check
## rotation: 0, 90, 180, 270 degrees
func can_place_at(grid: Array, grid_width: int, grid_height: int, x: int, y: int, rotation: int = 0) -> bool:
	# Check if prefab fits in grid
	var rot_width = width if rotation % 180 == 0 else height
	var rot_height = height if rotation % 180 == 0 else width
	
	if x + rot_width > grid_width or y + rot_height > grid_height:
		return false
	
	if x < 0 or y < 0:
		return false
	
	# Check if space is empty (null or compatible)
	for dy in range(rot_height):
		for dx in range(rot_width):
			var cell = grid[y + dy][x + dx]
			if cell != null:
				return false
	
	# Check neighbor conditions
	var rotation_offset = rotation / 90  # Convert to 0, 1, 2, 3
	
	for direction in neighbor_conditions.keys():
		var required_type: MetaTileType = neighbor_conditions[direction]
		if required_type == null:
			continue
		
		# Rotate the direction based on prefab rotation
		var rotated_dir = (direction + rotation_offset) % 4
		
		# Get neighbor position
		var neighbor_pos = _get_neighbor_position(x, y, rotated_dir)
		var nx = neighbor_pos.x
		var ny = neighbor_pos.y
		
		# Check if neighbor is in bounds
		if nx < 0 or nx >= grid_width or ny < 0 or ny >= grid_height:
			return false
		
		# Check if neighbor matches required type
		var neighbor_tile = grid[ny][nx]
		if neighbor_tile == null or not required_type.matches(neighbor_tile):
			return false
	
	return true

## Get neighbor position based on direction
func _get_neighbor_position(x: int, y: int, direction: Direction) -> Vector2i:
	match direction:
		Direction.NORTH:
			return Vector2i(x, y - 1)
		Direction.EAST:
			return Vector2i(x + 1, y)
		Direction.SOUTH:
			return Vector2i(x, y + 1)
		Direction.WEST:
			return Vector2i(x - 1, y)
		_:
			return Vector2i(x, y)

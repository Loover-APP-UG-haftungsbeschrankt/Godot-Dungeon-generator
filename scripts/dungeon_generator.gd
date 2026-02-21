class_name DungeonGenerator
extends Node

## DungeonGenerator creates a dungeon by placing rooms using a multi-walker algorithm.
## Multiple walkers independently place rooms until a target cell count is reached.
## This creates more organic, interconnected dungeons with loops.

## Placed room data structure
class PlacedRoom:
	var room: MetaRoom
	var position: Vector2i  # World position (in cells)
	var rotation: RoomRotator.Rotation
	var original_template: MetaRoom  # Reference to the original template before cloning/rotation
	
	func _init(p_room: MetaRoom, p_position: Vector2i, p_rotation: RoomRotator.Rotation, p_original_template: MetaRoom):
		room = p_room
		position = p_position
		rotation = p_rotation
		original_template = p_original_template
	
	## Gets the world position of a cell in this room
	func get_cell_world_pos(local_x: int, local_y: int) -> Vector2i:
		return position + Vector2i(local_x, local_y)


## Walker class for multi-walker dungeon generation
## Each walker independently places rooms until it dies or reaches its room limit
class Walker:
	var current_room: PlacedRoom  ## The room the walker is currently at
	var rooms_placed: int = 0     ## Number of rooms this walker has placed
	var is_alive: bool = true     ## Whether this walker is still active
	var max_rooms: int            ## Maximum rooms this walker can place before dying
	var walker_id: int            ## Unique identifier for this walker
	var path_history: Array[Vector2i] = []  ## History of room positions visited
	var color: Color              ## Visual color for this walker
	
	func _init(starting_room: PlacedRoom, p_max_rooms: int, p_walker_id: int = 0):
		current_room = starting_room
		max_rooms = p_max_rooms
		walker_id = p_walker_id
		rooms_placed = 0
		is_alive = true
		path_history.append(starting_room.position)
		# Assign unique color based on walker ID
		color = _generate_walker_color(p_walker_id)
	
	## Check if walker should die
	func check_death() -> void:
		if rooms_placed >= max_rooms:
			is_alive = false
	
	## Move walker to a new room
	func move_to_room(room: PlacedRoom) -> void:
		current_room = room
		path_history.append(room.position)
	
	## Generate a unique color for this walker
	func _generate_walker_color(id: int) -> Color:
		const GOLDEN_RATIO = 0.618033988749895  # Golden ratio for nice color distribution
		var hue = (id * GOLDEN_RATIO)
		hue = fmod(hue, 1.0)
		return Color.from_hsv(hue, 0.8, 0.9)


## Links a parent room to a child room that was placed to satisfy a required connection
class RequiredRoomLink:
	var from: PlacedRoom              ## The room that had the required connection
	var conn: MetaRoom.ConnectionPoint ## The required connection point used
	var to: PlacedRoom                ## The room placed to satisfy the connection
	var needs_placement: bool         ## False when 'to' is already placed (pre-satisfied connection)

	func _init(p_from: PlacedRoom, p_conn: MetaRoom.ConnectionPoint, p_to: PlacedRoom, p_needs_placement: bool = true) -> void:
		from = p_from
		conn = p_conn
		to = p_to
		needs_placement = p_needs_placement

## Boss room template to place at the farthest point from the entrance
@export var boss_room_template: MetaRoom = null

## Available room templates to use for generation
@export var room_templates: Array[MetaRoom] = []

## Random seed for generation (0 = random)
@export var generation_seed: int = 0

## Number of walkers to run simultaneously
@export var num_walkers: int = 3

## Maximum rooms each walker can place before dying
@export var max_rooms_per_walker: int = 20

## Maximum attempts to place each individual room (tries different templates/rotations)
@export var max_placement_attempts_per_room: int = 10

## Target total cell count (stop when this many cells are placed)
@export var target_meta_cell_count: int = 500

## Maximum iterations for the generation loop (safety limit)
@export var max_iterations: int = 10000

## Enable step-by-step visualization mode
@export var enable_visualization: bool = false

## Delay between each room placement step (in seconds) when visualizing
@export var visualization_step_delay: float = 0.1

## Directional bias for more compact dungeons (0 = no bias, 1 = strong bias towards center)
@export_range(0.0, 1.0) var compactness_bias: float = 0.3

## Probability that a POTENTIAL_PASSAGE group is opened when neither side has a deep enough
## dead-end chain. Applies only to shallow / trivial loops.
## Range: 0.0 = never open shallow loops, 1.0 = always open (default: 0.25)
@export_range(0.0, 1.0) var loop_passage_chance: float = 0.25

## Minimum dead-end chain depth required on BOTH sides of a POTENTIAL_PASSAGE group
## for it to be opened automatically as a loop passage.
## A depth of N means at least N rooms with degree ≤ 2 must be reachable in an unbroken
## chain from the passage entrance on each side before hitting a junction.
## Example: depth 2 → chain of 3 rooms (entrance + 2 further rooms) required on each side.
@export_range(1, 10) var min_loop_dead_end_depth: int = 2

## Maximum recursion depth when validating required connections
## Limits how many chained required connections can be validated
## Higher values allow more complex room chains but may impact performance
const MAX_REQUIRED_CONNECTION_DEPTH: int = 3

## All four cardinal directions in a fixed order — used throughout generation and post-processing
const DIRECTIONS: Array[MetaCell.Direction] = [
	MetaCell.Direction.UP,
	MetaCell.Direction.RIGHT,
	MetaCell.Direction.BOTTOM,
	MetaCell.Direction.LEFT
]

## List of all placed rooms in the dungeon
var placed_rooms: Array[PlacedRoom] = []

## Grid of occupied cells (for collision detection)
var occupied_cells: Dictionary = {}  # Vector2i -> PlacedRoom

## Active walkers during generation
var active_walkers: Array[Walker] = []

## Counter for assigning unique walker IDs
var next_walker_id: int = 0

## The placed boss room (null if not placed or no boss_room_template set)
var boss_room: PlacedRoom = null


## Signal emitted when generation completes
## Parameters: success (bool), room_count (int), cell_count (int)
## Note: cell_count parameter added in multi-walker version
signal generation_complete(success: bool, room_count: int, cell_count: int)

## Signal emitted after resolve_potential_passages() finishes
## Parameters: opened_count (int), blocked_count (int) — number of passage groups opened/blocked
signal passages_resolved(opened_count: int, blocked_count: int)

## Signal emitted when a room is placed (for visualization)
## Parameters: placement (PlacedRoom), walker (Walker)
signal room_placed(placement: PlacedRoom, walker: Walker)

## Signal emitted when a walker moves or spawns (for visualization)
## Parameters: walker (Walker), from_position (Vector2i), to_position (Vector2i), is_teleport (bool)
signal walker_moved(walker: Walker, from_pos: Vector2i, to_pos: Vector2i, is_teleport: bool)

## Signal emitted at each generation step (for visualization)
## Parameters: iteration (int), total_cells (int)
signal generation_step(iteration: int, total_cells: int)

## Signal emitted when the boss room is placed after generation
## Parameters: placement (PlacedRoom)
signal boss_room_placed(placement: PlacedRoom)


## Generates the dungeon using multi-walker algorithm
func generate() -> bool:
	# Clear previous generation
	clear_dungeon()
	
	# Setup random seed
	if generation_seed != 0:
		seed(generation_seed)
	
	# Validate room templates
	if room_templates.is_empty():
		push_error("DungeonGenerator: No room templates provided")
		return false
	
	# Validate parameters
	if num_walkers <= 0:
		push_error("DungeonGenerator: num_walkers must be greater than 0")
		return false
	
	if max_rooms_per_walker <= 0:
		push_error("DungeonGenerator: max_rooms_per_walker must be greater than 0")
		return false
	
	if target_meta_cell_count <= 0:
		push_error("DungeonGenerator: target_meta_cell_count must be greater than 0")
		return false
	
	# Find a suitable starting room (one with connections)
	var start_room = _get_random_room_with_connections()
	if start_room == null:
		push_error("DungeonGenerator: No rooms with connections found")
		return false
	
	# Place the first room at origin (clone it to avoid modifying the template)
	var first_room_clone = start_room.clone()
	var first_placement = PlacedRoom.new(first_room_clone, Vector2i.ZERO, RoomRotator.Rotation.DEG_0, start_room)
	_place_room(first_placement)
	
	# Initialize walkers at the first room
	active_walkers.clear()
	next_walker_id = 0
	for i in range(num_walkers):
		var walker = Walker.new(first_placement, max_rooms_per_walker, next_walker_id)
		next_walker_id += 1
		active_walkers.append(walker)
		walker_moved.emit(walker, Vector2i.ZERO, first_placement.position, false)
	
	# Main generation loop - continue until target cell count is reached
	var iterations = 0
	
	while _count_total_cells() < target_meta_cell_count and iterations < max_iterations:
		iterations += 1
		
		# Emit step signal for visualization
		generation_step.emit(iterations, _count_total_cells())
		
		# Each walker attempts to place one room
		for walker in active_walkers:
			
			var old_pos = walker.current_room.position
			
			# Try to place a room from this walker's current position
			var placed = _walker_try_place_room(walker)
			
			if placed:
				walker.rooms_placed += 1
				walker.check_death()
				
				# Emit walker moved signal - this is a normal move, not a teleport
				walker_moved.emit(walker, old_pos, walker.current_room.position, false)
				
				# Wait for visualization if enabled
				if enable_visualization and visualization_step_delay > 0:
					await get_tree().create_timer(visualization_step_delay).timeout
			else:
				walker.is_alive = false
				
			if not walker.is_alive:
				_respawn_walker(walker)
			
			# Check if we've reached target cell count
			if _count_total_cells() >= target_meta_cell_count:
				break
	
	var cell_count = _count_total_cells()
	var success = cell_count >= target_meta_cell_count
	
	# Post-processing: resolve remaining POTENTIAL_PASSAGE cells into PASSAGE or BLOCKED
	resolve_potential_passages()
	
	# Place boss room at the farthest point from the entrance
	if boss_room_template != null:
		_place_boss_room()
	
	generation_complete.emit(success, placed_rooms.size(), cell_count)
	
	print("DungeonGenerator: Generated ", placed_rooms.size(), " rooms with ", cell_count, " cells")
	return success

## Walker attempts to place a room from its current position
## Returns true if a room was successfully placed
func _walker_try_place_room(walker: Walker) -> bool:
	# Get open connections from walker's current room
	var open_connections = _get_open_connections(walker.current_room)
	
	# If no open connections, walker can't place a room
	if open_connections.is_empty():
		return false
	
	# Get available room templates, excluding the walker's current room template
	var current_is_connection_room = walker.current_room.room.is_connection_room()
	var available_templates: Array[MetaRoom] = []
	for template in room_templates:
		# Skip same template; also skip connection rooms when walker is at a connection room
		if template == walker.current_room.original_template or \
				(current_is_connection_room and template.is_connection_room()):
			continue
		available_templates.append(template)
	
	# If no templates available (only current room's template exists), can't place any more rooms
	if available_templates.is_empty():
		return false
	
	# Shuffle connections for randomness, but apply compactness bias
	open_connections.shuffle()
	if compactness_bias > 0:
		open_connections = _sort_connections_by_compactness(walker.current_room, open_connections)
	
	# Try to place a room at each open connection
	for conn_point in open_connections:
		# Try up to max_placement_attempts_per_room times with different templates/rotations
		var attempt_count = 0
		var templates_tried: Array[MetaRoom] = []
		
		while attempt_count < max_placement_attempts_per_room and templates_tried.size() < available_templates.size():
			attempt_count += 1
			
			# Pick random unused template that we haven't tried yet for this connection
			var remaining_templates: Array[MetaRoom] = []
			for template in available_templates:
				if not templates_tried.has(template):
					remaining_templates.append(template)
			
			if remaining_templates.is_empty():
				break  # Tried all available templates for this connection
			
			var template = remaining_templates[randi() % remaining_templates.size()]
			templates_tried.append(template)
			
			# Try all rotations for this template
			var rotations = RoomRotator.get_all_rotations()
			rotations.shuffle()
			
			for rotation in rotations:
				var rotated_room = RoomRotator.rotate_room(template, rotation)
				var placement = _try_connect_room(walker.current_room, conn_point, rotated_room, rotation, template)
				
				if placement != null:
					# Check if this room has required connections that need to be satisfied
					var required_conns = rotated_room.get_required_connection_points()
					
					if required_conns.is_empty():
						# No required connections – place normally
						_place_room(placement)
						_mark_passage_at_connection(walker.current_room, conn_point, placement)
						walker.move_to_room(placement)
						room_placed.emit(placement, walker)
						return true
					
					# Determine which required connection is the incoming one (already satisfied)
					var incoming_dir = MetaCell.opposite_direction(conn_point.direction)
					
					# Collect required connections: unsatisfied (need a new room) and
					# pre-satisfied (already overlap an existing room, only need PASSAGE marking)
					var pre_satisfied_links: Array[RequiredRoomLink] = []
					var unsatisfied: Array[MetaRoom.ConnectionPoint] = []
					var connections_viable := true
					for req_conn in required_conns:
						if req_conn.direction == incoming_dir:
							continue
						var conn_world_pos = placement.get_cell_world_pos(req_conn.x, req_conn.y)
						if occupied_cells.has(conn_world_pos):
							var existing_pl = occupied_cells[conn_world_pos]
							var existing_c = _get_cell_at_world_pos(existing_pl, conn_world_pos)
							if existing_c != null and existing_c.has_connection(MetaCell.opposite_direction(req_conn.direction)):
								pre_satisfied_links.append(RequiredRoomLink.new(placement, req_conn, existing_pl, false))
								continue  # Already satisfied – track for PASSAGE marking, no new room needed
							# Occupied without matching connection – this rotation is not viable
							connections_viable = false
							break
						unsatisfied.append(req_conn)
					if not connections_viable:
						continue  # Try next rotation
					
					if unsatisfied.is_empty():
						# All required connections already satisfied by existing rooms
						_place_room(placement)
						_mark_passage_at_connection(walker.current_room, conn_point, placement)
						for link: RequiredRoomLink in pre_satisfied_links:
							_mark_passage_at_connection(link.from, link.conn, link.to)
						walker.move_to_room(placement)
						room_placed.emit(placement, walker)
						return true
					
					# Simulate placing the main room to check feasibility of additional rooms
					# Shallow duplicate is correct: _simulate_occupied only adds entries to the dict,
					# it never modifies PlacedRoom or MetaCell objects, so references stay valid.
					var saved_occupied = occupied_cells.duplicate()
					_simulate_occupied(placement)
					
					var additional_rooms: Array[RequiredRoomLink] = []
					var all_satisfied := true
					
					# Recursively validate required connections (with depth limit to prevent infinite loops)
					all_satisfied = _validate_required_connections_recursive(
						placement, unsatisfied, additional_rooms, 0, MAX_REQUIRED_CONNECTION_DEPTH
					)
					
					# Always restore occupied_cells after simulation
					occupied_cells = saved_occupied
					
					if not all_satisfied:
						continue  # Try next rotation / template
					
					# Merge pre-satisfied links so the commit loop marks their passages too
					for link: RequiredRoomLink in pre_satisfied_links:
						additional_rooms.append(link)
					
					# Commit: place main room and all additional rooms
					_place_room(placement)
					_mark_passage_at_connection(walker.current_room, conn_point, placement)
					walker.move_to_room(placement)
					room_placed.emit(placement, walker)
					for item: RequiredRoomLink in additional_rooms:
						if item.needs_placement:
							_place_room(item.to)
						_mark_passage_at_connection(item.from, item.conn, item.to)
						if item.needs_placement:
							room_placed.emit(item.to, walker)
					return true
	
	return false


## Respawns a walker at a random room with open connections
## Can spawn at current walker's position or at another room
func _respawn_walker(walker: Walker) -> void:
	var old_pos = walker.current_room.position
	
	# 30% chance to spawn at current position if it has open connections
	# 70% chance to spawn at a random other room (reduces linearity)
	var should_spawn_at_current_position = randf() < 0.3
	
	if should_spawn_at_current_position and not _get_open_connections(walker.current_room).is_empty():
		# Spawn at current position - not a teleport
		walker.rooms_placed = 0
		walker.is_alive = true
		# Path history is kept to show the walker's trail
		# No walker_moved signal needed as position didn't change
	else:
		# Spawn at a random room with open connections (no center bias for teleports)
		var spawn_target = _get_random_room_with_open_connections()
		if spawn_target != null:
			walker.current_room = spawn_target
			walker.rooms_placed = 0
			walker.is_alive = true
			walker.path_history.append(spawn_target.position)
			# This is a teleport - the walker jumped to a non-adjacent room
			walker_moved.emit(walker, old_pos, spawn_target.position, true)


## Gets all open connections from a placed room
## Open connections are those that don't already lead to an existing room
func _get_open_connections(placement: PlacedRoom) -> Array[MetaRoom.ConnectionPoint]:
	var open_connections: Array[MetaRoom.ConnectionPoint] = []
	var all_connections = placement.room.get_connection_points()
	
	for conn_point in all_connections:
		# Get the world position of this connection
		var conn_world_pos = placement.get_cell_world_pos(conn_point.x, conn_point.y)
		
		# Get the position that would be adjacent in the connection direction
		var adjacent_pos = conn_world_pos + _get_direction_offset(conn_point.direction)
		
		# If there's no room at the adjacent position, this connection is open
		if not occupied_cells.has(adjacent_pos):
			open_connections.append(conn_point)
	
	return open_connections


## Gets a random placed room that has at least one open connection
## Prefers rooms with unsatisfied required connections
func _get_random_room_with_open_connections() -> PlacedRoom:
	var rooms_with_open: Array[PlacedRoom] = []
	
	for placement in placed_rooms:
		var open_connections = _get_open_connections(placement)
		if not open_connections.is_empty():
			rooms_with_open.append(placement)
	
	# Otherwise, pick any room with open connections
	if rooms_with_open.is_empty():
		return null
	
	return rooms_with_open[randi() % rooms_with_open.size()]


## Counts the total number of cells placed in the dungeon
## This counts all non-null cells, not just room count
func _count_total_cells() -> int:
	var total = 0
	
	for placement in placed_rooms:
		for y in range(placement.room.height):
			for x in range(placement.room.width):
				var cell = placement.room.get_cell(x, y)
				if cell != null && cell.cell_type == MetaCell.CellType.FLOOR:
					total += 1
	
	return total

## Tries to connect a room at the specified connection point
## With blocked cell overlap, rooms share their edge cells
func _try_connect_room(
	from_placement: PlacedRoom,
	from_connection: MetaRoom.ConnectionPoint,
	to_room: MetaRoom,
	rotation: RoomRotator.Rotation,
	original_template: MetaRoom
) -> PlacedRoom:
	# Find matching connection points in the target room
	var to_connections = to_room.get_connection_points()
	
	for to_conn in to_connections:
		# Check if directions match (opposite)
		var from_world_pos = from_placement.get_cell_world_pos(from_connection.x, from_connection.y)
		var required_direction = MetaCell.opposite_direction(from_connection.direction)
		
		if to_conn.direction != required_direction:
			continue
		
		# Calculate target room position
		# The connection cells should overlap (be at the same position)
		# So we place the room such that to_conn cell aligns with from_connection cell
		var target_pos = from_world_pos - Vector2i(to_conn.x, to_conn.y)
		
		# Check if room can be placed with allowed overlaps
		if _can_place_room(to_room, target_pos):
			return PlacedRoom.new(to_room, target_pos, rotation, original_template)
	
	return null


## Checks if a room can be placed at the given position without overlapping
## Allows BLOCKED cells to overlap with other BLOCKED cells
func _can_place_room(room: MetaRoom, position: Vector2i) -> bool:
	for y in range(room.height):
		for x in range(room.width):
			var cell = room.get_cell(x, y)
			if cell == null:
				continue
			
			var world_pos = position + Vector2i(x, y)
			
			# If this cell is blocked, it can overlap with other blocked cells
			if cell.cell_type == MetaCell.CellType.BLOCKED:
				if occupied_cells.has(world_pos):
					var existing_placement = occupied_cells[world_pos]
					var existing_cell = _get_cell_at_world_pos(existing_placement, world_pos)
					# Only allow overlap if existing cell is also BLOCKED
					if existing_cell == null or existing_cell.cell_type != MetaCell.CellType.BLOCKED:
						return false
				# Blocked can overlap with blocked, so continue checking other cells
				continue
			
			# Non-blocked cells cannot overlap with anything
			if occupied_cells.has(world_pos):
				return false
	
	return true


## Helper function to get the cell at a world position from a placed room
func _get_cell_at_world_pos(placement: PlacedRoom, world_pos: Vector2i) -> MetaCell:
	var local_pos = world_pos - placement.position
	if local_pos.x < 0 or local_pos.x >= placement.room.width:
		return null
	if local_pos.y < 0 or local_pos.y >= placement.room.height:
		return null
	return placement.room.get_cell(local_pos.x, local_pos.y)


## Places a room and marks its cells as occupied
## Handles merging of overlapping blocked cells with opposite connections
func _place_room(placement: PlacedRoom) -> void:
	placed_rooms.append(placement)
	
	# Mark cells as occupied and handle overlaps
	for y in range(placement.room.height):
		for x in range(placement.room.width):
			var cell = placement.room.get_cell(x, y)
			if cell == null:
				continue
			
			var world_pos = placement.get_cell_world_pos(x, y)
			
			# Check if there's already a cell at this position (overlap case)
			if occupied_cells.has(world_pos):
				var existing_placement = occupied_cells[world_pos]
				var existing_cell = _get_cell_at_world_pos(existing_placement, world_pos)
				
				# Merge overlapping blocked cells
				if cell.cell_type == MetaCell.CellType.BLOCKED and existing_cell != null and existing_cell.cell_type == MetaCell.CellType.BLOCKED:
					# Track which direction got connected
					var connected_dir = _merge_overlapping_cells(existing_cell, cell, x, y, placement)
					
					# Keep the existing placement in occupied_cells (it's already there)
					continue
			
			# For non-blocked cells or non-overlapping cells, mark as occupied
			# if cell.cell_type != MetaCell.CellType.BLOCKED:
			occupied_cells[world_pos] = placement


## Merges two overlapping blocked cells
## If both have connections in opposite directions, removes those connections and marks the cell
## as POTENTIAL_PASSAGE. Returns the direction of the connection, or -1 if no connection was made.
func _merge_overlapping_cells(existing_cell: MetaCell, new_cell: MetaCell, local_x: int, local_y: int, new_placement: PlacedRoom) -> int:
	var potential_door := false
	var connected_direction: int = -1
	
	# Check for opposite-facing connections and remove them
	# Horizontal connections (LEFT-RIGHT)
	if existing_cell.connection_left and new_cell.connection_right:
		existing_cell.connection_left = false
		new_cell.connection_right = false
		potential_door = true
		connected_direction = MetaCell.Direction.RIGHT
	elif existing_cell.connection_right and new_cell.connection_left:
		existing_cell.connection_right = false
		new_cell.connection_left = false
		potential_door = true
		connected_direction = MetaCell.Direction.LEFT
	
	# Vertical connections (UP-DOWN)
	if existing_cell.connection_up and new_cell.connection_bottom:
		existing_cell.connection_up = false
		new_cell.connection_bottom = false
		potential_door = true
		connected_direction = MetaCell.Direction.BOTTOM
	elif existing_cell.connection_bottom and new_cell.connection_up:
		existing_cell.connection_bottom = false
		new_cell.connection_up = false
		potential_door = true
		connected_direction = MetaCell.Direction.UP
	
	# Ensure both cells remain blocked or become potential passages
	if potential_door:
		existing_cell.cell_type = MetaCell.CellType.POTENTIAL_PASSAGE
		new_cell.cell_type = MetaCell.CellType.POTENTIAL_PASSAGE
	else:
		existing_cell.cell_type = MetaCell.CellType.BLOCKED
		new_cell.cell_type = MetaCell.CellType.BLOCKED
	
	return connected_direction


## Upgrades the overlapping connection cells to PASSAGE after the walker traverses them.
## Uses BFS flood-fill from the connection point to upgrade all reachable POTENTIAL_PASSAGE cells.
func _mark_passage_at_connection(from_placement: PlacedRoom, conn_point: MetaRoom.ConnectionPoint, new_placement: PlacedRoom) -> void:
	var start_pos = from_placement.get_cell_world_pos(conn_point.x, conn_point.y)
	var queue: Array[Vector2i] = [start_pos]
	var visited: Dictionary = {}

	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		if visited.has(pos):
			continue
		visited[pos] = true

		# Collect all placements that own a cell at this position
		var placements_at_pos: Array[PlacedRoom] = []
		if occupied_cells.has(pos):
			placements_at_pos.append(occupied_cells[pos])
		# from_placement and new_placement may not be in occupied_cells yet at the exact pos
		for pl in [from_placement, new_placement]:
			if not placements_at_pos.has(pl):
				placements_at_pos.append(pl)

		# Try to upgrade; only continue BFS into a neighbor if at least one cell was upgraded here
		var upgraded := false
		for pl in placements_at_pos:
			if _try_upgrade_cell_to_passage(pl, pos):
				upgraded = true

		if upgraded:
			for direction in [MetaCell.Direction.UP, MetaCell.Direction.RIGHT, MetaCell.Direction.BOTTOM, MetaCell.Direction.LEFT]:
				var adj_pos = pos + _get_direction_offset(direction)
				if not visited.has(adj_pos):
					queue.append(adj_pos)


## Upgrades a single cell to PASSAGE if it is currently POTENTIAL_PASSAGE.
## Returns true if the cell was upgraded.
func _try_upgrade_cell_to_passage(placement: PlacedRoom, world_pos: Vector2i) -> bool:
	var cell = _get_cell_at_world_pos(placement, world_pos)
	if cell != null and cell.cell_type == MetaCell.CellType.POTENTIAL_PASSAGE:
		cell.cell_type = MetaCell.CellType.PASSAGE
		return true
	return false


## Adds room cells to occupied_cells without adding to placed_rooms and without merging.
## Used for feasibility simulation before committing placement.
## Mimics _place_room's behavior: does NOT overwrite existing entries (blocked-blocked overlap).
func _simulate_occupied(placement: PlacedRoom) -> void:
	for y in range(placement.room.height):
		for x in range(placement.room.width):
			var cell = placement.room.get_cell(x, y)
			if cell == null:
				continue
			var world_pos = placement.get_cell_world_pos(x, y)
			if not occupied_cells.has(world_pos):
				occupied_cells[world_pos] = placement


## Recursively validates required connections for a room and its dependencies.
## Returns true if all required connections can be satisfied, false otherwise.
## Populates additional_rooms with RequiredRoomLink entries for each required room.
## If max_depth is reached, returns false and prevents the entire room chain from being placed.
func _validate_required_connections_recursive(
	placement: PlacedRoom,
	unsatisfied: Array[MetaRoom.ConnectionPoint],
	additional_rooms: Array[RequiredRoomLink],
	depth: int,
	max_depth: int
) -> bool:
	# Prevent infinite recursion - if we reach max depth, fail the entire placement
	# This ensures we don't have overly complex room chains that could cause issues
	if depth >= max_depth:
		return false
	
	# Try to satisfy each unsatisfied connection
	for req_conn in unsatisfied:
		var found = _find_room_for_required_connection(placement, req_conn)
		if found == null:
			return false
		
		additional_rooms.append(RequiredRoomLink.new(placement, req_conn, found))
		_simulate_occupied(found)
		
		# Check if the newly placed room also has required connections
		var new_required = found.room.get_required_connection_points()
		if not new_required.is_empty():
			# Find which connection is the incoming one (from placement to found)
			var incoming_dir = MetaCell.opposite_direction(req_conn.direction)
			
			# Collect unsatisfied connections for the new room
			var new_unsatisfied: Array[MetaRoom.ConnectionPoint] = []
			var connections_viable := true
			for new_req_conn in new_required:
				if new_req_conn.direction == incoming_dir:
					continue
				var conn_world_pos = found.get_cell_world_pos(new_req_conn.x, new_req_conn.y)
				if occupied_cells.has(conn_world_pos):
					var existing_pl = occupied_cells[conn_world_pos]
					var existing_c = _get_cell_at_world_pos(existing_pl, conn_world_pos)
					if existing_c != null and existing_c.has_connection(MetaCell.opposite_direction(new_req_conn.direction)):
						additional_rooms.append(RequiredRoomLink.new(found, new_req_conn, existing_pl, false))
						continue  # Already satisfied – track for PASSAGE marking, no new room needed
					# Occupied without matching connection – this chain is not viable
					connections_viable = false
					break
				new_unsatisfied.append(new_req_conn)
			if not connections_viable:
				return false
			
			# Recursively validate the new room's requirements
			if not new_unsatisfied.is_empty():
				var success = _validate_required_connections_recursive(
					found, new_unsatisfied, additional_rooms, depth + 1, max_depth
				)
				if not success:
					return false
	
	return true


## Finds a normal (non-connection) room template+rotation that can connect to the given
## required connection point. Only normal rooms are allowed next to connection rooms.
## Returns null if no valid room is found.
func _find_room_for_required_connection(
	from_placement: PlacedRoom,
	req_conn: MetaRoom.ConnectionPoint
) -> PlacedRoom:
	var rotations = RoomRotator.get_all_rotations()
	for template in room_templates:
		# Connection rooms must only connect to normal rooms, never to other connection rooms
		if template.is_connection_room():
			continue
		for rotation in rotations:
			var rotated = RoomRotator.rotate_room(template, rotation)
			var candidate = _try_connect_room(from_placement, req_conn, rotated, rotation, template)
			if candidate != null:
				return candidate
	return null


## Gets the offset vector for a direction
func _get_direction_offset(direction: MetaCell.Direction) -> Vector2i:
	match direction:
		MetaCell.Direction.UP:
			return Vector2i(0, -1)
		MetaCell.Direction.RIGHT:
			return Vector2i(1, 0)
		MetaCell.Direction.BOTTOM:
			return Vector2i(0, 1)
		MetaCell.Direction.LEFT:
			return Vector2i(-1, 0)
	return Vector2i.ZERO


## Gets a random room template that has connections and is not a connection room.
## Connection rooms (T, L, I) cannot be the starting room.
func _get_random_room_with_connections() -> MetaRoom:
	var valid_rooms: Array[MetaRoom] = []
	
	for template in room_templates:
		if template.has_connection_points() and not template.is_connection_room():
			valid_rooms.append(template)
	
	if valid_rooms.is_empty():
		return null
	
	return valid_rooms[randi() % valid_rooms.size()]


## Clears all generated dungeon data
func clear_dungeon() -> void:
	placed_rooms.clear()
	occupied_cells.clear()
	active_walkers.clear()
	next_walker_id = 0
	boss_room = null


## Gets the bounds of the generated dungeon
func get_dungeon_bounds() -> Rect2i:
	if placed_rooms.is_empty():
		return Rect2i(0, 0, 0, 0)
	
	# Initialize with first cell position
	var first_placement = placed_rooms[0]
	var first_pos = first_placement.get_cell_world_pos(0, 0)
	var min_pos = first_pos
	var max_pos = first_pos
	
	for placement in placed_rooms:
		for y in range(placement.room.height):
			for x in range(placement.room.width):
				var world_pos = placement.get_cell_world_pos(x, y)
				min_pos.x = mini(min_pos.x, world_pos.x)
				min_pos.y = mini(min_pos.y, world_pos.y)
				max_pos.x = maxi(max_pos.x, world_pos.x)
				max_pos.y = maxi(max_pos.y, world_pos.y)
	
	return Rect2i(min_pos, max_pos - min_pos + Vector2i.ONE)


## Gets the center of mass of the dungeon (for compactness)
func _get_dungeon_center() -> Vector2:
	if placed_rooms.is_empty():
		return Vector2.ZERO
	
	var sum_pos = Vector2.ZERO
	var count = 0
	
	for placement in placed_rooms:
		sum_pos += Vector2(placement.position)
		count += 1
	
	return sum_pos / count if count > 0 else Vector2.ZERO


## Sort connections by distance to dungeon center (for compactness)
## Closer to center = higher priority when compactness_bias is high
func _sort_connections_by_compactness(from_room: PlacedRoom, connections: Array[MetaRoom.ConnectionPoint]) -> Array[MetaRoom.ConnectionPoint]:
	var center = _get_dungeon_center()
	var scored_connections: Array = []
	
	for conn in connections:
		var conn_world_pos = from_room.get_cell_world_pos(conn.x, conn.y)
		var adjacent_pos = conn_world_pos + _get_direction_offset(conn.direction)
		var dist_to_center = Vector2(adjacent_pos).distance_to(center)
		
		# Apply bias: lower score = higher priority
		var score = dist_to_center
		if randf() > compactness_bias:
			# Sometimes ignore compactness for variety
			score = randf() * 1000.0
		
		scored_connections.append({"connection": conn, "score": score})
	
	# Sort by score (ascending = closer to center first)
	scored_connections.sort_custom(func(a, b): return a.score < b.score)
	
	# Extract sorted connections
	var sorted: Array[MetaRoom.ConnectionPoint] = []
	for item in scored_connections:
		sorted.append(item.connection)
	
	return sorted


## Gets a random room with open connections, preferring rooms closer to the dungeon center
## This improves compactness by reducing long teleports
func _get_random_room_with_open_connections_compact() -> PlacedRoom:
	var rooms_with_open: Array[PlacedRoom] = []
	
	for placement in placed_rooms:
		var open_connections = _get_open_connections(placement)
		if not open_connections.is_empty():
			rooms_with_open.append(placement)
	
	# Otherwise, pick based on compactness
	if rooms_with_open.is_empty():
		return null
	
	# Apply compactness bias
	if compactness_bias > 0 and randf() < compactness_bias:
		var center = _get_dungeon_center()
		# Sort rooms by distance to center, then pick randomly from the closest quarter.
		# This maintains compactness bias while preventing all walkers from teleporting
		# to the exact same room every time.
		var scored: Array = []
		for room in rooms_with_open:
			scored.append({room = room, dist = Vector2(room.position).distance_to(center)})
		scored.sort_custom(func(a, b): return a.dist < b.dist)
		var pick_count := mini(scored.size(), maxi(2, scored.size() / 4))
		return scored[randi() % pick_count].room
	
	# Random selection
	return rooms_with_open[randi() % rooms_with_open.size()]


# ---------------------------------------------------------------------------
# Boss room placement
# ---------------------------------------------------------------------------

## Places the boss room at the farthest reachable room from the entrance.
## Uses BFS on the room graph to find the room with the greatest graph distance
## from the first placed room (entrance at Vector2i.ZERO), then tries to connect
## the boss room template at an open connection of that room.
## Falls back to the next-farthest rooms if placement fails.
func _place_boss_room() -> void:
	if boss_room_template == null:
		return

	# Build the room graph after passages are resolved
	var room_graph: Dictionary = _build_room_graph()

	# BFS from the entrance (first placed room) to find rooms sorted by distance
	var entrance_pos: Vector2i = placed_rooms[0].position
	var rooms_by_distance: Array[Vector2i] = _bfs_rooms_by_distance(entrance_pos, room_graph)

	# Try to place boss room starting from the farthest room
	var rotations = RoomRotator.get_all_rotations()
	for i in range(rooms_by_distance.size() - 1, -1, -1):
		var target_pos: Vector2i = rooms_by_distance[i]

		# Find the PlacedRoom at this position
		var target_room: PlacedRoom = null
		for pl in placed_rooms:
			if pl.position == target_pos:
				target_room = pl
				break
		if target_room == null:
			continue

		var open_conns = _get_open_connections(target_room)
		if open_conns.is_empty():
			continue

		open_conns.shuffle()
		for conn_point in open_conns:
			rotations.shuffle()
			for rotation in rotations:
				var rotated_room = RoomRotator.rotate_room(boss_room_template, rotation)
				var placement = _try_connect_room(target_room, conn_point, rotated_room, rotation, boss_room_template)
				if placement != null:
					_place_room(placement)
					_mark_passage_at_connection(target_room, conn_point, placement)
					boss_room = placement
					boss_room_placed.emit(placement)
					print("DungeonGenerator: Boss room placed at ", placement.position, " (graph index from entrance: ", i, " of ", rooms_by_distance.size(), " rooms)")
					return

	push_warning("DungeonGenerator: Could not place boss room — no suitable connection found")


## BFS traversal from a starting room position through the room graph.
## Returns an array of room positions ordered by ascending graph distance.
func _bfs_rooms_by_distance(start_pos: Vector2i, room_graph: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_pos]
	visited[start_pos] = true

	while not queue.is_empty():
		var room_pos: Vector2i = queue.pop_front()
		result.append(room_pos)

		if not room_graph.has(room_pos):
			continue
		for neighbor: Vector2i in (room_graph[room_pos] as Dictionary).keys():
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)

	return result


# ---------------------------------------------------------------------------
# Post-processing: POTENTIAL_PASSAGE resolution via Dead-End Depth
# ---------------------------------------------------------------------------

## Resolves all remaining POTENTIAL_PASSAGE cells after meta-room generation.
##
## Every remaining POTENTIAL_PASSAGE group is an optional loop shortcut because
## the walker algorithm already guarantees full dungeon connectivity.
## The decision uses the dead-end depth of both sides of the potential passage:
##
##   depth_a = longest dead-end chain reachable from the room adjacent on side A
##   depth_b = longest dead-end chain reachable from the room adjacent on side B
##
##   depth_a >= min_loop_dead_end_depth AND depth_b >= min_loop_dead_end_depth
##     → PASSAGE  (meaningful shortcut rescuing deep dead-end arms on both sides)
##   otherwise
##     → BLOCKED with probability (1 - loop_passage_chance)
##       (trivial loop; only opened by chance for occasional variety)
##
##   Components touching fewer than 2 distinct rooms → always BLOCKED (dead-end stub).
##
## Emits passages_resolved(opened_count, blocked_count) when done.
func resolve_potential_passages() -> void:
	var potential_cells: Dictionary = _collect_potential_passage_cells()

	if potential_cells.is_empty():
		passages_resolved.emit(0, 0)
		return

	var components: Array = _find_passage_components(potential_cells)
	var room_graph: Dictionary = _build_room_graph()

	var opened_count: int = 0
	var blocked_count: int = 0

	for i: int in range(components.size()):
		var component: Array[Vector2i] = components[i]
		var component_set: Dictionary = {}
		for pos: Vector2i in component:
			component_set[pos] = true

		var room_ids: Array = _find_adjacent_room_ids(component, component_set)

		var should_open: bool
		if room_ids.size() < 2:
			# Dead-end stub: no two distinct rooms to connect → always block
			should_open = false
		else:
			var depth_a: int = _get_dead_end_depth(room_ids[0], room_graph)
			var depth_b: int = _get_dead_end_depth(room_ids[1], room_graph)
			if depth_a >= min_loop_dead_end_depth and depth_b >= min_loop_dead_end_depth:
				# Both sides have deep dead-end arms → open the shortcut
				should_open = true
			else:
				# Trivial loop → open only by chance
				should_open = randf() < loop_passage_chance

		_apply_passage_decision(component, potential_cells, should_open)

		if should_open:
			opened_count += 1
		else:
			blocked_count += 1

	passages_resolved.emit(opened_count, blocked_count)
	print("DungeonGenerator: Passage resolution (dead-end depth) — opened: %d, blocked: %d groups" % [opened_count, blocked_count])


## Collects all POTENTIAL_PASSAGE cells from every placed room.
## Returns: Vector2i (world pos) -> Array[{placement, x, y}]
## A world position can have entries from two placements (blocked-cell overlap).
func _collect_potential_passage_cells() -> Dictionary:
	var result: Dictionary = {}

	for placement: PlacedRoom in placed_rooms:
		for y in range(placement.room.height):
			for x in range(placement.room.width):
				var cell: MetaCell = placement.room.get_cell(x, y)
				if cell == null or cell.cell_type != MetaCell.CellType.POTENTIAL_PASSAGE:
					continue
				var world_pos: Vector2i = placement.get_cell_world_pos(x, y)
				if not result.has(world_pos):
					result[world_pos] = []
				result[world_pos].append({"placement": placement, "x": x, "y": y})

	return result


## Groups POTENTIAL_PASSAGE cells into 4-connected components via BFS flood-fill.
## Returns an Array of components; each component is an Array[Vector2i].
func _find_passage_components(potential_cells: Dictionary) -> Array:
	var visited: Dictionary = {}
	var components: Array = []

	for start_pos: Vector2i in potential_cells.keys():
		if visited.has(start_pos):
			continue

		var component: Array[Vector2i] = []
		var queue: Array[Vector2i] = [start_pos]

		while not queue.is_empty():
			var pos: Vector2i = queue.pop_front()
			if visited.has(pos) or not potential_cells.has(pos):
				continue
			visited[pos] = true
			component.append(pos)
			for direction: MetaCell.Direction in DIRECTIONS:
				queue.append(pos + _get_direction_offset(direction))

		if not component.is_empty():
			components.append(component)

	return components


## Returns the unique room positions (Vector2i, used as node IDs) for every PlacedRoom
## whose FLOOR or PASSAGE cells are directly adjacent to the given component.
## component_set is a pre-built Dictionary of the component's world positions for O(1) lookup.
func _find_adjacent_room_ids(component: Array[Vector2i], component_set: Dictionary) -> Array:
	var found: Dictionary = {}
	for pos: Vector2i in component:
		for direction: MetaCell.Direction in DIRECTIONS:
			var neighbor: Vector2i = pos + _get_direction_offset(direction)
			if component_set.has(neighbor) or not occupied_cells.has(neighbor):
				continue
			var pl: PlacedRoom = occupied_cells[neighbor]
			var cell: MetaCell = _get_cell_at_world_pos(pl, neighbor)
			if cell != null and (cell.cell_type == MetaCell.CellType.FLOOR or cell.cell_type == MetaCell.CellType.PASSAGE):
				found[pl.position] = true
	return found.keys()


## Applies the PASSAGE or BLOCKED decision to every cell in a component.
## Updates all placements that own a cell at each world position in the component.
func _apply_passage_decision(component: Array[Vector2i], potential_cells: Dictionary, open: bool) -> void:
	var new_type: MetaCell.CellType = MetaCell.CellType.PASSAGE if open else MetaCell.CellType.BLOCKED

	for world_pos: Vector2i in component:
		if not potential_cells.has(world_pos):
			continue
		for entry: Dictionary in potential_cells[world_pos]:
			var cell: MetaCell = (entry["placement"] as PlacedRoom).room.get_cell(entry["x"], entry["y"])
			if cell != null and cell.cell_type == MetaCell.CellType.POTENTIAL_PASSAGE:
				cell.cell_type = new_type


## Builds the confirmed room adjacency graph from PASSAGE cells only.
## Two placements are connected when they both own a PASSAGE cell at the same world position.
## Returns: Dictionary(room_pos: Vector2i → Dictionary(neighbor_pos: Vector2i → true))
func _build_room_graph() -> Dictionary:
	var graph: Dictionary = {}
	for pl: PlacedRoom in placed_rooms:
		if not graph.has(pl.position):
			graph[pl.position] = {}

	# Map each world position that has a PASSAGE cell to every placement that owns it.
	var pos_to_rooms: Dictionary = {}
	for placement: PlacedRoom in placed_rooms:
		for y in range(placement.room.height):
			for x in range(placement.room.width):
				var cell: MetaCell = placement.room.get_cell(x, y)
				if cell == null or cell.cell_type != MetaCell.CellType.PASSAGE:
					continue
				var world_pos: Vector2i = placement.get_cell_world_pos(x, y)
				if not pos_to_rooms.has(world_pos):
					pos_to_rooms[world_pos] = []
				pos_to_rooms[world_pos].append(placement.position)

	# Each world position shared by 2+ placements creates an edge in the graph.
	for world_pos: Vector2i in pos_to_rooms:
		var room_list: Array = pos_to_rooms[world_pos]
		for i in range(room_list.size()):
			for j in range(i + 1, room_list.size()):
				var a: Vector2i = room_list[i]
				var b: Vector2i = room_list[j]
				if not graph.has(a):
					graph[a] = {}
				if not graph.has(b):
					graph[b] = {}
				graph[a][b] = true
				graph[b][a] = true

	return graph


## Returns the maximum dead-end chain depth reachable from start_id in room_graph.
## Traversal follows rooms with degree <= 2 (dead ends and corridors).
## At depth > 0, rooms with degree > 2 (junctions / hubs) end the chain without counting.
## This measures how many rooms deep a player would be trapped in a dead-end arm.
##
## Uses a DFS with a best_depth table: rooms can be revisited if a greater depth is found,
## ensuring the true maximum is always discovered. parent_id (null for the start node)
## prevents backtracking to the immediate predecessor so the search stays directional.
func _get_dead_end_depth(start_id: Vector2i, room_graph: Dictionary) -> int:
	if not room_graph.has(start_id):
		return 0
	var max_depth: int = 0
	# DFS stack: [room_id, parent_id (null or Vector2i), depth]
	# Rooms may be pushed multiple times; best_depth ensures we only do useful work.
	var stack: Array = [[start_id, null, 0]]
	# Track the deepest depth at which each room was processed.
	# A room is reprocessed only when a greater depth is found, guaranteeing the true maximum.
	var best_depth: Dictionary = {}

	while not stack.is_empty():
		var entry: Array = stack.pop_back()
		var room_id: Vector2i = entry[0]
		var parent_id = entry[1]  # null (start) or Vector2i (predecessor)
		var depth: int = entry[2]

		# Skip if we already processed this room at an equal or greater depth.
		if best_depth.has(room_id) and best_depth[room_id] >= depth:
			continue
		best_depth[room_id] = depth

		var degree: int = room_graph[room_id].size()

		# At depth > 0, stop traversal when we hit a junction (hub room).
		# The junction is not counted — it marks the boundary of the dead-end arm.
		if depth > 0 and degree > 2:
			continue

		max_depth = maxi(max_depth, depth)

		for neighbor_id: Vector2i in (room_graph[room_id] as Dictionary).keys():
			if neighbor_id != parent_id:
				stack.append([neighbor_id, room_id, depth + 1])

	return max_depth

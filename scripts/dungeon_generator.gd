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

## Maximum recursion depth when validating required connections
## Limits how many chained required connections can be validated
## Higher values allow more complex room chains but may impact performance
const MAX_REQUIRED_CONNECTION_DEPTH: int = 3

## List of all placed rooms in the dungeon
var placed_rooms: Array[PlacedRoom] = []

## Grid of occupied cells (for collision detection)
var occupied_cells: Dictionary = {}  # Vector2i -> PlacedRoom

## Active walkers during generation
var active_walkers: Array[Walker] = []

## Counter for assigning unique walker IDs
var next_walker_id: int = 0


## Signal emitted when generation completes
## Parameters: success (bool), room_count (int), cell_count (int)
## Note: cell_count parameter added in multi-walker version
signal generation_complete(success: bool, room_count: int, cell_count: int)

## Signal emitted when a room is placed (for visualization)
## Parameters: placement (PlacedRoom), walker (Walker)
signal room_placed(placement: PlacedRoom, walker: Walker)

## Signal emitted when a walker moves or spawns (for visualization)
## Parameters: walker (Walker), from_position (Vector2i), to_position (Vector2i), is_teleport (bool)
signal walker_moved(walker: Walker, from_pos: Vector2i, to_pos: Vector2i, is_teleport: bool)

## Signal emitted at each generation step (for visualization)
## Parameters: iteration (int), total_cells (int)
signal generation_step(iteration: int, total_cells: int)


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
	
	# 50% chance to spawn at current position if it has open connections
	# 50% chance to spawn at a random other room
	var should_spawn_at_current_position = randf() < 0.5
	
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

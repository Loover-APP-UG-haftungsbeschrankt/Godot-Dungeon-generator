extends Node2D

## DungeonVisualizer renders the generated dungeon to the screen.
## It draws cells as colored rectangles for easy visualization.
## Now includes walker visualization and path tracking.

@export var cell_size: int = 32
@export var draw_grid: bool = true
@export var draw_connections: bool = true
@export var draw_walkers: bool = true
@export var draw_walker_paths: bool = true
@export var path_line_width: float = 4.0
@export var draw_step_numbers: bool = true
@export var step_number_interval: int = 5  # Show number every N steps

var generator: DungeonGenerator
var cached_cell_count: int = 0
var cached_active_walker_count: int = 0  # Cache active walker count
var walker_positions: Dictionary = {}  # walker_id -> current position
var visible_walker_paths: Dictionary = {}  # walker_id -> bool (which paths to show)


func _ready() -> void:
	# Find the DungeonGenerator node
	generator = get_node_or_null("../DungeonGenerator")
	if generator == null:
		push_error("DungeonVisualizer: Could not find DungeonGenerator node")
		return
	
	# Connect to generation signals
	generator.generation_complete.connect(_on_generation_complete)
	generator.room_placed.connect(_on_room_placed)
	generator.walker_moved.connect(_on_walker_moved)
	generator.generation_step.connect(_on_generation_step)
	
	# Initialize visible walker paths (all enabled by default)
	_initialize_visible_walker_paths()
	
	# Generate dungeon on start
	_generate_and_visualize()


func _generate_and_visualize() -> void:
	print("\n=== Generating Dungeon ===")
	var success = await generator.generate()
	if success:
		print("Generation successful! Rooms placed: ", generator.placed_rooms.size())
		_initialize_visible_walker_paths()
		queue_redraw()
	else:
		print("Generation failed or incomplete")


func _on_generation_complete(success: bool, room_count: int, cell_count: int) -> void:
	print("Dungeon generation complete. Success: ", success, ", Rooms: ", room_count, ", Cells: ", cell_count)
	cached_cell_count = cell_count
	_update_walker_count()
	queue_redraw()


func _on_room_placed(placement: DungeonGenerator.PlacedRoom, walker: DungeonGenerator.Walker) -> void:
	# Update visualization when a room is placed
	queue_redraw()


func _on_walker_moved(walker: DungeonGenerator.Walker, from_pos: Vector2i, to_pos: Vector2i) -> void:
	# Track walker position for visualization
	walker_positions[walker.walker_id] = to_pos
	_update_walker_count()
	queue_redraw()


func _on_generation_step(iteration: int, total_cells: int) -> void:
	# Update cached cell count during generation
	cached_cell_count = total_cells


## Update the cached active walker count
func _update_walker_count() -> void:
	cached_active_walker_count = 0
	for walker in generator.active_walkers:
		if walker.is_alive:
			cached_active_walker_count += 1


## Initialize visible walker paths dictionary based on active walkers
func _initialize_visible_walker_paths() -> void:
	visible_walker_paths.clear()
	if generator == null:
		return
	for walker in generator.active_walkers:
		visible_walker_paths[walker.walker_id] = true


## Get the center position of a room in world coordinates
func _get_room_center_pos(room_pos: Vector2i, room: MetaRoom) -> Vector2:
	# Calculate center based on actual room dimensions
	var center_offset = Vector2(room.width, room.height) * 0.5
	return Vector2(room_pos) + center_offset


func _draw() -> void:
	if generator == null or generator.placed_rooms.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(10, 30), "No dungeon generated yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
		return
	
	# Get dungeon bounds for centering
	var bounds = generator.get_dungeon_bounds()
	var offset = -Vector2(bounds.position) * cell_size + Vector2(50, 50)
	
	# Draw each placed room
	for placement in generator.placed_rooms:
		_draw_room(placement, offset)
		
	
	# Draw walker paths first (below rooms)
	if draw_walker_paths:
		_draw_walker_paths(offset)
	
	# Draw walkers on top
	if draw_walkers:
		_draw_walkers(offset)
		
	
	# Draw statistics
	_draw_statistics(bounds)


func _draw_walker_paths(offset: Vector2) -> void:
	for walker in generator.active_walkers:
		# Check if this walker's path should be visible
		if not visible_walker_paths.get(walker.walker_id, true):
			continue
			
		if walker.path_history.size() < 2:
			continue
		
		# Draw path as connected lines
		for i in range(walker.path_history.size() - 1):
			var from_room_pos = walker.path_history[i]
			var to_room_pos = walker.path_history[i + 1]
			
			# Find the rooms at these positions to get their centers
			var from_room = _find_room_at_position(from_room_pos)
			var to_room = _find_room_at_position(to_room_pos)
			
			if from_room == null or to_room == null:
				continue
			
			# Calculate center positions in screen space
			var from_center = _get_room_center_pos(from_room_pos, from_room.room)
			var to_center = _get_room_center_pos(to_room_pos, to_room.room)
			
			var from_pos = from_center * cell_size + offset
			var to_pos = to_center * cell_size + offset
			
			# Fade older path segments
			var alpha = 0.2 + (float(i) / walker.path_history.size()) * 0.5
			var path_color = walker.color
			path_color.a = alpha
			
			# Check if this is a teleport (non-adjacent rooms)
			var is_teleport = _is_teleport_move(from_room_pos, to_room_pos)
			
			if is_teleport:
				# Draw dotted line for teleports
				_draw_dashed_line(from_pos, to_pos, path_color, path_line_width * 0.7, 10.0, 10.0)
			else:
				# Draw solid line for normal moves
				draw_line(from_pos, to_pos, path_color, path_line_width)
			
			# Draw step numbers at intervals
			if draw_step_numbers and i % step_number_interval == 0:
				var step_pos = from_pos
				_draw_step_number(step_pos, i, walker.color)


## Check if a move between two positions is a teleport (non-adjacent)
func _is_teleport_move(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	var delta = to_pos - from_pos
	var manhattan_dist = abs(delta.x) + abs(delta.y)
	# Adjacent rooms have manhattan distance <= max room dimension
	# For simplicity, if distance > 10, consider it a teleport
	return manhattan_dist > 10


## Draw a dashed/dotted line
func _draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float, dash_length: float, gap_length: float) -> void:
	var direction = (to - from).normalized()
	var distance = from.distance_to(to)
	var current_pos = from
	var traveled = 0.0
	var draw_dash = true
	
	while traveled < distance:
		var segment_length = dash_length if draw_dash else gap_length
		var next_traveled = min(traveled + segment_length, distance)
		var next_pos = from + direction * next_traveled
		
		if draw_dash:
			draw_line(current_pos, next_pos, color, width)
		
		current_pos = next_pos
		traveled = next_traveled
		draw_dash = !draw_dash


## Draw a step number at a position
func _draw_step_number(pos: Vector2, step: int, color: Color) -> void:
	# Draw a small circle background
	var bg_color = Color.BLACK
	bg_color.a = 0.7
	draw_circle(pos, 12, bg_color)
	
	# Draw the step number
	var text = str(step)
	var font = ThemeDB.fallback_font
	var font_size = 12
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, pos - text_size * 0.5 + Vector2(0, font_size * 0.3), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


## Find a placed room at a given position
func _find_room_at_position(pos: Vector2i) -> DungeonGenerator.PlacedRoom:
	for placement in generator.placed_rooms:
		if placement.position == pos:
			return placement
	return null


func _draw_walkers(offset: Vector2) -> void:
	for walker in generator.active_walkers:
		if not walker.is_alive:
			continue
		
		# Find the room to get its dimensions
		var room = _find_room_at_position(walker.current_room.position)
		if room == null:
			continue
		
		# Calculate walker position at center of room
		var room_center = _get_room_center_pos(walker.current_room.position, room.room)
		var walker_pos = room_center * cell_size + offset
		
		# Draw walker as a colored circle
		draw_circle(walker_pos, cell_size * 0.5, walker.color)
		
		# Draw walker outline
		draw_arc(walker_pos, cell_size * 0.5, 0, TAU, 32, Color.WHITE, 2.5)
		
		# Draw walker ID text
		var id_text = str(walker.walker_id)
		var font = ThemeDB.fallback_font
		var font_size = 18
		var text_size = font.get_string_size(id_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, walker_pos - text_size * 0.5 + Vector2(0, font_size * 0.35), id_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)


func _draw_room(placement: DungeonGenerator.PlacedRoom, offset: Vector2) -> void:
	var room = placement.room
	
	for y in range(room.height):
		for x in range(room.width):
			var cell = room.get_cell(x, y)
			if cell == null:
				continue
			
			var world_pos = placement.get_cell_world_pos(x, y)
			var screen_pos = Vector2(world_pos) * cell_size + offset
			
			# Draw cell based on type
			var color: Color
			match cell.cell_type:
				MetaCell.CellType.FLOOR:
					color = Color(0.3, 0.3, 0.4)
				MetaCell.CellType.DOOR:
					color = Color(0.6, 0.4, 0.2)
				MetaCell.CellType.BLOCKED:
					color = Color(0.1, 0.1, 0.1)
			
			# Draw cell rectangle
			draw_rect(Rect2(screen_pos, Vector2(cell_size, cell_size)), color, true)
			
			# Draw grid lines
			if draw_grid:
				draw_rect(Rect2(screen_pos, Vector2(cell_size, cell_size)), Color(0.2, 0.2, 0.2), false, 1.0)
			
			# Draw connections
			if draw_connections and cell.cell_type != MetaCell.CellType.BLOCKED:
				_draw_cell_connections(cell, screen_pos)


func _draw_cell_connections(cell: MetaCell, screen_pos: Vector2) -> void:
	var center = screen_pos + Vector2(cell_size, cell_size) * 0.5
	var line_length = cell_size * 0.3
	var connection_color = Color(0.8, 0.8, 0.2)
	var line_width = 2.0
	
	if cell.connection_up:
		draw_line(center, center + Vector2(0, -line_length), connection_color, line_width)
	if cell.connection_right:
		draw_line(center, center + Vector2(line_length, 0), connection_color, line_width)
	if cell.connection_bottom:
		draw_line(center, center + Vector2(0, line_length), connection_color, line_width)
	if cell.connection_left:
		draw_line(center, center + Vector2(-line_length, 0), connection_color, line_width)


func _draw_statistics(bounds: Rect2i) -> void:
	var stats_pos = Vector2(10, 30)
	var line_height = 20
	var font = ThemeDB.fallback_font
	var font_size = 14
	
	var stats = [
		"Rooms: %d" % generator.placed_rooms.size(),
		"Cells: %d / %d" % [cached_cell_count, generator.target_meta_cell_count],
		"Bounds: %d x %d" % [bounds.size.x, bounds.size.y],
		"Active Walkers: %d / %d" % [cached_active_walker_count, generator.num_walkers],
		"Compactness Bias: %.1f" % generator.compactness_bias,
		"Seed: %d" % generator.generation_seed
	]
	
	for i in range(stats.size()):
		draw_string(font, stats_pos + Vector2(0, i * line_height), stats[i], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			# Regenerate with same seed
			_generate_and_visualize()
		elif event.keycode == KEY_S:
			# Generate with new random seed
			generator.generation_seed = randi()
			_generate_and_visualize()
		elif event.keycode == KEY_W:
			# Toggle walker visualization
			draw_walkers = !draw_walkers
			queue_redraw()
			print("Walker visualization: ", "ON" if draw_walkers else "OFF")
		elif event.keycode == KEY_P:
			# Toggle path visualization
			draw_walker_paths = !draw_walker_paths
			queue_redraw()
			print("Path visualization: ", "ON" if draw_walker_paths else "OFF")
		elif event.keycode == KEY_N:
			# Toggle step numbers
			draw_step_numbers = !draw_step_numbers
			queue_redraw()
			print("Step numbers: ", "ON" if draw_step_numbers else "OFF")
		elif event.keycode == KEY_V:
			# Toggle step-by-step visualization
			generator.enable_visualization = !generator.enable_visualization
			print("Step-by-step visualization: ", "ON" if generator.enable_visualization else "OFF")
		elif event.keycode == KEY_C:
			# Increase compactness bias
			generator.compactness_bias = min(1.0, generator.compactness_bias + 0.1)
			print("Compactness bias: %.1f" % generator.compactness_bias)
			queue_redraw()
		elif event.keycode == KEY_X:
			# Decrease compactness bias
			generator.compactness_bias = max(0.0, generator.compactness_bias - 0.1)
			print("Compactness bias: %.1f" % generator.compactness_bias)
			queue_redraw()
		elif event.keycode >= KEY_0 and event.keycode <= KEY_9:
			# Toggle visibility of specific walker path (0-9)
			var walker_id = event.keycode - KEY_0
			if visible_walker_paths.has(walker_id):
				visible_walker_paths[walker_id] = !visible_walker_paths[walker_id]
				queue_redraw()
				print("Walker %d path: %s" % [walker_id, "ON" if visible_walker_paths[walker_id] else "OFF"])

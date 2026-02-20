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
@export var draw_return_indicators: bool = true  # Show when walker returns to visited room
@export var teleport_dash_length: float = 10.0  # Length of dashes in teleport lines
@export var teleport_gap_length: float = 10.0  # Length of gaps in teleport lines
@export var step_marker_radius: float = 14.0  # Radius of step number circle markers

var generator: DungeonGenerator
var cached_cell_count: int = 0
var cached_active_walker_count: int = 0  # Cache active walker count
var cached_passages_opened: int = 0       # Passage groups opened in last resolution
var cached_passages_blocked: int = 0      # Passage groups blocked in last resolution
var walker_positions: Dictionary = {}  # walker_id -> current position
var visible_walker_paths: Dictionary = {}  # walker_id -> bool (which paths to show)
var room_position_cache: Dictionary = {}  # Vector2i -> PlacedRoom (for O(1) lookups)
var walker_checkboxes: Dictionary = {}  # walker_id -> CheckBox node
var walker_teleports: Dictionary = {}  # walker_id -> Array[bool] (is each segment a teleport)
var mouse_position_label: Label  # Label for displaying mouse grid position
var camera: Camera2D  # Reference to the camera for coordinate conversion

# Constants for text positioning
const TEXT_VERTICAL_OFFSET_FACTOR = 0.35  # Vertical centering factor for text in circles
const STEP_TEXT_FONT_SIZE = 13  # Font size for step numbers


func _ready() -> void:
	# Find the DungeonGenerator node
	generator = get_node_or_null("../DungeonGenerator")
	if generator == null:
		push_error("DungeonVisualizer: Could not find DungeonGenerator node")
		return
	
	# Get reference to camera for coordinate conversion
	camera = get_node_or_null("../Camera2D")
	if camera == null:
		push_warning("DungeonVisualizer: Could not find Camera2D node")
	
	# Get reference to mouse position label
	mouse_position_label = get_node_or_null("../CanvasLayer/MousePositionLabel")
	if mouse_position_label == null:
		push_warning("DungeonVisualizer: Could not find MousePositionLabel")
	
	# Connect to generation signals
	generator.generation_complete.connect(_on_generation_complete)
	generator.room_placed.connect(_on_room_placed)
	generator.walker_moved.connect(_on_walker_moved)
	generator.generation_step.connect(_on_generation_step)
	generator.passages_resolved.connect(_on_passages_resolved)
	
	# Connect toggle all button
	var toggle_all_button = get_node_or_null("../CanvasLayer/WalkerSelectionPanel/MarginContainer/VBoxContainer/ToggleAllButton")
	if toggle_all_button:
		toggle_all_button.pressed.connect(_on_toggle_all_pressed)
	
	# Initialize visible walker paths (all enabled by default)
	_initialize_visible_walker_paths()
	
	# Generate dungeon on start
	_generate_and_visualize()


func _process(_delta: float) -> void:
	# Update mouse position label
	_update_mouse_position_label()


func _update_mouse_position_label() -> void:
	if mouse_position_label == null or camera == null or generator == null:
		return
	
	if generator.placed_rooms.is_empty():
		mouse_position_label.text = "Cell: -"
		return
	
	# Get mouse position in screen space
	var mouse_screen_pos = get_viewport().get_mouse_position()
	
	# Convert to world space using camera
	var mouse_world_pos = camera.get_global_mouse_position()
	
	# Calculate the same offset used in _draw()
	var bounds = generator.get_dungeon_bounds()
	var offset = -Vector2(bounds.position) * cell_size + Vector2(50, 50)
	
	# Convert world position to grid position
	# Reverse the transformation: world_pos = grid_pos * cell_size + offset
	# So: grid_pos = (world_pos - offset) / cell_size
	var grid_pos = (mouse_world_pos - offset) / cell_size
	var grid_pos_int = Vector2i(int(floor(grid_pos.x)), int(floor(grid_pos.y)))
	
	# Update label text
	mouse_position_label.text = "Cell: (%d, %d)" % [grid_pos_int.x, grid_pos_int.y]


func _generate_and_visualize() -> void:
	print("\n=== Generating Dungeon ===")
	
	# Clear walker state from previous generation BEFORE starting new generation
	# This prevents old data from interfering with new generation
	_clear_walker_state_for_regeneration()
	
	var success = await generator.generate()
	if success:
		print("Generation successful! Rooms placed: ", generator.placed_rooms.size())
		# Force UI rebuild to show new walkers (don't use conditional update)
		_update_walker_selection_ui()
		queue_redraw()
	else:
		print("Generation failed or incomplete")


func _on_generation_complete(success: bool, room_count: int, cell_count: int) -> void:
	print("Dungeon generation complete. Success: ", success, ", Rooms: ", room_count, ", Cells: ", cell_count)
	cached_cell_count = cell_count
	_update_walker_count()
	_build_room_position_cache()
	queue_redraw()


func _on_passages_resolved(opened: int, blocked: int) -> void:
	cached_passages_opened = opened
	cached_passages_blocked = blocked
	queue_redraw()


func _on_room_placed(placement: DungeonGenerator.PlacedRoom, walker: DungeonGenerator.Walker) -> void:
	# Update room position cache incrementally during generation
	room_position_cache[placement.position] = placement
	# Update visualization when a room is placed
	queue_redraw()


func _on_walker_moved(walker: DungeonGenerator.Walker, from_pos: Vector2i, to_pos: Vector2i, is_teleport: bool) -> void:
	# Track walker position for visualization
	walker_positions[walker.walker_id] = to_pos
	
	# Track whether this move was a teleport
	if not walker_teleports.has(walker.walker_id):
		walker_teleports[walker.walker_id] = []
	walker_teleports[walker.walker_id].append(is_teleport)
	
	_update_walker_count()
	# Update UI if needed (e.g., if new walker spawned during generation)
	_update_walker_selection_ui_if_needed()
	queue_redraw()


func _on_generation_step(iteration: int, total_cells: int) -> void:
	# Update cached cell count during generation
	cached_cell_count = total_cells
	# Redraw to show walker paths and positions during generation
	queue_redraw()


## Update the cached active walker count
func _update_walker_count() -> void:
	cached_active_walker_count = 0
	for walker in generator.active_walkers:
		if walker.is_alive:
			cached_active_walker_count += 1


## Initialize visible walker paths dictionary based on active walkers
func _initialize_visible_walker_paths() -> void:
	visible_walker_paths.clear()
	walker_teleports.clear()
	if generator == null:
		return
	for walker in generator.active_walkers:
		visible_walker_paths[walker.walker_id] = true
		walker_teleports[walker.walker_id] = []


## Clear walker state before regeneration to prevent old data from persisting
func _clear_walker_state_for_regeneration() -> void:
	# Clear teleport tracking (prevents old teleport data from showing on new generation)
	walker_teleports.clear()
	
	# Clear walker positions (old positions no longer valid)
	walker_positions.clear()
	
	# Clear old walker checkboxes from UI
	var checkbox_container = get_node_or_null("../CanvasLayer/WalkerSelectionPanel/MarginContainer/VBoxContainer/WalkerCheckboxContainer")
	if checkbox_container != null:
		for child in checkbox_container.get_children():
			child.queue_free()
	walker_checkboxes.clear()
	
	# Keep visible_walker_paths intact - these are user preferences for which paths to show
	# The user's visibility settings should persist across regenerations


## Build cache of room positions for O(1) lookups
func _build_room_position_cache() -> void:
	room_position_cache.clear()
	if generator == null:
		return
	for placement in generator.placed_rooms:
		room_position_cache[placement.position] = placement


## Update the walker selection UI with checkboxes for each walker
func _update_walker_selection_ui() -> void:
	# Find the checkbox container
	var checkbox_container = get_node_or_null("../CanvasLayer/WalkerSelectionPanel/MarginContainer/VBoxContainer/WalkerCheckboxContainer")
	if checkbox_container == null:
		return
	
	# Track which walker IDs we've seen
	var current_walker_ids: Array = []
	for walker in generator.active_walkers:
		current_walker_ids.append(walker.walker_id)
	
	# Remove checkboxes for walkers that no longer exist
	var to_remove: Array = []
	for walker_id in walker_checkboxes.keys():
		if walker_id not in current_walker_ids:
			to_remove.append(walker_id)
	
	for walker_id in to_remove:
		if walker_checkboxes.has(walker_id):
			var checkbox = walker_checkboxes[walker_id]
			# Find and remove the parent HBoxContainer
			if checkbox != null and checkbox.get_parent() != null:
				var hbox = checkbox.get_parent().get_parent()
				if hbox != null:
					hbox.queue_free()
			walker_checkboxes.erase(walker_id)
	
	# Add or update checkboxes for each walker
	for walker in generator.active_walkers:
		# Initialize visible_walker_paths for new walkers
		if not visible_walker_paths.has(walker.walker_id):
			visible_walker_paths[walker.walker_id] = true
		
		# If checkbox already exists, just update it
		if walker_checkboxes.has(walker.walker_id):
			var checkbox = walker_checkboxes[walker.walker_id]
			# Check if checkbox is still valid (not freed/queued for deletion)
			if checkbox != null and is_instance_valid(checkbox):
				# Update checkbox state if needed (but don't trigger signal)
				if checkbox.button_pressed != visible_walker_paths[walker.walker_id]:
					checkbox.set_pressed_no_signal(visible_walker_paths[walker.walker_id])
			else:
				# Checkbox was freed, remove from dictionary
				walker_checkboxes.erase(walker.walker_id)
				# Continue to create new checkbox below
			continue
		
		# Create new checkbox for new walker
		var checkbox = CheckBox.new()
		checkbox.text = "Walker %d" % walker.walker_id
		checkbox.button_pressed = visible_walker_paths[walker.walker_id]
		
		# Create a color indicator
		var indicator = ColorRect.new()
		indicator.custom_minimum_size = Vector2(16, 16)
		indicator.color = walker.color
		
		var hbox = HBoxContainer.new()
		hbox.add_child(indicator)
		hbox.add_child(checkbox)
		
		checkbox_container.add_child(hbox)
		walker_checkboxes[walker.walker_id] = checkbox
		
		# Connect the toggled signal
		checkbox.toggled.connect(_on_walker_checkbox_toggled.bind(walker.walker_id))


## Update walker selection UI only if walker count changed
func _update_walker_selection_ui_if_needed() -> void:
	# If UI hasn't been built yet (walker_checkboxes is empty but walkers exist), build it
	if walker_checkboxes.is_empty() and not generator.active_walkers.is_empty():
		_update_walker_selection_ui()
	# Otherwise, only update if walker count changed
	elif walker_checkboxes.size() != generator.active_walkers.size():
		_update_walker_selection_ui()


## Handle toggle all button press
func _on_toggle_all_pressed() -> void:
	# Determine if we should enable or disable all
	# If any are disabled, enable all; otherwise disable all
	var any_disabled = false
	for walker_id in visible_walker_paths:
		if not visible_walker_paths[walker_id]:
			any_disabled = true
			break
	
	var new_state = any_disabled  # Enable if any disabled, disable if all enabled
	
	# Toggle all walker paths
	for walker_id in visible_walker_paths:
		visible_walker_paths[walker_id] = new_state
		# Sync with checkbox if it exists and is valid
		if walker_checkboxes.has(walker_id):
			var checkbox = walker_checkboxes[walker_id]
			if checkbox != null and is_instance_valid(checkbox):
				checkbox.button_pressed = new_state
	
	queue_redraw()
	print("All walker paths: %s" % ["ON" if new_state else "OFF"])


## Handle walker checkbox toggle
func _on_walker_checkbox_toggled(button_pressed: bool, walker_id: int) -> void:
	visible_walker_paths[walker_id] = button_pressed
	queue_redraw()
	print("Walker %d path: %s" % [walker_id, "ON" if button_pressed else "OFF"])


## Get the center position of a room in grid coordinates (not world/screen coordinates)
func _get_room_center_grid_pos(room_pos: Vector2i, room: MetaRoom) -> Vector2:
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
		
		# Get the teleport flags for this walker
		var teleport_flags = walker_teleports.get(walker.walker_id, [])
		
		# Track visited positions for this walker to detect returns
		var visited_positions: Dictionary = {}  # Vector2i -> first visit index
		
		# Draw path as connected lines
		for i in range(walker.path_history.size() - 1):
			var from_room_pos = walker.path_history[i]
			var to_room_pos = walker.path_history[i + 1]
			
			# Track visited positions
			if not visited_positions.has(from_room_pos):
				visited_positions[from_room_pos] = i
			
			# Find the rooms at these positions to get their centers
			var from_room = _find_room_at_position(from_room_pos)
			var to_room = _find_room_at_position(to_room_pos)
			
			if from_room == null or to_room == null:
				continue
			
			# Calculate center positions in screen space
			var from_center = _get_room_center_grid_pos(from_room_pos, from_room.room)
			var to_center = _get_room_center_grid_pos(to_room_pos, to_room.room)
			
			var from_pos = from_center * cell_size + offset
			var to_pos = to_center * cell_size + offset
			
			# Fade older path segments
			var alpha = 0.2 + (float(i) / walker.path_history.size()) * 0.5
			var path_color = walker.color
			path_color.a = alpha
			
			# Get exact teleport information for this segment
			# teleport_flags[j] indicates whether the move that created path_history[j] was a teleport
			# So for segment i (from path_history[i] to path_history[i+1]), we use teleport_flags[i+1]
			var is_teleport = false
			if i + 1 < teleport_flags.size():
				is_teleport = teleport_flags[i + 1]
			
			# Check if walker is returning to a previously visited room
			var is_return = visited_positions.has(to_room_pos) and visited_positions[to_room_pos] < i
			
			if is_teleport:
				# Draw dotted line for teleports with fixed 2.0 width
				_draw_dashed_line(from_pos, to_pos, path_color, 2.0, teleport_dash_length, teleport_gap_length)
			else:
				# Draw solid line for normal moves
				var line_width = path_line_width
				# Make return paths slightly thinner
				if is_return and draw_return_indicators:
					line_width *= 0.8
				draw_line(from_pos, to_pos, path_color, line_width)
			
			# Draw step numbers at every room
			if draw_step_numbers:
				_draw_step_number(from_pos, i, walker.color, is_return)


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
func _draw_step_number(pos: Vector2, step: int, color: Color, is_return: bool = false) -> void:
	# Draw a small circle background
	var bg_color = Color.BLACK
	bg_color.a = 0.75
	
	# Make return visits more visible with a different background
	if is_return and draw_return_indicators:
		bg_color = Color.DARK_RED
		bg_color.a = 0.85
	
	draw_circle(pos, step_marker_radius, bg_color)
	
	# Draw outline for return visits
	if is_return and draw_return_indicators:
		draw_arc(pos, step_marker_radius, 0, TAU, 32, color, 2.0)
	
	# Draw the step number with better centering
	var text = str(step)
	var font = ThemeDB.fallback_font
	var font_size = STEP_TEXT_FONT_SIZE
	
	# Get text dimensions for proper centering
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	
	# Calculate centered position
	# Use font ascent and descent for proper vertical centering
	var text_pos = pos - Vector2(text_size.x * 0.5, -font_size * TEXT_VERTICAL_OFFSET_FACTOR)
	
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)


## Find a placed room at a given position using cached lookup (O(1))
func _find_room_at_position(pos: Vector2i) -> DungeonGenerator.PlacedRoom:
	return room_position_cache.get(pos, null)


func _draw_walkers(offset: Vector2) -> void:
	for walker in generator.active_walkers:
		if not walker.is_alive:
			continue
		
		# Find the room to get its dimensions
		var room = _find_room_at_position(walker.current_room.position)
		if room == null:
			continue
		
		# Calculate walker position at center of room
		var room_center = _get_room_center_grid_pos(walker.current_room.position, room.room)
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
		draw_string(font, walker_pos - text_size * 0.5 + Vector2(0, font_size * TEXT_VERTICAL_OFFSET_FACTOR), id_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.BLACK)


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
				MetaCell.CellType.POTENTIAL_PASSAGE:
					color = Color(0.6, 0.4, 0.2)
				MetaCell.CellType.PASSAGE:
					color = Color(0.2, 0.7, 0.3)
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
		"Seed: %d" % generator.generation_seed,
		"Passages: +%d / -%d (chance %.0f%%)" % [cached_passages_opened, cached_passages_blocked, generator.loop_passage_chance * 100]
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
		elif event.keycode == KEY_A:
			# Toggle all walker paths
			_on_toggle_all_pressed()
		elif event.keycode >= KEY_0 and event.keycode <= KEY_9:
			# Toggle visibility of specific walker path (0-9)
			var walker_id = event.keycode - KEY_0
			if visible_walker_paths.has(walker_id):
				visible_walker_paths[walker_id] = !visible_walker_paths[walker_id]
				# Sync with checkbox if it exists and is valid
				if walker_checkboxes.has(walker_id):
					var checkbox = walker_checkboxes[walker_id]
					if checkbox != null and is_instance_valid(checkbox):
						checkbox.button_pressed = visible_walker_paths[walker_id]
				queue_redraw()
				print("Walker %d path: %s" % [walker_id, "ON" if visible_walker_paths[walker_id] else "OFF"])

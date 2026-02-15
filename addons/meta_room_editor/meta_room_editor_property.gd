@tool
extends VBoxContainer

## Visual editor for MetaRoom resources
## Provides a grid-based interface for editing room layouts

var meta_room: MetaRoom
var grid_container: GridContainer
var cell_buttons: Array[Button] = []

# UI Elements
var info_label: Label
var width_spinbox: SpinBox
var height_spinbox: SpinBox
var resize_button: Button

# Cell properties panel
var properties_panel: PanelContainer
var properties_visible: bool = false
var current_selected_cell_x: int = -1
var current_selected_cell_y: int = -1

# Property controls
var prop_cell_type_option: OptionButton
var prop_conn_up_check: CheckBox
var prop_conn_right_check: CheckBox
var prop_conn_bottom_check: CheckBox
var prop_conn_left_check: CheckBox
var prop_conn_up_req_check: CheckBox
var prop_conn_right_req_check: CheckBox
var prop_conn_bottom_req_check: CheckBox
var prop_conn_left_req_check: CheckBox

var _initialized: bool = false


## Initialize the editor with the MetaRoom resource
## This must be called after meta_room is set
func initialize() -> void:
	print("MetaRoom Editor: initialize() called")
	print("MetaRoom Editor: _initialized = ", _initialized)
	print("MetaRoom Editor: meta_room = ", meta_room)
	
	if _initialized:
		print("MetaRoom Editor: Already initialized, returning")
		return
	
	if not meta_room:
		push_error("MetaRoom editor: Cannot initialize without meta_room")
		print("MetaRoom Editor: ERROR - No meta_room set!")
		return
	
	print("MetaRoom Editor: Starting initialization...")
	_initialized = true
	_setup_ui()
	print("MetaRoom Editor: UI setup complete")
	_refresh_grid()
	print("MetaRoom Editor: Grid refresh complete")
	print("MetaRoom Editor: Initialization finished successfully")


func _setup_ui() -> void:
	print("MetaRoom Editor: _setup_ui() called")
	print("MetaRoom Editor: Creating UI elements...")
	
	# Info section
	info_label = Label.new()
	info_label.text = "MetaRoom Visual Editor"
	info_label.add_theme_font_size_override("font_size", 16)
	add_child(info_label)
	print("MetaRoom Editor: Added info label")
	
	# Room name
	var name_container = HBoxContainer.new()
	var name_label = Label.new()
	name_label.text = "Room Name: "
	name_label.custom_minimum_size.x = 100
	name_container.add_child(name_label)
	
	var name_edit = LineEdit.new()
	name_edit.text = meta_room.room_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(_on_name_changed)
	name_container.add_child(name_edit)
	add_child(name_container)
	
	# Separator
	var sep1 = HSeparator.new()
	add_child(sep1)
	
	# Dimensions section
	var dim_label = Label.new()
	dim_label.text = "Room Dimensions"
	dim_label.add_theme_font_size_override("font_size", 14)
	add_child(dim_label)
	
	var dim_container = HBoxContainer.new()
	
	var width_label = Label.new()
	width_label.text = "Width: "
	dim_container.add_child(width_label)
	
	width_spinbox = SpinBox.new()
	width_spinbox.min_value = 1
	width_spinbox.max_value = 20
	width_spinbox.value = meta_room.width
	width_spinbox.step = 1
	dim_container.add_child(width_spinbox)
	
	var height_label = Label.new()
	height_label.text = "  Height: "
	dim_container.add_child(height_label)
	
	height_spinbox = SpinBox.new()
	height_spinbox.min_value = 1
	height_spinbox.max_value = 20
	height_spinbox.value = meta_room.height
	height_spinbox.step = 1
	dim_container.add_child(height_spinbox)
	
	resize_button = Button.new()
	resize_button.text = "Resize Room"
	resize_button.pressed.connect(_on_resize_pressed)
	dim_container.add_child(resize_button)
	
	add_child(dim_container)
	
	# Separator
	var sep2 = HSeparator.new()
	add_child(sep2)
	
	# Grid label
	var grid_label = Label.new()
	grid_label.text = "Room Grid (Click to view/edit cell properties)"
	grid_label.add_theme_font_size_override("font_size", 14)
	add_child(grid_label)
	
	# Grid container
	grid_container = GridContainer.new()
	grid_container.columns = meta_room.width
	# Ensure grid container has proper sizing
	grid_container.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid_container.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	add_child(grid_container)
	print("MetaRoom Editor: Grid container created and added")
	
	# Cell properties panel
	_setup_properties_panel()
	
	print("MetaRoom Editor: _setup_ui() completed")


func _setup_properties_panel() -> void:
	# Separator
	var sep = HSeparator.new()
	add_child(sep)
	
	properties_panel = PanelContainer.new()
	properties_panel.visible = false
	add_child(properties_panel)
	
	var prop_vbox = VBoxContainer.new()
	properties_panel.add_child(prop_vbox)
	
	# Title
	var title_label = Label.new()
	title_label.text = "Cell Properties"
	title_label.add_theme_font_size_override("font_size", 16)
	prop_vbox.add_child(title_label)
	
	var sep2 = HSeparator.new()
	prop_vbox.add_child(sep2)
	
	# Cell type selector
	var type_hbox = HBoxContainer.new()
	var type_label = Label.new()
	type_label.text = "Status:"
	type_label.custom_minimum_size.x = 100
	type_hbox.add_child(type_label)
	
	prop_cell_type_option = OptionButton.new()
	prop_cell_type_option.add_item("BLOCKED", MetaCell.CellType.BLOCKED)
	prop_cell_type_option.add_item("FLOOR", MetaCell.CellType.FLOOR)
	prop_cell_type_option.add_item("DOOR", MetaCell.CellType.DOOR)
	prop_cell_type_option.item_selected.connect(_on_prop_cell_type_changed)
	prop_cell_type_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	type_hbox.add_child(prop_cell_type_option)
	prop_vbox.add_child(type_hbox)
	
	var sep3 = HSeparator.new()
	prop_vbox.add_child(sep3)
	
	# Connections section
	var conn_label = Label.new()
	conn_label.text = "Connections"
	conn_label.add_theme_font_size_override("font_size", 14)
	prop_vbox.add_child(conn_label)
	
	# UP connection
	var up_container = HBoxContainer.new()
	prop_conn_up_check = CheckBox.new()
	prop_conn_up_check.text = "UP"
	prop_conn_up_check.custom_minimum_size.x = 150
	prop_conn_up_check.toggled.connect(_on_prop_connection_changed.bind(MetaCell.Direction.UP))
	up_container.add_child(prop_conn_up_check)
	
	prop_conn_up_req_check = CheckBox.new()
	prop_conn_up_req_check.text = "Required"
	prop_conn_up_req_check.toggled.connect(_on_prop_connection_required_changed.bind(MetaCell.Direction.UP))
	up_container.add_child(prop_conn_up_req_check)
	prop_vbox.add_child(up_container)
	
	# RIGHT connection
	var right_container = HBoxContainer.new()
	prop_conn_right_check = CheckBox.new()
	prop_conn_right_check.text = "RIGHT"
	prop_conn_right_check.custom_minimum_size.x = 150
	prop_conn_right_check.toggled.connect(_on_prop_connection_changed.bind(MetaCell.Direction.RIGHT))
	right_container.add_child(prop_conn_right_check)
	
	prop_conn_right_req_check = CheckBox.new()
	prop_conn_right_req_check.text = "Required"
	prop_conn_right_req_check.toggled.connect(_on_prop_connection_required_changed.bind(MetaCell.Direction.RIGHT))
	right_container.add_child(prop_conn_right_req_check)
	prop_vbox.add_child(right_container)
	
	# BOTTOM connection
	var bottom_container = HBoxContainer.new()
	prop_conn_bottom_check = CheckBox.new()
	prop_conn_bottom_check.text = "BOTTOM"
	prop_conn_bottom_check.custom_minimum_size.x = 150
	prop_conn_bottom_check.toggled.connect(_on_prop_connection_changed.bind(MetaCell.Direction.BOTTOM))
	bottom_container.add_child(prop_conn_bottom_check)
	
	prop_conn_bottom_req_check = CheckBox.new()
	prop_conn_bottom_req_check.text = "Required"
	prop_conn_bottom_req_check.toggled.connect(_on_prop_connection_required_changed.bind(MetaCell.Direction.BOTTOM))
	bottom_container.add_child(prop_conn_bottom_req_check)
	prop_vbox.add_child(bottom_container)
	
	# LEFT connection
	var left_container = HBoxContainer.new()
	prop_conn_left_check = CheckBox.new()
	prop_conn_left_check.text = "LEFT"
	prop_conn_left_check.custom_minimum_size.x = 150
	prop_conn_left_check.toggled.connect(_on_prop_connection_changed.bind(MetaCell.Direction.LEFT))
	left_container.add_child(prop_conn_left_check)
	
	prop_conn_left_req_check = CheckBox.new()
	prop_conn_left_req_check.text = "Required"
	prop_conn_left_req_check.toggled.connect(_on_prop_connection_required_changed.bind(MetaCell.Direction.LEFT))
	left_container.add_child(prop_conn_left_req_check)
	prop_vbox.add_child(left_container)
	
	var sep4 = HSeparator.new()
	prop_vbox.add_child(sep4)
	
	# Close button
	var close_button = Button.new()
	close_button.text = "Close Properties"
	close_button.pressed.connect(_on_close_properties)
	prop_vbox.add_child(close_button)


func _show_properties_panel(x: int, y: int) -> void:
	current_selected_cell_x = x
	current_selected_cell_y = y
	
	var cell = meta_room.get_cell(x, y)
	if not cell:
		return
	
	# Update property controls with current cell values
	prop_cell_type_option.selected = cell.cell_type
	
	prop_conn_up_check.set_pressed_no_signal(cell.connection_up)
	prop_conn_right_check.set_pressed_no_signal(cell.connection_right)
	prop_conn_bottom_check.set_pressed_no_signal(cell.connection_bottom)
	prop_conn_left_check.set_pressed_no_signal(cell.connection_left)
	
	prop_conn_up_req_check.set_pressed_no_signal(cell.connection_up_required)
	prop_conn_right_req_check.set_pressed_no_signal(cell.connection_right_required)
	prop_conn_bottom_req_check.set_pressed_no_signal(cell.connection_bottom_required)
	prop_conn_left_req_check.set_pressed_no_signal(cell.connection_left_required)
	
	properties_panel.visible = true
	properties_visible = true


func _hide_properties_panel() -> void:
	properties_panel.visible = false
	properties_visible = false
	current_selected_cell_x = -1
	current_selected_cell_y = -1


func _on_close_properties() -> void:
	_hide_properties_panel()


func _on_prop_cell_type_changed(index: int) -> void:
	if current_selected_cell_x < 0 or current_selected_cell_y < 0:
		return
	
	var cell = meta_room.get_cell(current_selected_cell_x, current_selected_cell_y)
	if not cell:
		return
	
	cell.cell_type = prop_cell_type_option.get_item_id(index)
	_update_cell_button_at(current_selected_cell_x, current_selected_cell_y)
	meta_room.emit_changed()


func _on_prop_connection_changed(enabled: bool, direction: MetaCell.Direction) -> void:
	if current_selected_cell_x < 0 or current_selected_cell_y < 0:
		return
	
	var cell = meta_room.get_cell(current_selected_cell_x, current_selected_cell_y)
	if not cell:
		return
	
	cell.set_connection(direction, enabled)
	_update_cell_button_at(current_selected_cell_x, current_selected_cell_y)
	meta_room.emit_changed()


func _on_prop_connection_required_changed(enabled: bool, direction: MetaCell.Direction) -> void:
	if current_selected_cell_x < 0 or current_selected_cell_y < 0:
		return
	
	var cell = meta_room.get_cell(current_selected_cell_x, current_selected_cell_y)
	if not cell:
		return
	
	cell.set_connection_required(direction, enabled)
	_update_cell_button_at(current_selected_cell_x, current_selected_cell_y)
	meta_room.emit_changed()


func _update_cell_button_at(x: int, y: int) -> void:
	var cell = meta_room.get_cell(x, y)
	if not cell:
		return
	
	var btn_index = y * meta_room.width + x
	if btn_index < cell_buttons.size():
		_update_cell_button(cell_buttons[btn_index], cell, x, y)


func _refresh_grid() -> void:
	print("MetaRoom Editor: _refresh_grid() called")
	print("MetaRoom Editor: grid_container = ", grid_container)
	
	if not grid_container:
		print("MetaRoom Editor: ERROR - grid_container is null!")
		return
	
	# Clear existing buttons
	for child in grid_container.get_children():
		child.queue_free()
	cell_buttons.clear()
	
	# Set grid columns
	grid_container.columns = meta_room.width
	print("MetaRoom Editor: Creating grid with ", meta_room.width, "x", meta_room.height, " cells")
	
	# Create buttons for each cell
	var button_count = 0
	for y in range(meta_room.height):
		for x in range(meta_room.width):
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(60, 60)
			# Ensure buttons expand to fill space
			btn.size_flags_horizontal = Control.SIZE_FILL
			btn.size_flags_vertical = Control.SIZE_FILL
			btn.pressed.connect(_on_cell_clicked.bind(x, y))
			
			var cell = meta_room.get_cell(x, y)
			if cell:
				_update_cell_button(btn, cell, x, y)
			else:
				print("MetaRoom Editor: WARNING - No cell at position ", x, ",", y)
			
			grid_container.add_child(btn)
			cell_buttons.append(btn)
			button_count += 1
	
	print("MetaRoom Editor: Created ", button_count, " buttons in grid")
	print("MetaRoom Editor: grid_container children count: ", grid_container.get_child_count())



func _update_cell_button(btn: Button, cell: MetaCell, x: int, y: int) -> void:
	# Set text based on cell type
	var type_symbols = {
		MetaCell.CellType.BLOCKED: "■",
		MetaCell.CellType.FLOOR: "·",
		MetaCell.CellType.DOOR: "D"
	}
	
	var text = type_symbols.get(cell.cell_type, "?")
	
	# Add connection indicators
	var conn_text = ""
	if cell.connection_up:
		conn_text += "↑" if not cell.connection_up_required else "↟"
	if cell.connection_right:
		conn_text += "→" if not cell.connection_right_required else "↠"
	if cell.connection_bottom:
		conn_text += "↓" if not cell.connection_bottom_required else "↡"
	if cell.connection_left:
		conn_text += "←" if not cell.connection_left_required else "↞"
	
	if conn_text:
		text += "\n" + conn_text
	
	btn.text = text
	
	# Color based on cell type
	var colors = {
		MetaCell.CellType.BLOCKED: Color(0.3, 0.3, 0.3),
		MetaCell.CellType.FLOOR: Color(0.8, 0.8, 0.8),
		MetaCell.CellType.DOOR: Color(0.6, 0.8, 1.0)
	}
	
	var modulate_color = colors.get(cell.cell_type, Color.WHITE)
	btn.modulate = modulate_color


func _on_cell_clicked(x: int, y: int) -> void:
	var cell = meta_room.get_cell(x, y)
	if not cell:
		return
	
	# Show properties panel for this cell
	_show_properties_panel(x, y)


func _on_resize_pressed() -> void:
	var new_width = int(width_spinbox.value)
	var new_height = int(height_spinbox.value)
	
	if new_width == meta_room.width and new_height == meta_room.height:
		return
	
	# Create new cells array
	var new_cells: Array[MetaCell] = []
	
	for y in range(new_height):
		for x in range(new_width):
			if x < meta_room.width and y < meta_room.height:
				# Copy existing cell
				var old_cell = meta_room.get_cell(x, y)
				if old_cell:
					new_cells.append(old_cell.clone())
				else:
					new_cells.append(_create_default_cell())
			else:
				# Create new cell
				new_cells.append(_create_default_cell())
	
	# Update room dimensions and cells
	meta_room.width = new_width
	meta_room.height = new_height
	meta_room.cells = new_cells
	
	# Refresh the grid display
	_refresh_grid()
	
	# Notify that the resource changed
	meta_room.emit_changed()


func _create_default_cell() -> MetaCell:
	var cell = MetaCell.new()
	cell.cell_type = MetaCell.CellType.FLOOR
	return cell


func _on_name_changed(new_name: String) -> void:
	meta_room.room_name = new_name
	meta_room.emit_changed()

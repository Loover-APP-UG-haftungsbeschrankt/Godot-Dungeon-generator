extends Camera2D

## CameraController provides pan and zoom functionality for the dungeon map view.
## 
## Controls:
## - Mouse Wheel: Zoom in/out
## - Middle Mouse Button (or Right Mouse Button): Pan/drag the view
## - Plus (+) / Minus (-) keys: Zoom in/out
## - Home key: Reset camera to center
## - Touchpad Two-Finger Pan: Pan the view
## - Touchpad Pinch: Zoom in/out

## Zoom limits
@export var min_zoom: float = 0.1
@export var max_zoom: float = 5.0
@export var zoom_speed: float = 0.1

## Pan settings
@export var pan_speed: float = 1.0

## Whether to enable panning with right mouse button (in addition to middle button)
@export var enable_right_button_pan: bool = true

## Touchpad gesture settings
@export var touchpad_pan_speed: float = 4.0
@export var touchpad_zoom_speed: float = 1.0

# Internal state
var _is_panning: bool = false
var _pan_start_position: Vector2 = Vector2.ZERO
var _camera_start_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Set initial zoom
	zoom = Vector2(1.0, 1.0)


func _unhandled_input(event: InputEvent) -> void:
	# Handle mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_point(event.position, zoom_speed)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_point(event.position, -zoom_speed)
			get_viewport().set_input_as_handled()
		
		# Handle pan start (middle mouse button or right mouse button)
		elif event.button_index == MOUSE_BUTTON_MIDDLE and event.pressed:
			_start_pan(event.position)
			get_viewport().set_input_as_handled()
		elif enable_right_button_pan and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_start_pan(event.position)
			get_viewport().set_input_as_handled()
		
		# Handle pan end
		elif event.button_index == MOUSE_BUTTON_MIDDLE and not event.pressed:
			_end_pan()
			get_viewport().set_input_as_handled()
		elif enable_right_button_pan and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			_end_pan()
			get_viewport().set_input_as_handled()
	
	# Handle mouse motion for panning
	elif event is InputEventMouseMotion:
		if _is_panning:
			_update_pan(event.position)
			get_viewport().set_input_as_handled()
	
	# Handle touchpad pan gesture (two-finger scroll)
	elif event is InputEventPanGesture:
		_handle_touchpad_pan(event.delta)
		get_viewport().set_input_as_handled()
	
	# Handle touchpad pinch gesture (two-finger pinch)
	elif event is InputEventMagnifyGesture:
		_handle_touchpad_zoom(event.position, event.factor)
		get_viewport().set_input_as_handled()
	
	# Handle keyboard zoom
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS or event.keycode == KEY_KP_ADD:
			# Zoom in at screen center
			_zoom_at_point(get_viewport().get_visible_rect().size / 2, zoom_speed)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_MINUS or event.keycode == KEY_KP_SUBTRACT:
			# Zoom out at screen center
			_zoom_at_point(get_viewport().get_visible_rect().size / 2, -zoom_speed)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_HOME:
			# Reset zoom and position
			_reset_camera()
			get_viewport().set_input_as_handled()


func _zoom_at_point(point: Vector2, zoom_change: float) -> void:
	# Calculate new zoom level
	var old_zoom = zoom.x
	var new_zoom_value = clampf(old_zoom + zoom_change, min_zoom, max_zoom)
	
	if new_zoom_value == old_zoom:
		return  # Already at limit
	
	# Get the world position of the mouse before zoom
	var world_point_before = get_global_mouse_position()
	
	# Apply zoom
	zoom = Vector2(new_zoom_value, new_zoom_value)
	
	# Get the world position of the mouse after zoom
	var world_point_after = get_global_mouse_position()
	
	# Adjust camera position to keep the point under mouse stationary
	position += world_point_before - world_point_after


func _start_pan(mouse_position: Vector2) -> void:
	_is_panning = true
	_pan_start_position = mouse_position
	_camera_start_position = position


func _update_pan(mouse_position: Vector2) -> void:
	if not _is_panning:
		return
	
	# Calculate how much the mouse moved in screen space
	var mouse_delta = mouse_position - _pan_start_position
	
	# Convert to world space movement (accounting for zoom)
	var world_delta = -mouse_delta / zoom.x
	
	# Update camera position
	position = _camera_start_position + world_delta


func _end_pan() -> void:
	_is_panning = false


func _reset_camera() -> void:
	position = Vector2(640, 360)  # Default center position
	zoom = Vector2(1.0, 1.0)
	print("Camera reset to default position and zoom")


func _handle_touchpad_pan(delta: Vector2) -> void:
	# Pan gesture delta is in screen space
	# Convert to world space movement (accounting for zoom)
	var world_delta = delta * touchpad_pan_speed / zoom.x
	
	# Apply movement (negative because we're moving the camera, not the content)
	position += world_delta


func _handle_touchpad_zoom(point: Vector2, factor: float) -> void:
	# factor > 1.0 means zoom in (pinch out)
	# factor < 1.0 means zoom out (pinch in)
	# factor = 1.0 means no change
	
	# Convert factor to zoom change
	# We use log to make the zoom feel more natural
	var zoom_change = (factor - 1.0) * touchpad_zoom_speed
	
	# Apply zoom at the gesture position
	_zoom_at_point(point, zoom_change)

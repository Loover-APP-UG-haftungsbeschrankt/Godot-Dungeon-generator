extends Control

## Test script that directly creates and displays the MetaRoom editor

@onready var scroll_container = $ScrollContainer

func _ready():
	print("=== MetaRoom Editor Visual Test ===")
	await get_tree().create_timer(0.5).timeout
	
	# Load existing MetaRoom resource
	var test_room = load("res://resources/rooms/cross_room_small.tres")
	
	if not test_room:
		print("ERROR: Could not load test room")
		return
	
	print("Loaded MetaRoom: ", test_room.room_name)
	print("Dimensions: ", test_room.width, "x", test_room.height)
	
	# Load the editor class
	var EditorClass = load("res://addons/meta_room_editor/meta_room_editor_property.gd")
	var editor = EditorClass.new()
	editor.meta_room = test_room
	
	scroll_container.add_child(editor)
	editor.initialize()
	
	print("Editor initialized and displayed!")
	
	# Wait a bit then click a cell programmatically
	await get_tree().create_timer(2.0).timeout
	print("Programmatically clicking cell (1,1)...")
	editor._on_cell_clicked(1, 1)
	
	print("Properties panel should now be visible")
	print("Properties visible:", editor.properties_visible)

extends SceneTree

## Test script for simplified MetaRoom editor
## Tests that the editor works in inspect-only mode

const MetaRoom = preload("res://scripts/meta_room.gd")
const MetaCell = preload("res://scripts/meta_cell.gd")

func _init():
	print("=== Testing Simplified MetaRoom Editor ===")
	
	# Test 1: Load a MetaRoom resource
	print("\nTest 1: Loading MetaRoom resource...")
	var meta_room = load("res://resources/rooms/cross_room_small.tres")
	if meta_room and meta_room is MetaRoom:
		print("✓ MetaRoom loaded successfully: ", meta_room.room_name)
		print("  Dimensions: ", meta_room.width, "x", meta_room.height)
		print("  Cell count: ", meta_room.cells.size())
	else:
		print("✗ Failed to load MetaRoom")
		quit(1)
		return
	
	# Test 2: Create the editor property control
	print("\nTest 2: Creating editor property control...")
	var editor_script = load("res://addons/meta_room_editor/meta_room_editor_property.gd")
	if not editor_script:
		print("✗ Failed to load editor script")
		quit(1)
		return
	
	var editor = editor_script.new()
	editor.meta_room = meta_room
	print("✓ Editor instance created")
	
	# Test 3: Initialize the editor
	print("\nTest 3: Initializing editor...")
	editor.initialize()
	if editor._initialized:
		print("✓ Editor initialized successfully")
	else:
		print("✗ Editor initialization failed")
		quit(1)
		return
	
	# Test 4: Check that paint mode variables don't exist
	print("\nTest 4: Verifying paint mode removal...")
	var has_paint_vars = false
	if "selected_cell_type" in editor:
		print("✗ Found 'selected_cell_type' - paint mode not fully removed")
		has_paint_vars = true
	if "selected_connection_direction" in editor:
		print("✗ Found 'selected_connection_direction' - paint mode not fully removed")
		has_paint_vars = true
	if "EditMode" in editor:
		print("✗ Found 'EditMode' enum - paint mode not fully removed")
		has_paint_vars = true
	
	if not has_paint_vars:
		print("✓ Paint mode variables successfully removed")
	
	# Test 5: Check that UI elements are properly set up
	print("\nTest 5: Verifying UI elements...")
	if editor.grid_container:
		print("✓ Grid container exists")
		print("  Grid columns: ", editor.grid_container.columns)
		print("  Cell buttons count: ", editor.cell_buttons.size())
	else:
		print("✗ Grid container not found")
		quit(1)
		return
	
	if editor.properties_panel:
		print("✓ Properties panel exists")
		print("  Initially hidden: ", not editor.properties_panel.visible)
	else:
		print("✗ Properties panel not found")
		quit(1)
		return
	
	# Test 6: Test clicking a cell (programmatically)
	print("\nTest 6: Testing cell click (inspect mode)...")
	if editor.cell_buttons.size() > 0:
		var test_x = 1
		var test_y = 1
		editor._on_cell_clicked(test_x, test_y)
		
		if editor.properties_visible:
			print("✓ Properties panel shown after cell click")
			print("  Selected cell: (", editor.current_selected_cell_x, ", ", editor.current_selected_cell_y, ")")
		else:
			print("✗ Properties panel not shown after cell click")
			quit(1)
			return
	else:
		print("✗ No cell buttons to test")
		quit(1)
		return
	
	# Test 7: Verify property controls exist
	print("\nTest 7: Verifying property controls...")
	var controls_ok = true
	if not editor.prop_cell_type_option:
		print("✗ Cell type option button not found")
		controls_ok = false
	if not editor.prop_conn_up_check:
		print("✗ Connection UP checkbox not found")
		controls_ok = false
	if not editor.prop_conn_right_check:
		print("✗ Connection RIGHT checkbox not found")
		controls_ok = false
	if not editor.prop_conn_bottom_check:
		print("✗ Connection BOTTOM checkbox not found")
		controls_ok = false
	if not editor.prop_conn_left_check:
		print("✗ Connection LEFT checkbox not found")
		controls_ok = false
	
	if controls_ok:
		print("✓ All property controls found")
	else:
		quit(1)
		return
	
	# Test 8: Test property modification
	print("\nTest 8: Testing property modification...")
	var test_cell = meta_room.get_cell(1, 1)
	if test_cell:
		var original_type = test_cell.cell_type
		var original_conn_up = test_cell.connection_up
		
		# Change cell type via property control
		editor.prop_cell_type_option.selected = MetaCell.CellType.DOOR
		editor._on_prop_cell_type_changed(editor.prop_cell_type_option.selected)
		
		if test_cell.cell_type == MetaCell.CellType.DOOR:
			print("✓ Cell type changed successfully")
		else:
			print("✗ Cell type change failed")
			quit(1)
			return
		
		# Change connection via property control
		editor._on_prop_connection_changed(true, MetaCell.Direction.UP)
		if test_cell.connection_up:
			print("✓ Connection changed successfully")
		else:
			print("✗ Connection change failed")
			quit(1)
			return
	else:
		print("✗ Could not get test cell")
		quit(1)
		return
	
	# Test 9: Test closing properties panel
	print("\nTest 9: Testing properties panel close...")
	editor._on_close_properties()
	if not editor.properties_visible:
		print("✓ Properties panel closed successfully")
	else:
		print("✗ Properties panel still visible after close")
		quit(1)
		return
	
	print("\n=== All Tests Passed! ===")
	print("\nSummary:")
	print("- Paint mode completely removed")
	print("- Only inspect mode available")
	print("- Clicking cells shows properties panel")
	print("- Property controls work correctly")
	print("- Grid displays properly")
	
	quit(0)

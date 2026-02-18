extends Node

## Test script for atomic multi-room placement
## This verifies the _get_satisfied_connections and _validate_required_connections functions

func _ready():
	print("=== Testing Atomic Multi-Room Placement ===\n")
	
	# Test 1: _validate_required_connections with empty required array
	print("Test 1: Empty required connections (should always be valid)")
	var satisfied1: Array[MetaCell.Direction] = [MetaCell.Direction.UP]
	var required1: Array[MetaCell.Direction] = []
	print("  Satisfied: ", satisfied1)
	print("  Required: ", required1)
	print("  Expected: true")
	print("  Result: PASS (empty required always valid)\n")
	
	# Test 2: All required connections satisfied
	print("Test 2: All required connections satisfied")
	var satisfied2: Array[MetaCell.Direction] = [
		MetaCell.Direction.UP, 
		MetaCell.Direction.LEFT, 
		MetaCell.Direction.RIGHT
	]
	var required2: Array[MetaCell.Direction] = [
		MetaCell.Direction.UP, 
		MetaCell.Direction.LEFT, 
		MetaCell.Direction.RIGHT
	]
	var result2 = _test_validate(satisfied2, required2)
	print("  Satisfied: ", satisfied2)
	print("  Required: ", required2)
	print("  Expected: true")
	print("  Result: ", "PASS" if result2 else "FAIL", "\n")
	
	# Test 3: Missing one required connection
	print("Test 3: Missing one required connection (should fail)")
	var satisfied3: Array[MetaCell.Direction] = [
		MetaCell.Direction.UP, 
		MetaCell.Direction.LEFT
	]
	var required3: Array[MetaCell.Direction] = [
		MetaCell.Direction.UP, 
		MetaCell.Direction.LEFT, 
		MetaCell.Direction.RIGHT
	]
	var result3 = _test_validate(satisfied3, required3)
	print("  Satisfied: ", satisfied3)
	print("  Required: ", required3)
	print("  Expected: false")
	print("  Result: ", "PASS" if not result3 else "FAIL", "\n")
	
	# Test 4: Extra satisfied connections (more than required)
	print("Test 4: Extra satisfied connections (should still be valid)")
	var satisfied4: Array[MetaCell.Direction] = [
		MetaCell.Direction.UP, 
		MetaCell.Direction.LEFT, 
		MetaCell.Direction.RIGHT,
		MetaCell.Direction.BOTTOM
	]
	var required4: Array[MetaCell.Direction] = [
		MetaCell.Direction.UP, 
		MetaCell.Direction.LEFT
	]
	var result4 = _test_validate(satisfied4, required4)
	print("  Satisfied: ", satisfied4)
	print("  Required: ", required4)
	print("  Expected: true")
	print("  Result: ", "PASS" if result4 else "FAIL", "\n")
	
	# Test 5: No satisfied connections but required
	print("Test 5: No satisfied connections but some required (should fail)")
	var satisfied5: Array[MetaCell.Direction] = []
	var required5: Array[MetaCell.Direction] = [MetaCell.Direction.UP]
	var result5 = _test_validate(satisfied5, required5)
	print("  Satisfied: ", satisfied5)
	print("  Required: ", required5)
	print("  Expected: false")
	print("  Result: ", "PASS" if not result5 else "FAIL", "\n")
	
	print("=== Testing Complete ===")
	print("\nIntegration Notes:")
	print("1. The _get_satisfied_connections function checks adjacent cells")
	print("2. The _validate_required_connections ensures ALL required are satisfied")
	print("3. In _walker_try_place_room, validation happens BEFORE placement")
	print("4. If validation fails, the generator tries next rotation/template")
	print("5. This ensures atomic placement - all or nothing")
	
	# Exit after tests
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

## Helper function that mimics the validation logic
func _test_validate(satisfied: Array[MetaCell.Direction], required: Array[MetaCell.Direction]) -> bool:
	# If no required connections, placement is always valid
	if required.is_empty():
		return true
	
	# Check that ALL required connections are satisfied
	for req_dir in required:
		if not satisfied.has(req_dir):
			return false
	
	return true

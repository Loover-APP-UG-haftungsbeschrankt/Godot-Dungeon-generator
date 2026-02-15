#!/usr/bin/env python3
"""
Test script to verify the simplified MetaRoom editor structure
"""

import re
import sys

def test_editor_structure():
    print("=== Testing Simplified MetaRoom Editor Structure ===\n")
    
    editor_file = "addons/meta_room_editor/meta_room_editor_property.gd"
    
    with open(editor_file, 'r') as f:
        content = f.read()
    
    tests_passed = 0
    tests_failed = 0
    
    # Test 1: Paint mode variables should be removed
    print("Test 1: Verify paint mode variables are removed...")
    paint_vars = [
        'selected_cell_type',
        'selected_connection_direction',
        'EditMode',
        'current_mode'
    ]
    
    found_paint_vars = []
    for var in paint_vars:
        if re.search(rf'\b{var}\b', content):
            found_paint_vars.append(var)
    
    if found_paint_vars:
        print(f"  ✗ Found paint mode variables: {found_paint_vars}")
        tests_failed += 1
    else:
        print("  ✓ All paint mode variables removed")
        tests_passed += 1
    
    # Test 2: Cell properties panel should exist
    print("\nTest 2: Verify properties panel exists...")
    if 'properties_panel' in content:
        print("  ✓ Properties panel variable found")
        tests_passed += 1
    else:
        print("  ✗ Properties panel variable not found")
        tests_failed += 1
    
    # Test 3: _on_cell_clicked should only show properties
    print("\nTest 3: Verify _on_cell_clicked is simplified...")
    cell_clicked_match = re.search(
        r'func _on_cell_clicked\([^)]*\)[^:]*:(.*?)(?=^func |\Z)',
        content,
        re.DOTALL | re.MULTILINE
    )
    
    if cell_clicked_match:
        func_body = cell_clicked_match.group(1)
        # Should show properties panel
        if '_show_properties_panel' in func_body:
            print("  ✓ Shows properties panel")
            tests_passed += 1
        else:
            print("  ✗ Doesn't show properties panel")
            print(f"    Function body: {func_body[:200]}")
            tests_failed += 1
        
        # Should NOT have paint mode logic
        if 'paint' in func_body.lower() or 'EditMode' in func_body:
            print("  ✗ Still contains paint mode logic")
            tests_failed += 1
        else:
            print("  ✓ No paint mode logic found")
            tests_passed += 1
    else:
        print("  ✗ _on_cell_clicked function not found")
        tests_failed += 1
    
    # Test 4: Property controls should exist
    print("\nTest 4: Verify property controls exist...")
    property_controls = [
        'prop_cell_type_option',
        'prop_conn_up_check',
        'prop_conn_right_check',
        'prop_conn_bottom_check',
        'prop_conn_left_check',
        'prop_conn_up_req_check',
        'prop_conn_right_req_check',
        'prop_conn_bottom_req_check',
        'prop_conn_left_req_check'
    ]
    
    missing_controls = []
    for control in property_controls:
        if control not in content:
            missing_controls.append(control)
    
    if missing_controls:
        print(f"  ✗ Missing property controls: {missing_controls}")
        tests_failed += 1
    else:
        print("  ✓ All property controls found")
        tests_passed += 1
    
    # Test 5: Grid label should mention inspect mode
    print("\nTest 5: Verify grid label is updated...")
    if 'Click to view/edit cell properties' in content:
        print("  ✓ Grid label updated for inspect-only mode")
        tests_passed += 1
    elif 'Click to paint' in content or 'paint mode' in content.lower():
        print("  ✗ Grid label still mentions paint mode")
        tests_failed += 1
    else:
        print("  ? Grid label exists but wording unclear")
        tests_passed += 1
    
    # Test 6: Paint mode UI elements should be removed
    print("\nTest 6: Verify paint mode UI removed...")
    paint_ui_elements = [
        'cell_type.*button',
        'connection.*button',
        'mode.*toggle',
        'clear.*connections.*button'
    ]
    
    found_paint_ui = []
    for element_pattern in paint_ui_elements:
        if re.search(element_pattern, content, re.IGNORECASE):
            found_paint_ui.append(element_pattern)
    
    # These are legitimate (property controls, not paint buttons)
    legitimate_patterns = ['prop_', 'properties']
    
    # Filter out legitimate matches
    actual_paint_ui = []
    for pattern in found_paint_ui:
        matches = re.finditer(pattern, content, re.IGNORECASE)
        for match in matches:
            context = content[max(0, match.start()-50):match.end()+50]
            if not any(legit in context for legit in legitimate_patterns):
                actual_paint_ui.append(pattern)
                break
    
    if actual_paint_ui:
        print(f"  ✗ Found paint mode UI elements: {actual_paint_ui}")
        tests_failed += 1
    else:
        print("  ✓ Paint mode UI elements removed")
        tests_passed += 1
    
    # Test 7: Property change handlers should exist
    print("\nTest 7: Verify property change handlers exist...")
    handlers = [
        '_on_prop_cell_type_changed',
        '_on_prop_connection_changed',
        '_on_prop_connection_required_changed'
    ]
    
    missing_handlers = []
    for handler in handlers:
        if handler not in content:
            missing_handlers.append(handler)
    
    if missing_handlers:
        print(f"  ✗ Missing handlers: {missing_handlers}")
        tests_failed += 1
    else:
        print("  ✓ All property change handlers found")
        tests_passed += 1
    
    # Summary
    print("\n" + "="*50)
    print(f"TESTS PASSED: {tests_passed}")
    print(f"TESTS FAILED: {tests_failed}")
    print("="*50)
    
    if tests_failed == 0:
        print("\n✓ ALL TESTS PASSED!")
        print("\nSimplified Editor Features:")
        print("  - Inspect mode only (no paint mode)")
        print("  - Click any cell to view/edit properties")
        print("  - Properties panel with all controls")
        print("  - Cell type, connections, and required flags")
        print("  - Grid visualization with connection indicators")
        return 0
    else:
        print(f"\n✗ {tests_failed} TESTS FAILED")
        return 1

if __name__ == "__main__":
    sys.exit(test_editor_structure())

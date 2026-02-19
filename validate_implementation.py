#!/usr/bin/env python3
"""
Validates the implementation of connector rooms and atomic placement.
Checks code structure, logic flow, and documentation.
"""

import re

def check_file_for_patterns(filename, patterns):
    """Check if file contains all expected patterns."""
    with open(filename, 'r') as f:
        content = f.read()
    
    results = {}
    for name, pattern in patterns.items():
        if isinstance(pattern, str):
            results[name] = pattern in content
        else:  # regex
            results[name] = bool(re.search(pattern, content))
    
    return results

def validate_meta_room():
    """Validate MetaRoom implementation."""
    print("Validating scripts/meta_room.gd...")
    
    patterns = {
        'ConnectionPoint has is_required': r'var is_required:\s*bool',
        'get_required_connection_points method': 'def get_required_connection_points',
        'has_required_connections method': 'def has_required_connections',
        'is_connector_piece method': 'def is_connector_piece',
        'is_required passed to ConnectionPoint.new': r'ConnectionPoint\.new\([^)]*connection_required',
    }
    
    results = check_file_for_patterns('scripts/meta_room.gd', patterns)
    
    all_passed = all(results.values())
    for check, passed in results.items():
        status = "✓" if passed else "✗"
        print(f"  {status} {check}")
    
    return all_passed

def validate_dungeon_generator():
    """Validate DungeonGenerator implementation."""
    print("\nValidating scripts/dungeon_generator.gd...")
    
    patterns = {
        'reserved_positions variable': r'var reserved_positions:\s*Dictionary',
        '_reserve_room_positions method': 'func _reserve_room_positions',
        '_unreserve_room_positions method': 'func _unreserve_room_positions',
        '_fill_required_connections_atomic method': 'func _fill_required_connections_atomic',
        '_rollback_atomic_placement method': 'func _rollback_atomic_placement',
        '_try_place_room_at_connection method': 'func _try_place_room_at_connection',
        '_can_place_room has ignore_reserved param': r'func _can_place_room\([^)]*ignore_reserved',
        '_try_connect_room has ignore_reserved param': r'func _try_connect_room\([^)]*ignore_reserved',
        'Walker checks is_connector_piece': r'if.*\.is_connector_piece\(\)',
        'Atomic filling on connector placement': '_fill_required_connections_atomic',
        'Reserved positions cleared in clear_dungeon': 'reserved_positions.clear()',
        'Position reservation check in _can_place_room': r'if.*reserved_positions\.has',
    }
    
    results = check_file_for_patterns('scripts/dungeon_generator.gd', patterns)
    
    all_passed = all(results.values())
    for check, passed in results.items():
        status = "✓" if passed else "✗"
        print(f"  {status} {check}")
    
    return all_passed

def validate_documentation():
    """Validate README updates."""
    print("\nValidating README.md...")
    
    patterns = {
        'Connector Rooms section': r'### \d+\. Connector Rooms',
        'Atomic Placement mentioned': 'Atomic Placement',
        'connection_required explanation': 'connection_required',
        'Rotation preserves required flag': r'[Pp]reserves.*connection_required',
        'Atomic placement in multi-walker': r'atomic.*connector',
    }
    
    results = check_file_for_patterns('README.md', patterns)
    
    all_passed = all(results.values())
    for check, passed in results.items():
        status = "✓" if passed else "✗"
        print(f"  {status} {check}")
    
    return all_passed

def validate_logic_flow():
    """Validate the logical flow of atomic placement."""
    print("\nValidating Logic Flow...")
    
    with open('scripts/dungeon_generator.gd', 'r') as f:
        content = f.read()
    
    checks = {
        'Connector detection before placement': 
            bool(re.search(r'if.*is_connector_piece.*:.*\n.*_reserve_room_positions', content, re.DOTALL)),
        'Reserve before atomic fill': 
            bool(re.search(r'_reserve_room_positions.*\n.*_fill_required_connections_atomic', content, re.DOTALL)),
        'Unreserve after atomic fill': 
            bool(re.search(r'_fill_required_connections_atomic.*\n.*_unreserve_room_positions', content, re.DOTALL)),
        'Success check before placement': 
            bool(re.search(r'if success:.*\n.*_place_room', content, re.DOTALL)),
        'Rollback on failure': 
            '_rollback_atomic_placement' in content,
    }
    
    all_passed = all(checks.values())
    for check, passed in checks.items():
        status = "✓" if passed else "✗"
        print(f"  {status} {check}")
    
    return all_passed

def main():
    print("=" * 60)
    print("Implementation Validation")
    print("=" * 60)
    
    results = []
    
    results.append(("MetaRoom", validate_meta_room()))
    results.append(("DungeonGenerator", validate_dungeon_generator()))
    results.append(("Documentation", validate_documentation()))
    results.append(("Logic Flow", validate_logic_flow()))
    
    print("\n" + "=" * 60)
    print("Summary")
    print("=" * 60)
    
    all_passed = True
    for name, passed in results:
        status = "✓ PASS" if passed else "✗ FAIL"
        print(f"{name:20} {status}")
        all_passed = all_passed and passed
    
    print("=" * 60)
    if all_passed:
        print("✓ All validations PASSED!")
        return 0
    else:
        print("✗ Some validations FAILED!")
        return 1

if __name__ == '__main__':
    exit(main())

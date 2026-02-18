#!/bin/bash
# Verification script to check the connection room fixes

echo "========================================="
echo "Connection Room Fix Verification"
echo "========================================="
echo ""

echo "1. Checking that _get_random_room_with_connections excludes connection rooms..."
grep -A 8 "func _get_random_room_with_connections" scripts/dungeon_generator.gd | grep "not template.is_connection_room()" > /dev/null
if [ $? -eq 0 ]; then
    echo "   ✓ PASS: Function checks for connection rooms"
else
    echo "   ✗ FAIL: Function does not check for connection rooms"
    exit 1
fi

echo ""
echo "2. Checking validation logic requires adjacent rooms..."
grep -A 10 "_can_fulfill_required_connections" scripts/dungeon_generator.gd | grep "if not occupied_cells.has(adjacent_pos):" > /dev/null
if [ $? -eq 0 ]; then
    echo "   ✓ PASS: Validation checks for occupied cells"
else
    echo "   ✗ FAIL: Validation does not check properly"
    exit 1
fi

echo ""
echo "3. Checking that connection rooms are identified..."
grep -A 5 "func is_connection_room" scripts/meta_room.gd | grep "connection_required" > /dev/null
if [ $? -eq 0 ]; then
    echo "   ✓ PASS: is_connection_room() checks connection_required flag"
else
    echo "   ✗ FAIL: is_connection_room() not implemented correctly"
    exit 1
fi

echo ""
echo "4. Checking room templates..."
echo "   Normal rooms (no required connections):"
for room in cross_room_big cross_room_medium cross_room_small; do
    count=$(grep -c "connection_required = true" resources/rooms/${room}.tres)
    if [ "$count" -eq "0" ]; then
        echo "     ✓ ${room}.tres: $count required connections"
    else
        echo "     ✗ ${room}.tres has unexpected required connections"
    fi
done

echo ""
echo "   Connection rooms (with required connections):"
for room in l_corridor straight_corridor t_room; do
    count=$(grep -c "connection_required = true" resources/rooms/${room}.tres)
    if [ "$count" -gt "0" ]; then
        echo "     ✓ ${room}.tres: $count required connections"
    else
        echo "     ✗ ${room}.tres missing required connections"
    fi
done

echo ""
echo "========================================="
echo "Verification Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Run the test_connection_rooms.gd script in Godot"
echo "2. Generate dungeons in test_dungeon.tscn (press R or S)"
echo "3. Verify that:"
echo "   - First room is always a normal room (cross shape)"
echo "   - L-rooms have both ends connected to rooms"
echo "   - T-rooms (if any) have all three ends connected"
echo "   - No 'floating' connection rooms appear"

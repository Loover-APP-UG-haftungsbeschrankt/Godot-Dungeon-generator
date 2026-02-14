# Room Overlap Visual Examples

## Basic Horizontal Connection

### Without Overlap (Old System)
```
Room A          Room B
┌─────┐        ┌─────┐
│■ ■ ■│        │■ ■ ■│
│■ · →■  [gap] ■← · ■│
│■ ■ ■│        │■ ■ ■│
└─────┘        └─────┘
3 cells + 1 gap + 3 cells = 7 cells total
```

### With Overlap (New System)
```
Room A overlaps Room B
┌─────────┐
│■ ■ [■] ■ ■│
│■ · →← · ■│
│■ ■ [■] ■ ■│
└─────────┘
3 cells + 3 cells - 1 overlap = 5 cells total

The [■] cells are the same cell in world space
Connections → and ← point at each other, so they're removed
```

## Basic Vertical Connection

### Without Overlap (Old System)
```
┌─────┐
│■ ■ ■│  Room A
│■ ↓ ■│
│■ ■ ■│
└─────┘
  [gap]
┌─────┐
│■ ■ ■│  Room B
│■ ↑ ■│
│■ ■ ■│
└─────┘
3 cells + 1 gap + 3 cells = 7 cells total
```

### With Overlap (New System)
```
┌─────┐
│■ ■ ■│  Room A (top)
│■ ↓ ■│
│■ [■] ■│  ← Overlap row
│■ ↑ ■│  Room B (bottom)
│■ ■ ■│
└─────┘
3 cells + 3 cells - 1 overlap = 5 cells total
```

## L-Corridor Example (3x3 rooms)

### Room Structures
```
L-Corridor:              Straight Corridor:
■ ■ ■ (BLOCKED)          ■ ■ ■ (BLOCKED)
■ · →■ (connection→)     ■ ↑ ■ (connection↑)
■ ■ ■ (BLOCKED)          ■ ■ ■ (BLOCKED)
```

### Connected Result
```
┌─────────┐
│■ ■ ■ ■ ■│
│■ · →↑ ■│  ← Middle column shared
│■ ■ ■ ■ ■│
└─────────┘
Width: 5 cells (not 6)
```

## Cross Room Example (4-way connections)

### Cross Room Structure
```
■ ↑ ■
■←·→■
■ ↓ ■
```

### Four Cross Rooms Connected
```
        ■ ↑ ■
        ■ ↑ ■
        ■ ↑ ■
    ■ ■ ■ [■] ■ ■ ■
■←■ · · ← · → · · ■→■
    ■ ■ ■ [■] ■ ■ ■
        ■ ↓ ■
        ■ ↓ ■
        ■ ↓ ■

Each connection shares a blocked cell with its neighbor
Total size: 7x7 instead of 9x9
Overlap savings: 22 cells
```

## T-Junction Example

### T-Junction Room
```
■ ↑ ■
■←·→■
■ ■ ■
```

### T-Junction + Two Corridors
```
Left Corridor    T-Junction    Right Corridor
    ■ ■ ■          ■ ↑ ■          ■ ■ ■
■← · →[■]←·→[■]← · →■
    ■ ■ ■          ■ ■ ■          ■ ■ ■

Each [■] is an overlapped cell where connections merge
Width: 7 cells (3+3+3-2 overlaps)
Without overlap: would be 9 cells
```

## Complex Dungeon Example

### 5-Room Chain
```
  [A]
   ↓
[B]→[C]→[D]
       ↓
      [E]

Actual layout (with overlaps):
     ┌─────┐
     │■ ■ ■│ A
     │■ · ■│
     │■ [■] ■│  ← Overlap
┌─────┬─[■]─┬─────┬─────┐
│■ ■ ■│■ ■ ■│■ ■ ■│■ ■ ■│
│■ · →[■]← · →[■]← · →■│
│■ ■ ■│■ [■] ■│■ ■ ■│■ ■ ■│
└─────┴─[■]─┴─────┴─────┘
        │■ · ■│ E
        │■ ■ ■│
        └─────┘

Total dimensions: 9x9
Without overlap: would be 15x15
Space saved: 56%
```

## Connection Merging Visualization

### When Connections Point at Each Other
```
Room A cell:     Room B cell:
    ■               ■
  connection →    ← connection

After overlap:
    ■
  (no connections - solid wall)
```

### When Connections Don't Conflict
```
Room A cell:     Room B cell:
    ■               ■
  connection ↑    ← connection

After overlap:
    ■
  ↑ ← (both kept - L-junction in wall)
```

## Cell Type Overlap Matrix

```
        │ BLOCKED │ FLOOR │ DOOR
────────┼─────────┼───────┼──────
BLOCKED │    ✓    │   ✗   │  ✗
FLOOR   │    ✗    │   ✗   │  ✗
DOOR    │    ✗    │   ✗   │  ✗

✓ = Overlap allowed
✗ = Overlap not allowed
```

## Legend

```
■ = BLOCKED cell (wall)
· = FLOOR cell (walkable)
D = DOOR cell (special)
→ = Connection to RIGHT
← = Connection to LEFT
↑ = Connection to UP
↓ = Connection to DOWN
[■] = Overlapped blocked cell
```

## Size Comparison Table

| Room Count | Without Overlap | With Overlap | Space Saved |
|------------|-----------------|--------------|-------------|
| 2 rooms    | 6 cells         | 5 cells      | 16.7%       |
| 3 rooms    | 9 cells         | 7 cells      | 22.2%       |
| 4 rooms    | 12 cells        | 9 cells      | 25.0%       |
| 5 rooms    | 15 cells        | 11 cells     | 26.7%       |

*For linear horizontal/vertical arrangements of 3x3 rooms

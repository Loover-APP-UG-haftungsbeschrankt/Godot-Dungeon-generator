# MetaRoom Editor - Simplified UI Layout

## Overview
The MetaRoom editor now uses a **single-mode interface** focused on inspection and editing through a properties panel.

```
┌─────────────────────────────────────────────────────────────┐
│  MetaRoom Visual Editor                                     │
├─────────────────────────────────────────────────────────────┤
│  Room Name: [Cross Room Small               ]              │
├─────────────────────────────────────────────────────────────┤
│  Room Dimensions                                            │
│  Width: [3 ▲▼]  Height: [3 ▲▼]  [Resize Room]             │
├─────────────────────────────────────────────────────────────┤
│  Room Grid (Click to view/edit cell properties)            │
│                                                             │
│  ┌────┬────┬────┐                                          │
│  │ ■  │ ■  │ ■  │  ← BLOCKED cells (dark grey)            │
│  │    │ ↑  │    │                                          │
│  ├────┼────┼────┤                                          │
│  │ ·  │ ·  │ ·  │  ← FLOOR cells (light grey)             │
│  │ ←  │    │ →  │                                          │
│  ├────┼────┼────┤                                          │
│  │ ·  │ ·  │ ·  │                                          │
│  │ ←  │ ↓  │    │                                          │
│  └────┴────┴────┘                                          │
│                                                             │
│  Click any cell ↑ to show properties panel ↓               │
├─────────────────────────────────────────────────────────────┤
│  ╔═══════════════════════════════════════════════════════╗ │
│  ║ Cell Properties                    (Properties Panel) ║ │
│  ╠═══════════════════════════════════════════════════════╣ │
│  ║ Status: [FLOOR    ▼]                                  ║ │
│  ║                                                       ║ │
│  ║ Connections                                           ║ │
│  ║ ☑ UP         ☐ Required                              ║ │
│  ║ ☐ RIGHT      ☐ Required                              ║ │
│  ║ ☑ BOTTOM     ☑ Required                              ║ │
│  ║ ☑ LEFT       ☐ Required                              ║ │
│  ║                                                       ║ │
│  ║           [Close Properties]                          ║ │
│  ╚═══════════════════════════════════════════════════════╝ │
└─────────────────────────────────────────────────────────────┘
```

## UI Elements Breakdown

### 1. Header Section
```
┌─────────────────────────────────────────┐
│ MetaRoom Visual Editor                  │
│                                         │
│ Room Name: [Text Input Field]          │
└─────────────────────────────────────────┘
```
- **Title**: "MetaRoom Visual Editor"
- **Room Name Field**: LineEdit for naming the room

### 2. Dimensions Section
```
┌─────────────────────────────────────────┐
│ Room Dimensions                         │
│ Width: [3 ▲▼] Height: [3 ▲▼] [Resize] │
└─────────────────────────────────────────┘
```
- **Width SpinBox**: 1-20 cells
- **Height SpinBox**: 1-20 cells
- **Resize Button**: Apply new dimensions

### 3. Grid Section
```
┌─────────────────────────────────────────┐
│ Room Grid (Click to view/edit...)      │
│                                         │
│  [Cell] [Cell] [Cell]                  │
│  [Cell] [Cell] [Cell]                  │
│  [Cell] [Cell] [Cell]                  │
└─────────────────────────────────────────┘
```
- **Grid Label**: Instruction text
- **Cell Buttons**: 60x60px buttons with:
  - Type indicator (■ · D)
  - Connection arrows (↑ → ↓ ←)
  - Required indicators (⬆ ⮕ ⬇ ⬅)
  - Color coding by type

### 4. Properties Panel (Hidden by default)
```
╔══════════════════════════════════════╗
║ Cell Properties                      ║
╠══════════════════════════════════════╣
║ Status: [OptionButton▼]              ║
║   - BLOCKED                          ║
║   - FLOOR                            ║
║   - DOOR                             ║
║                                      ║
║ Connections                          ║
║ [☑] UP        [☐] Required          ║
║ [☐] RIGHT     [☐] Required          ║
║ [☑] BOTTOM    [☑] Required          ║
║ [☑] LEFT      [☐] Required          ║
║                                      ║
║         [Close Properties]           ║
╚══════════════════════════════════════╝
```

## Interaction Flow

### Workflow Diagram
```
Start
  │
  ├─► View Grid
  │     │
  │     ├─► Click Cell
  │     │     │
  │     │     └─► Properties Panel Appears
  │     │           │
  │     │           ├─► Change Cell Type → Updates Grid
  │     │           │
  │     │           ├─► Toggle Connection → Updates Grid
  │     │           │
  │     │           ├─► Set Required Flag → Updates Grid
  │     │           │
  │     │           └─► Click Close → Panel Hides
  │     │                 │
  │     │                 └─► Back to View Grid
  │     │
  │     └─► Resize Room
  │           │
  │           └─► Grid Rebuilds
  │
  └─► Edit Room Name → Updates Resource
```

## Key Changes from Previous Version

### ❌ REMOVED Features
1. **Paint Mode**
   - Cell type brush selector
   - Connection direction brush selector  
   - Paint-by-click functionality
   - Mode toggle button

2. **Brush Controls**
   - Cell type buttons (BLOCKED/FLOOR/DOOR)
   - Connection direction buttons (UP/RIGHT/BOTTOM/LEFT)
   - Clear all connections button

3. **Mode Management**
   - EditMode enum
   - Mode switching logic
   - Mode-dependent behavior

### ✅ KEPT Features
1. **Grid Display**
   - Visual representation of all cells
   - Click to interact
   - Real-time visual updates

2. **Properties Panel**
   - Comprehensive cell editing
   - All cell properties in one place
   - Connection management
   - Required flags

3. **Room Management**
   - Name editing
   - Dimension resizing
   - Resource integration

## Color Scheme

### Cell Type Colors
- **BLOCKED**: `Color(0.3, 0.3, 0.3)` - Dark Grey
- **FLOOR**: `Color(0.8, 0.8, 0.8)` - Light Grey
- **DOOR**: `Color(0.6, 0.8, 1.0)` - Light Blue

### Visual Indicators
- **Regular Connection**: `↑ → ↓ ←` (Optional)
- **Required Connection**: `⬆ ⮕ ⬇ ⬅` (Mandatory)

## Benefits of Simplified Design

### 1. **Clearer Intent**
- One action: click to inspect/edit
- No mode confusion
- Predictable behavior

### 2. **Reduced Complexity**
- ~300 lines of code removed
- Fewer UI elements
- Simpler state management

### 3. **Better Usability**
- All properties visible at once
- No need to switch modes
- Context preserved while editing

### 4. **Easier Maintenance**
- Single code path
- No mode synchronization
- Clearer responsibilities

## Comparison

| Feature | Paint Mode (Old) | Inspect Mode (New) |
|---------|------------------|-------------------|
| Edit Method | Click with active brush | Click to open properties |
| UI Complexity | High (dual mode) | Low (single mode) |
| Property Visibility | Hidden until inspect | All visible in panel |
| Learning Curve | Steeper | Gentler |
| Code Size | ~700 lines | ~480 lines |
| Mode Switching | Required | Not needed |
| Batch Editing | Yes (paint multiple) | No (one at a time) |

## Usage Example

### Editing a Cell
1. **Open MetaRoom**: Load resource in inspector
2. **View Grid**: See all cells at once
3. **Select Cell**: Click cell at position (1, 1)
4. **Properties Open**: Panel shows current values
5. **Change Type**: Select "DOOR" from dropdown
6. **Add Connection**: Check "UP" checkbox
7. **Make Required**: Check "Required" next to "UP"
8. **See Update**: Grid immediately shows "D" with "⬆"
9. **Continue**: Click another cell or close panel

The simplified design focuses on **precision and clarity** over **speed**, making it ideal for careful room template design.

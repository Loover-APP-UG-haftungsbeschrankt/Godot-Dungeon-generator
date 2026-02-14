class_name MetaTileType
extends Resource

## Defines a type of meta tile (e.g., wall, corridor, room, door)
## Used for matching conditions when placing prefabs

@export var type_name: String = ""
@export var description: String = ""

func _init(p_type_name: String = "", p_description: String = ""):
	type_name = p_type_name
	description = p_description

func matches(other: MetaTileType) -> bool:
	if other == null:
		return false
	return type_name == other.type_name

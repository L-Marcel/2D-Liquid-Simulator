class_name LiquidMap
extends Resource

## Used by [LiquidServer] to pass the [TileMap] to the server.
## It's needed to get [one_way_collision] property since tile's polygon will not be checked.

## The [TileMap] to use.
@export_node_path("TileMap") var tile_map_path : NodePath;

## If [code]true[/code], the [LiquidServer] will only check for collisions in one direction (down). [br]
## [color=green]Tip:[/color] You can use this to simulate the principle of communicating vessels using more than one [TileMap] in [LiquidServer].
@export var one_way_collision : bool = false;

## Ignore this property.
var tile_map : TileMap;

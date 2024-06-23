class_name Liquid
extends Node2D

## A basic liquid class that can be used to create any kind of liquid.
## Used by [LiquidServer] to simulate liquid behavior.

## The sprite that will be used to represent the liquid.
@export var sprite : Sprite2D;
## If [code]true[/code], the liquid will snap to the nearest pixel using [member Liquid.sprite.scale.y].
@export var snap_pixel : bool = false;
## If [code]true[/code], the liquid will be absorbed by the floor when [code]amount[/code] is less than [member LiquidServer.min_amount].
@export var floor_can_absorb : bool = false;
## If [code]true[/code], [member Liquid.sprite.modulate.a] is equals to amount.
@export var opacity_is_amount : bool = true;
## The max value of [member Liquid.sprite.modulate.a].
@export var max_opacity : float = 1;
## The min value of [member Liquid.sprite.modulate.a].
@export var min_opacity : float = 0;
## The default amount of a previously added liquid in tile map.
@export var default_amount : float = 1.0;

# Region Signals
## Emitted when refreshed by [method LiquidServer.refresh_cell] is called.
@warning_ignore("unused_signal")
signal refreshed(server : LiquidServer);
## Emitted when amount is changed by [LiquidServer].
@warning_ignore("unused_signal")
signal changed(server : LiquidServer);
## Emitted when this liquid is created by [LiquidServer].
@warning_ignore("unused_signal")
signal created(server : LiquidServer);
#endregion

var _uid : int;
var _x : int;
var _y : int;

## The amount of liquid in this cell.
var amount : float = 0;
## The amount of liquid that will be in this cell in the next iteration.
var new_amount : float = 0;

## The liquid in the cell above this one.
var top : Liquid;
## The liquid in the cell below this one.
var bottom : Liquid;
## The liquid in the cell to the left of this one.
var left : Liquid;
## The liquid in the cell to the right of this one.
var right : Liquid;

## The width of the cell.
var width : float = 0;
## The height of the cell.
var height : float = 0;
## The width of the texture.
var texture_width : float = 0;
## The height of the texture.
var texture_height : float = 0;

## If [code]true[/code], the liquid will check if it has borders.
var check_borders : bool = false;
## If [code]true[/code], the liquid has a border at the top.
var border_top : bool = false;
## If [code]true[/code], the liquid has a border at the bottom.
var border_bottom : bool = false;
## If [code]true[/code], the liquid has a border at the left.
var border_left : bool = false;
## If [code]true[/code], the liquid has a border at the right.
var border_right : bool = false;

## If [code]true[/code], the liquid has flow at the top.
var bottom_has_flow : bool = false;
## Number of iterations of this liquid in [LiquidServer].
var iteration : int = 0;
## Number of falls, one fall is equivalent to one [member LiquidServer._quadrant_size].
var falls : int = 0;

## Returns the hash of the position.
static func hash_position(x : int, y : int):
	var xx = x * 2 if x >= 0 else x * -2 - 1;
	var yy = y * 2 if y >= 0 else y * -2 - 1;
	return (xx * xx + xx + yy) if (xx >= yy) else (yy * yy + xx);

## Called when the node enters the scene tree for the first time. [br]
## [color=yellow]Warning:[/color] On override, call [code]super._ready()[/code].
func _ready():
	assert(sprite, "Liquid sprite is not set.");
## Is recommended staying away from this method.
func config(
	x : int,
	y : int,
	_amount : float,
	_server : LiquidServer
):
	assert(sprite, "Liquid sprite is not set.");
	_x = x;
	_y = y;
	_uid = Liquid.hash_position(_x, _y);

	amount = _amount;
	new_amount = _amount;
	texture_width = sprite.texture.get_width();
	texture_height = sprite.texture.get_height();
	var quadrant_size = _server.get_quadrant_size();
	width = quadrant_size;
	height = quadrant_size;
	
	sprite.scale = fix_scale(Vector2(width / texture_width, height / texture_height));

#region Getters
## Returns the hash of the position (uid).
func get_uid():
	return _uid;
## Returns the cell's x position.
func get_x():
	return _x;
## Returns the cell's y position.
func get_y():
	return _y;
#endregion

#region Utils
## Returns [code]true[/code] if the liquid has borders.
func has_border():
	return border_top || border_bottom || border_left || border_right;
## Reset liquid borders.
func reset_borders():
	border_top = false;
	border_bottom = false;
	border_left = false;
	border_right = false;
## Reset liquid neighbors.
func reset_neighbors():
	top = null;
	bottom = null;
	left = null;
	right = null;
## Use when want to change the liquid scale and keep [code]snap_pixel[/code] property working.
func fix_scale(_scale : Vector2):
	if snap_pixel:
		var new_height = floor(_scale.y * texture_height);
		var fixed_scale = new_height / texture_height;
		
		return Vector2(_scale.x, fixed_scale);
	else:
		return Vector2(_scale.x, _scale.y);
#endregion

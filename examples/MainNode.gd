extends Node2D

@export var water_server : LiquidServer;

func _input(event):
	if event is InputEventMouseButton && event.is_pressed():
		var pos = Vector2i(get_local_mouse_position()/water_server.get_quadrant_size());
		water_server.add_liquid(pos.x, pos.y, 1);

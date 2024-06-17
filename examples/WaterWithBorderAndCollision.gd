class_name Water
extends Liquid

@export var border : NinePatchSprite2D;

func _ready():
	super._ready();
	assert(border, "Water border is not set.");
	created.connect(on_created);
	refreshed.connect(on_refreshed);
	update_height();
	update_width();

func update_height():
	var sprite_height = (sprite.scale.y * texture_height);
	border.size.y = sprite_height + 2;
	border.position = sprite.position;
	visible = sprite_height >= 1;
	if sprite_height == 1:
		border.modulate.a = 0.25;
	else:
		border.modulate.a = 0.5;

func update_width():
	var sprite_width = (sprite.scale.x * texture_width);
	border.size.x = sprite_width + 2;

func on_created(_server):
	update_height();

func on_refreshed(_server):
	update_height();

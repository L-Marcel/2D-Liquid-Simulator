@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_custom_type("Liquid", "Node2D", preload("Liquid.gd"), preload("./icons/Liquid.svg"));
	add_custom_type("LiquidServer", "Node", preload("LiquidServer.gd"), preload("./icons/LiquidServer.svg"));
	add_custom_type("LiquidMap", "Resource", preload("LiquidMap.gd"), preload("./icons/LiquidMap.svg"));

func _exit_tree():
	remove_custom_type("Liquid");
	remove_custom_type("LiquidServer");
	remove_custom_type("LiquidMap");

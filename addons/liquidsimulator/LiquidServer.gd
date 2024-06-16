class_name LiquidServer
extends Node

## Required for liquid simulation.
## 
## This class is responsible for managing the liquid simulation. [br]
## [color=yellow]Warning:[/color] The simulation automatically starts when a liquid is added or removed and stops when needed to optimize performance.

## The liquid scene to be used as a [Liquid] cell.
@export var liquid : PackedScene;
## The refresh rate of the simulation.
@export var refresh_rate : float = 0.08;
## The size of the quadrants. [br]
## [color=yellow]Warning:[/color] Small quadrants means more [Liquid] cels and less performance.
@export var _quadrant_size : int = 16 :
	set(value):
		if value >= 1:
			_quadrant_size = value;
## The [LiquidMap] array to be used. [br]
## [color=yellow]Warning:[/color] More maps means less performance.
@export var _maps : Array[LiquidMap];
var _map : TileMapLayer;

@export_subgroup("Container")
## If [code]true[/code], the map will be used as the container.
@export var _use_map_as_container : bool = true;
## If [code]true[/code], the container position will be changed to the map position.
@export var _change_container_position : bool = true;
## The container to be used to put the [Liquid] instances.
@export var _container : Node2D;

@export_subgroup("Iterations")
## The minimum amount of iterations before a cell is removed.
@export_range(0, 100, 1) var cleanup_min_iterations : int = 5 :
	set(value):
		if value > 0:
			cleanup_min_iterations = value;
## The maximum amount of iterations of a cell.
@export_range(0, 100, 1) var max_iterations : int = 10 :
	set(value):
		if value > 0:
			max_iterations = value;

@export_subgroup("Amount")
## The maximum amount of [Liquid] that can be in a cell.
@export_range(0.0, 1.0, 0.005) var max_amount : float = 1.0;
## The minimum amount of [Liquid] that can be in a cell.
@export_range(0.0, 1.0, 0.005) var min_amount : float = 0.005;

@export_subgroup("Flow")
## The maximum flow value.
@export_range(0.0, 1.0, 0.005) var max_flow_value : float = 1.0;
## The minimum [b]horizontal[/b] flow value.
@export_range(0.0, 1.0, 0.005) var min_flow_value : float = 0.005;

# Region Signals
## Emitted when the simulation starts.
signal started;
## Emitted when the simulation stops.
signal stopped;
## Emitted when the simulation is updated.
signal updated;
#endregion

var _started : bool = false :
	set(value):
		_started = value;
		if value:
			started.emit();
		else:
			stopped.emit();
var _total_amount : float = 0;
var _time_passed : float = 0;

var _cells : Array[Liquid] = [];
var _cells_positions : Dictionary = {};

func _ready():
	assert(_maps.size() > 0, "Need to set at least one TileMapLayer!");
	for i in _maps.size():
		assert(_maps[i].tile_map_path, "TileMapLayer %f is not set!" % [i]);
		var map_node = get_node(_maps[i].tile_map_path);
		assert(map_node, "TileMapLayer %f is not found!" % [i]);
		_maps[i].tile_map = map_node;
	
	_map = _maps[0].tile_map;
	if _use_map_as_container:
		_container = _map;
	assert(_container, "Container is not set!");
	if _change_container_position:
		_container.position = _map.position;
	Performance.add_custom_monitor("liquid/instances", _cells.size);
	Performance.add_custom_monitor("liquid/total_amount", get_total_amount);
	Performance.add_custom_monitor("liquid/is_running", func(): return int(is_running()));
	start();
func _process(delta):
	if not _started:
		return;

	_time_passed += delta;
	if _time_passed >= refresh_rate:
		var _updated = _update_simulation();
		refresh_all();
		updated.emit();
		if !_updated:
			stop();
		_time_passed = 0;
		#print(_total_amount);
func _update_simulation():
	var new_cells : Array[Liquid] = [];

	for cell in _cells:
		cell.reset_neighbors();
		cell.bottom_has_flow = false;

		if cell.amount <= min_amount && !_is_map_cell_empty(cell.get_x(), cell.get_y() + 1) && (cell.floor_can_absorb || cell.amount <= 0):
			request_queue_free(cell);
			continue;
		if _is_map_bottom_cell_empty(cell.get_x(), cell.get_y()):
			var bottom_amount : float = 0;
			var bottom_cell : Liquid = get_cell_by_position(cell.get_x(), cell.get_y() + 1);
			if bottom_cell:
				bottom_amount = bottom_cell.new_amount;
			var flow : float = clamp(1 - bottom_amount, 0, min(max_flow_value, cell.new_amount));
			
			if flow != 0:
				if !bottom_cell:
					bottom_cell = _create_cell(cell.get_x(), cell.get_y() + 1, 0);
					new_cells.append(bottom_cell);
					_cells_positions[bottom_cell.get_uid()] = bottom_cell;
				bottom_cell.new_amount += flow;
				cell.bottom_has_flow = true;
				cell.new_amount -= flow;
				#print("flow bottom: ", cell.new_amount, " -> ", bottom_cell.new_amount, " (%f)" % [flow]);
		
		if cell.new_amount <= 0:
			request_queue_free(cell);
			continue;
		if _is_map_left_cell_empty(cell.get_x(), cell.get_y()):
			var left_amount : float = 0;
			var left_cell : Liquid = get_cell_by_position(cell.get_x() - 1, cell.get_y());
			if left_cell:
				left_amount = left_cell.new_amount;
			
			if left_amount < cell.new_amount:
				var flow : float = min((cell.new_amount - left_amount) / 1.2, max_flow_value);

				if flow > min_flow_value:
					if !left_cell:
						left_cell = _create_cell(cell.get_x() - 1, cell.get_y(), 0);
						new_cells.append(left_cell);
						_cells_positions[left_cell.get_uid()] = left_cell;
					left_cell.new_amount += flow;
					cell.new_amount -= flow;
					#print("flow left: ", cell.new_amount, " -> ", left_cell.new_amount, " (%f)" % [flow]);
		
		if cell.new_amount <= 0:
			request_queue_free(cell);
			continue;
		if _is_map_right_cell_empty(cell.get_x(), cell.get_y()):
			var right_amount : float = 0;
			var right_cell : Liquid = get_cell_by_position(cell.get_x() + 1, cell.get_y());
			if right_cell:
				right_amount = right_cell.new_amount;
			
			if right_amount < cell.new_amount:
				var flow : float = min((cell.new_amount - right_amount) / 1.2, max_flow_value);
				
				if flow > min_flow_value:
					if !right_cell:
						right_cell = _create_cell(cell.get_x() + 1, cell.get_y(), 0);
						new_cells.append(right_cell);
						_cells_positions[right_cell.get_uid()] = right_cell;
					right_cell.new_amount += flow;
					cell.new_amount -= flow;
					#print("flow right: ", cell.new_amount, " -> ", right_cell.new_amount, " (%f)" % [flow]);
		
		if cell.new_amount <= 0:
			request_queue_free(cell);
			continue;
		if _is_map_top_cell_empty(cell.get_x(), cell.get_y()):
			var top_cell : Liquid = get_cell_by_position(cell.get_x(), cell.get_y() - 1);
			var flow : float = min(max(cell.new_amount - 1.0, 0), max_flow_value);
			
			if flow != 0:
				if !top_cell:
					top_cell = _create_cell(cell.get_x(), cell.get_y() - 1, 0);
					new_cells.append(top_cell);
					_cells_positions[top_cell.get_uid()] = top_cell;
				top_cell.new_amount += flow; 
				cell.new_amount -= flow;
				#print("flow top: ", cell.new_amount, " -> ", top_cell.new_amount, " (%f)" % [flow]);
		if cell.new_amount <= 0:
			request_queue_free(cell);
	
	for cell in new_cells:
		_cells.append(cell);

	_total_amount = 0;
	var _updated : bool = false;
	for cell in _cells:
		if cell.amount == cell.new_amount:
			cell.iteration = min(cell.iteration + 1, max_iterations);
			if !_updated && cell.iteration < max_iterations:
				_updated = true;
		else:
			_updated = true;
			cell.amount = cell.new_amount;
			cell.iteration = 0;
			cell.changed.emit(self);
		#print("cell (%d, %d): %f" % [cell.get_x(), cell.get_y(), cell.amount])
		_total_amount += cell.amount;
	return _updated;
func _create_cell(x : int, y : int, amount : float):
	var instance : Liquid = liquid.instantiate();
	instance.config(x, y, amount, self);
	instance.created.emit(self);
	_container.add_child(instance);
	return instance;
func _get_map_cell_by_position(x : int, y : int, map : TileMapLayer = _map):
	var qx = x * _quadrant_size;
	var qy = y * _quadrant_size;

	var xx = floor(qx / float(map.rendering_quadrant_size));
	var yy = floor(qy / float(map.rendering_quadrant_size));

	return map.get_cell_source_id(Vector2(xx, yy));

#region Checking
func _is_map_top_cell_empty(x : int, y : int):
	return _is_map_cell_empty(x, y - 1, Vector2i(0, -1));
func _is_map_bottom_cell_empty(x : int, y : int):
	return _is_map_cell_empty(x, y + 1, Vector2i(0, 1), true);
func _is_map_left_cell_empty(x : int, y : int):
	return _is_map_cell_empty(x - 1, y, Vector2i(-1, 0));
func _is_map_right_cell_empty(x : int, y : int):
	return _is_map_cell_empty(x + 1, y, Vector2i(1, 0));
func _is_map_cell_empty(x : int, y : int, increments = Vector2i.ZERO, one_way : bool = false):
	for map in _maps:
		var map_cell = _get_map_cell_by_position(x, y, map.tile_map);

		if _get_map_cell_by_position(x - increments.x, y - increments.y, map.tile_map) != -1:
			continue;

		if map_cell != -1 && (!map.one_way_collision || one_way):
			return false;
	return true;
func _is_top_neightbor_valid(cell : Liquid):
	return cell.top && cell.top.amount >= min_amount;
func _is_bottom_neightbor_valid(cell : Liquid):
	return cell.bottom && cell.bottom.amount >= min_amount;
func _is_left_neightbor_valid(cell : Liquid):
	return cell.left && cell.left.amount >= min_amount;
func _is_right_neightbor_valid(cell : Liquid):
	return cell.right && cell.right.amount >= min_amount;
#endregion

#region API
## Check if the simulation is running.
func is_running() -> bool:
	return _started;
## Start the simulation. [br]
## [color=yellow]Warning:[/color] The simulation automatically starts when a [Liquid] is added or removed and stops when needed to optimize performance.
func start() -> void:
	_started = true;
## Stop the simulation. [br]
## [color=yellow]Warning:[/color] The simulation automatically starts when a [Liquid] is added or removed and stops when needed to optimize performance.
func stop() -> void:
	_started = false;
## Clear the simulation. [br]
## If [code]stop_after[/code] is [code]true[/code], the simulation will be stopped.
func clear(stop_after : bool = true) -> void:
	for cell in _cells:
		_container.remove_child(cell);
		cell.queue_free();
	_cells.clear();
	_cells_positions.clear();
	_total_amount = 0;
	if stop_after:
		stop();
## Add an amount of [Liquid] in a cell.
func add_liquid(x : int, y : int, amount : float) -> void:
	if !_is_map_cell_empty(x, y):
		return;
	var cell : Liquid = get_cell_by_position(x, y);
	if !cell:
		cell = _create_cell(x, y, amount);
		_cells.append(cell);
		_cells_positions[cell.get_uid()] = cell;
	else:
		cell.new_amount += amount;
	start();
## Remove an amount of [Liquid] in a cell.
func remove_liquid(x : int, y : int, amount : float) -> void:
	var cell : Liquid = get_cell_by_position(x, y);
	if cell:
		cell.new_amount -= amount;
		start();
## Update the amount of [Liquid] in a cell.
func update_liquid(x : int, y : int, amount : float) -> void:
	if !_is_map_cell_empty(x, y):
		return;
	var cell : Liquid = get_cell_by_position(x, y);
	if !cell:
		add_liquid(x, y, amount);
	else:
		cell.new_amount = amount;
	start();
## Get the amount of [Liquid] in a cell.
func get_liquid(x : int, y : int) -> float:
	var cell : Liquid = get_cell_by_position(x, y);
	if cell:
		return cell.amount;
	return 0;

#region Refresh
## Refresh [Liquid]'s sprite, neighboors and borders.
func refresh_cell(cell : Liquid) -> void:
	refresh_cell_neighboors(cell);
	refresh_cell_borders(cell);
	refresh_cell_sprite(cell);
	cell.refreshed.emit(self);
## Refresh [Liquid]'s borders if [code]check_boders[/code] is [code]true[/code].
func refresh_cell_borders(cell : Liquid) -> void:
	if !cell.check_borders:
		return;
	if cell.amount < min_amount:
		cell.border_top = false;
		cell.border_bottom = false;
		cell.border_left = false;
		cell.border_right = false;
	else:
		cell.border_top = !_is_top_neightbor_valid(cell) && _is_map_cell_empty(cell.get_x(), cell.get_y() - 1);
		cell.border_bottom = !_is_bottom_neightbor_valid(cell) && _is_map_cell_empty(cell.get_x(), cell.get_y() + 1);
		cell.border_left = !_is_left_neightbor_valid(cell) && _is_map_cell_empty(cell.get_x() - 1, cell.get_y());
		cell.border_right = !_is_right_neightbor_valid(cell) && _is_map_cell_empty(cell.get_x() + 1, cell.get_y());
## Refresh [Liquid]'s neighboors.
func refresh_cell_neighboors(cell : Liquid) -> void:
	cell.left = get_cell_by_position(cell.get_x() - 1, cell.get_y());
	cell.right = get_cell_by_position(cell.get_x() + 1, cell.get_y());
	cell.top = get_cell_by_position(cell.get_x(), cell.get_y() - 1);
	cell.bottom = get_cell_by_position(cell.get_x(), cell.get_y() + 1);
## Refresh [Liquid]'s sprite.
func refresh_cell_sprite(cell : Liquid) -> void:
	var translation : float;
	var scale : float = min(cell.amount, 1);

	if cell.top && (cell.top.amount >= min_amount || cell.top.bottom_has_flow):
		scale = 1;

	translation = (cell.height - floor(cell.height * scale)) / 2.0;
	if cell.snap_pixel:
		translation = (cell.height - floor(cell.height * scale)) / 2.0;
	else:
		translation = (cell.height - (cell.height * scale)) / 2.0;
		
	var qx = cell.get_x() * _quadrant_size;
	var qy = cell.get_y() * _quadrant_size;
	
	var rx = (qx % _map.rendering_quadrant_size);
	var ry = (qy % _map.rendering_quadrant_size);

	var xx = floor(qx / float(_map.rendering_quadrant_size));
	var yy = floor(qy / float(_map.rendering_quadrant_size));

	var diff = _map.rendering_quadrant_size - _quadrant_size;

	cell.position = _map.map_to_local(Vector2(xx, yy)) - Vector2((diff/2.0) - rx, (diff/2.0) - ry);

	cell.sprite.scale = cell.fix_scale(Vector2(cell.sprite.scale.x, (cell.height / cell.texture_height) * scale));
	cell.sprite.position = Vector2(0, translation);
## Refresh all [Liquid]'s sprites, neighboors and borders.
func refresh_all() -> void:
	for cell in _cells:
		refresh_cell(cell);
#endregion

#region Getters
## Get simulation's quadrant size.
func get_quadrant_size() -> int:
	return _quadrant_size;
## Get simulation's total amount. [br]
## The total amount is the sum of all [Liquid].
func get_total_amount() -> float:
	return _total_amount;
## Get simulation's map.
func get_map() -> TileMapLayer:
	return _map;
## Get simulation's container.
func get_container() -> Node2D:
	return _container;
## Get simulation's [Liquid] by [code]uuid[/code].
func get_cell_by_uid(uid : int) -> Liquid:
	return _cells_positions.get(uid);
## Get simulation's [Liquid] by [code]position[/code].
func get_cell_by_position(x : int, y : int) -> Liquid:
	var uid : int = Liquid.hash_position(x, y);
	return _cells_positions.get(uid);
#endregion

#region Lifecycle
## Put a [Liquid] in the queue to be removed.
func request_queue_free(cell : Liquid) -> void:
	if cell.iteration > cleanup_min_iterations:
		#print("clear: %f  %f" % [cell.amount, cell.new_amount]);
		cleanup_cell(cell);
## Remove a [Liquid] from the simulation. [br]
## [color=yellow]Warning:[/color] The method [code]queue_free[/code] is called too.
func cleanup_cell(cell : Liquid) -> void:
	cell.new_amount = 0;
	cell.amount = 0;
	_cells.erase(cell);
	_cells_positions.erase(cell.get_uid());
	cell.queue_free();
#endregion
#endregion

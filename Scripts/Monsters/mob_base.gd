# res://Actors/MobBase.gd
class_name MobBase
extends CharacterBody3D

# ---------------------------------------------------------------------
# Core stats (base values; overridable via setup(config))
# ---------------------------------------------------------------------
@export var base_health: int = 20
@export var base_damage: int = 5
@export var base_move_speed: float = 3.0
@export var base_attack_speed: float = 1.0   # attacks per second
@export var base_attack_range: float = 1.0

# Movement / physics
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
@export var floor_snap: float = 0.05

# Climbing / stepping helpers
@export var step_height: float = 0.6
@export var step_clearance: float = 0.12
@export var wall_detect_dot: float = 0.2
@export var climb_up_boost: float = 2.0

# Visual / mesh
@export_node_path("GeometryInstance3D") var mesh_path: NodePath

# ---------------------------------------------------------------------
# Animation wiring
# ---------------------------------------------------------------------
@export_node_path("AnimationPlayer") var anim_player_path: NodePath
@export var anim_group:  StringName = &""     # e.g. "Skeleton", "Bat"
@export var anim_spawn:  StringName = &"Spawn"
@export var anim_idle:   StringName = &"Idle"
@export var anim_run:    StringName = &"Run"
@export var anim_death:  StringName = &"Death"
@export var anim_attack: StringName = &"Attack"

# ---------------------------------------------------------------------
# Runtime vars
# ---------------------------------------------------------------------
var health: int
var damage: int
var move_speed: float
var attack_speed: float
var attack_range: float

var _attack_cd: float = 0.0
var _attack_range_sq: float = 1.0
var _tower: Node3D = null
var _move_dir: Vector3 = Vector3.ZERO
var _mesh_cached: GeometryInstance3D = null
var _anim_player: AnimationPlayer = null

enum State { SPAWN, IDLE, RUN, ATTACK }
var _state: State = State.SPAWN

# ---------------------------------------------------------------------
# Spawner hook
# ---------------------------------------------------------------------
func setup(config: Dictionary) -> void:
	health = int(config.get("health", base_health))
	damage = int(config.get("damage", base_damage))
	move_speed = float(config.get("speed", base_move_speed))
	attack_speed = float(config.get("attack_speed", base_attack_speed))
	attack_range = float(config.get("attack_range", base_attack_range))

	if config.has("scale"):
		scale = Vector3.ONE * float(config["scale"])
	if config.has("tint"):
		_apply_tint(config["tint"])

# ---------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------
func _ready() -> void:
	if health == 0: health = base_health
	if damage == 0: damage = base_damage
	if move_speed == 0.0: move_speed = base_move_speed
	if attack_speed == 0.0: attack_speed = base_attack_speed
	if attack_range == 0.0: attack_range = base_attack_range

	_attack_range_sq = attack_range * attack_range
	_tower = _get_tower()
	add_to_group("monsters")

	up_direction = Vector3.UP
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = floor_snap

	_mesh_cached = _get_mesh()
	_anim_player = get_node_or_null(anim_player_path) as AnimationPlayer
	if _anim_player:
		_anim_player.animation_finished.connect(_on_animation_finished)

	var spawn_name := _resolve_anim(anim_spawn)
	if _anim_player and _anim_player.has_animation(spawn_name):
		_play(spawn_name)
		_state = State.SPAWN
	else:
		_set_state(State.IDLE)

func _physics_process(delta: float) -> void:
	if _attack_cd > 0.0:
		_attack_cd -= delta
	if _state == State.SPAWN:
		return
	move_and_attack_tower(delta)

# ---------------------------------------------------------------------
# Shared AI: move → face → attack tower
# ---------------------------------------------------------------------
func move_and_attack_tower(delta: float) -> void:
	if _tower == null or not _tower.is_inside_tree():
		_tower = _get_tower()
		if _tower == null:
			velocity.x = 0.0
			velocity.z = 0.0
			_move_dir = Vector3.ZERO
			_set_state(State.IDLE)
			_apply_gravity_and_move(delta)
			return

	var dx := _tower.global_position.x - global_position.x
	var dz := _tower.global_position.z - global_position.z
	var dist_sq := dx * dx + dz * dz

	if dist_sq <= _attack_range_sq:
		velocity.x = 0.0
		velocity.z = 0.0
		_move_dir = Vector3.ZERO
		var yaw := atan2(dx, dz)
		rotation.y = lerp_angle(rotation.y, yaw, 8.0 * delta)
		if _state != State.ATTACK:
			_set_state(State.ATTACK)
		try_attack()
	else:
		var inv_len: float = 1.0 / max(1e-6, sqrt(dist_sq))
		velocity.x = dx * inv_len * move_speed
		velocity.z = dz * inv_len * move_speed
		_move_dir = Vector3(dx, 0.0, dz) * inv_len
		var yaw2 := atan2(dx, dz)
		rotation.y = lerp_angle(rotation.y, yaw2, 5.0 * delta)
		if _state != State.RUN:
			_set_state(State.RUN)

	_apply_gravity_and_move(delta)

# ---------------------------------------------------------------------
# Attack cadence
# ---------------------------------------------------------------------
func try_attack() -> void:
	if _attack_cd <= 0.0:
		_attack_cd = max(0.01, 1.0 / max(attack_speed, 0.01))
		_on_attack()
		_play_attack_once()

func _on_attack() -> void:
	if _tower and is_instance_valid(_tower) and "take_damage" in _tower:
		_tower.take_damage(damage)

# ---------------------------------------------------------------------
# Movement helpers (wall-glide + auto-step)
# ---------------------------------------------------------------------
func _apply_gravity_and_move(delta: float) -> void:
	if !is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

	if _move_dir.length() > 0.001:
		var hit_wall := false
		for i in range(get_slide_collision_count()):
			var c := get_slide_collision(i)
			var n := c.get_normal()
			if n.dot(Vector3.UP) < wall_detect_dot:
				hit_wall = true
				var horiz := Vector3(velocity.x, 0.0, velocity.z)
				var along_plane := horiz - n * horiz.dot(n)
				if horiz.dot(-n) > 0.0 and along_plane.length() > 0.001:
					velocity.x = along_plane.x
					velocity.z = along_plane.z
					velocity.y = max(velocity.y, climb_up_boost)
		if hit_wall:
			move_and_slide()

	if is_on_floor() and _move_dir.length() > 0.001 and is_on_wall_only():
		_try_step_up()

func _try_step_up() -> void:
	var prev_pos := global_position
	var prev_vel := velocity
	var up := Vector3.UP * step_height
	if test_move(global_transform, up):
		return
	global_position += up
	var forward := _move_dir * step_clearance
	if test_move(global_transform, forward):
		global_position = prev_pos
		velocity = prev_vel
		return
	global_position += forward
	velocity = prev_vel
	move_and_slide()
	if global_position.distance_squared_to(prev_pos) < 1e-6:
		global_position = prev_pos
		velocity = prev_vel

# ---------------------------------------------------------------------
# Damage / death
# ---------------------------------------------------------------------
func take_damage(amount: int) -> void:
	if _state == State.SPAWN:
		return
	health -= amount
	_on_health_changed()
	if health <= 0:
		die()

func _on_health_changed() -> void:
	_flash_red()

func die() -> void:
	if _state == State.SPAWN:
		return
	_state = State.SPAWN
	velocity = Vector3.ZERO
	var death_name := _resolve_anim(anim_death)
	if _anim_player and _anim_player.has_animation(death_name):
		for c in _anim_player.animation_finished.get_connections():
			if c.callable == Callable(self, "_on_death_finished"):
				_anim_player.animation_finished.disconnect(_on_death_finished)
		_anim_player.animation_finished.connect(_on_death_finished)
		_anim_player.play(death_name)
	else:
		_on_die()
		queue_free()

func _on_death_finished(anim_name: StringName) -> void:
	if anim_name == _resolve_anim(anim_death):
		_on_die()
		queue_free()

func _on_die() -> void:
	pass

# ---------------------------------------------------------------------
# Animation helpers
# ---------------------------------------------------------------------
func _resolve_anim(clip: StringName) -> StringName:
	if _anim_player == null:
		return clip

	# Prefer "Group/Clip" if a group is set and exists
	if anim_group != &"":
		var qualified := "%s/%s" % [anim_group, clip]
		if _anim_player.has_animation(qualified):
			return qualified

	# Fallback: try unqualified name
	if _anim_player.has_animation(clip):
		return clip

	# Debug output if nothing found
	print("⚠️ Animation not found:", clip, "or", anim_group, "/", clip)
	return clip

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == _resolve_anim(anim_spawn):
		_set_state(State.IDLE)

func _set_state(next: State) -> void:
	if _state == next:
		return
	_state = next
	match _state:
		State.IDLE:
			_play(_resolve_anim(anim_idle))
		State.RUN:
			_play(_resolve_anim(anim_run))
		State.ATTACK:
			_play_attack_once()
		State.SPAWN:
			_play(_resolve_anim(anim_spawn))

func _play(name: StringName) -> void:
	print("playing:", name)
	if _anim_player and _anim_player.has_animation(name) and _anim_player.current_animation != name:
		_anim_player.play(name)

func _play_attack_once() -> void:
	if _anim_player == null:
		return
	var name := _resolve_anim(anim_attack)
	if not _anim_player.has_animation(name):
		return
	var clip := _anim_player.get_animation(name)
	if clip == null:
		return
	var original_len: float = maxf(0.001, clip.length)
	var desired_len: float = maxf(0.05, 1.0 / max(attack_speed, 0.01))
	var speed_scale: float = clampf(original_len / desired_len, 0.1, 5.0)
	_anim_player.play(name, -1.0, speed_scale, false)
	_anim_player.seek(0.0, true)

# ---------------------------------------------------------------------
# Tower / mesh / visuals
# ---------------------------------------------------------------------
func _get_tower() -> Node3D:
	for n in get_tree().get_nodes_in_group("tower"):
		if n is Node3D and n.is_inside_tree():
			return n as Node3D
	return null

func _get_mesh() -> GeometryInstance3D:
	if _mesh_cached and is_instance_valid(_mesh_cached):
		return _mesh_cached
	if mesh_path != NodePath("") and has_node(mesh_path):
		_mesh_cached = get_node(mesh_path) as GeometryInstance3D
	else:
		var found := find_children("", "GeometryInstance3D", true, false)
		if found.size() > 0:
			_mesh_cached = found[0] as GeometryInstance3D
	return _mesh_cached

func _apply_tint(value) -> void:
	var mesh := _get_mesh()
	#if mesh == null:
		#return
	#var mat := mesh.material_override
	#if mat == null:
		#mat = StandardMaterial3D.new()
		#mesh.material_override = mat
	#if mat is StandardMaterial3D:
		#var c: Color = value if value is Color else Color(value)
		#mat.albedo_color = c

func _flash_red() -> void:
	var mesh := _get_mesh()
	if mesh == null:
		return
	var original := mesh.material_override
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.2, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.1, 0.1)
	mesh.material_override = mat
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(mesh):
		mesh.material_override = original

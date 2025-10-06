extends CharacterBody3D

@export var speed: float = 3.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
@export var attack_range: float = 1.0
@export var attack_damage: int = 1
@export var attack_interval: float = 0.8

@export var max_health: int = 2000
var health: int

@export_node_path("GeometryInstance3D") var mesh_path: NodePath
@onready var mesh: GeometryInstance3D = get_node_or_null(mesh_path) as GeometryInstance3D

@export_node_path("AnimationPlayer") var anim_player_path: NodePath
@export var anim_spawn:  StringName = &"Skeleton/Spawn"
@export var anim_idle:   StringName = &"Skeleton/Idle"
@export var anim_run:    StringName = &"Skeleton/Run"
@export var anim_death:  StringName = &"Skeleton/Death"
@export var anim_attack: StringName = &"Skeleton/Attack"
@onready var anim_player: AnimationPlayer = get_node(anim_player_path) as AnimationPlayer

enum State { SPAWN, IDLE, RUN, ATTACK }
var state: State = State.SPAWN

var _attack_cd: float = 0.0
var _tower: Node3D = null
var _attack_range_sq: float = 1.0

# Movement
var _stall_cd: float = 0.0           # time left to stay stalled (seconds)
var _stuck_accum: float = 0.0        # how long we've been not making progress
var _prev_pos: Vector3               # last frame world pos
var _rng := RandomNumberGenerator.new()

const _STUCK_SAMPLE_TIME := 0.12     # how long with no movement to call it stuck
const _STALL_MIN := 0.50             # stall duration range
const _STALL_MAX := 0.80
const _MIN_MOVE_SQ := 0.000025       # ~0.005 m squared


func _ready() -> void:
	add_to_group("monsters")
	
	_rng.randomize()
	_prev_pos = global_position
	
	health = max_health
	_attack_range_sq = attack_range * attack_range
	_tower = _get_tower()

	if anim_player and anim_player.has_animation(anim_spawn):
		anim_player.animation_finished.connect(_on_animation_finished)
		_play(anim_spawn)
		state = State.SPAWN
	else:
		_set_state(State.IDLE)

func _physics_process(delta: float) -> void:
	if state == State.SPAWN:
		return

	# cooldowns
	if _attack_cd > 0.0:
		_attack_cd -= delta
	if _stall_cd > 0.0:
		_stall_cd -= delta

	# refresh tower (cheap)
	if _tower == null or not _tower.is_inside_tree():
		_tower = _get_tower()
		if _tower == null:
			velocity.x = 0.0; velocity.z = 0.0
			_set_state(State.IDLE)
			_apply_gravity_and_move(delta)
			_prev_pos = global_position
			return

	# horizontal vector to tower
	var dx := _tower.global_position.x - global_position.x
	var dz := _tower.global_position.z - global_position.z
	var dist_sq := dx*dx + dz*dz

	# if currently stalled, just stay idle and skip steering
	if _stall_cd > 0.0:
		velocity.x = 0.0; velocity.z = 0.0
		if dist_sq > _attack_range_sq and state != State.IDLE:
			_set_state(State.IDLE)
		_apply_gravity_and_move(delta)
		_prev_pos = global_position
		return

	if dist_sq <= _attack_range_sq:
		# ATTACK: face + hit on cooldown
		velocity.x = 0.0; velocity.z = 0.0
		var yaw := atan2(dx, dz)
		rotation.y = lerp_angle(rotation.y, yaw, 8.0 * delta)
		if state != State.ATTACK: _set_state(State.ATTACK)
		if _attack_cd <= 0.0 and "take_damage" in _tower:
			_tower.take_damage(attack_damage)
			_attack_cd = attack_interval
			_play_attack_once()
	else:
		# MOVE: steer toward tower
		var inv_len := 1.0 / sqrt(dist_sq)
		velocity.x = dx * inv_len * speed
		velocity.z = dz * inv_len * speed
		var yaw2 := atan2(dx, dz)
		rotation.y = lerp_angle(rotation.y, yaw2, 5.0 * delta)
		if state != State.RUN: _set_state(State.RUN)

	# apply gravity + move
	_apply_gravity_and_move(delta)

	# --- stuck detection (after moving) ---
	var mdx := global_position.x - _prev_pos.x
	var mdz := global_position.z - _prev_pos.z
	var moved_sq := mdx*mdx + mdz*mdz

	var trying_to_move := (state == State.RUN)
	if trying_to_move and moved_sq < _MIN_MOVE_SQ:
		_stuck_accum += delta
		if _stuck_accum >= _STUCK_SAMPLE_TIME:
			# stall for a short random time to de-sync clogs
			_stall_cd = _rng.randf_range(_STALL_MIN, _STALL_MAX)
			_stuck_accum = 0.0
			velocity.x = 0.0; velocity.z = 0.0
			_set_state(State.IDLE)
	else:
		_stuck_accum = 0.0

	_prev_pos = global_position


func _apply_gravity_and_move(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

# --- damage / death ---
func take_damage(amount: int) -> void:
	if state == State.SPAWN:
		return
	health -= amount
	_flash_red()
	if health <= 0:
		die()

func die() -> void:
	if state == State.SPAWN:
		return
	state = State.SPAWN
	velocity = Vector3.ZERO
	if anim_player and anim_player.has_animation(anim_death):
		anim_player.play(anim_death)
		anim_player.animation_finished.connect(_on_death_finished)
	else:
		queue_free()

func _on_death_finished(anim_name: StringName) -> void:
	if anim_name == anim_death:
		queue_free()

# --- anim/state helpers ---
func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == anim_spawn:
		_set_state(State.IDLE)

func _set_state(next: State) -> void:
	if state == next:
		return
	state = next
	match state:
		State.IDLE:   _play(anim_idle)
		State.RUN:    _play(anim_run)
		State.ATTACK: _play(anim_attack)
		State.SPAWN:  _play(anim_spawn)

func _play(name: StringName) -> void:
	if anim_player and anim_player.has_animation(name) and anim_player.current_animation != name:
		anim_player.play(name)

func _play_attack_once() -> void:
	if anim_player == null or not anim_player.has_animation(anim_attack):
		return

	var clip: Animation = anim_player.get_animation(anim_attack)
	if clip == null:
		return

	var original_len: float = maxf(0.001, clip.length)
	var desired_len: float = maxf(0.05, attack_interval)   # don’t let it get too tiny
	var speed_scale: float = original_len / desired_len
	speed_scale = clampf(speed_scale, 0.1, 5.0)

	# play once, restart from the beginning at the computed speed
	anim_player.play(anim_attack, -1.0, speed_scale, false)
	anim_player.seek(0.0, true)

# --- tower lookup ---
func _get_tower() -> Node3D:
	for n in get_tree().get_nodes_in_group("tower"):
		if n is Node3D and n.is_inside_tree():
			return n as Node3D
	return null

# --- hit flash ---
func _flash_red() -> void:
	if mesh == null:
		var found := find_children("", "GeometryInstance3D", true, false)
		if found.size() == 0:
			return
		mesh = found[0] as GeometryInstance3D

	var original: Material = mesh.material_override
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.2, 0.2)
	mat.emission_enabled = true
	mat.emission = Color(1, 0.1, 0.1)
	mesh.material_override = mat
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(mesh):
		mesh.material_override = original

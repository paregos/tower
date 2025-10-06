extends CharacterBody3D

# --- tuning ---
@export var speed: float = 3.0
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float

# Combat
@export var attack_range: float = 1.0
@export var attack_damage: int = 1
@export var attack_interval: float = 0.8

# Health
@export var max_health: int = 2000
var health: int

# Visuals / Anim
@export_node_path("GeometryInstance3D") var mesh_path: NodePath
@onready var mesh: GeometryInstance3D = get_node_or_null(mesh_path) as GeometryInstance3D

@export_node_path("AnimationPlayer") var anim_player_path: NodePath
@export var anim_spawn:  StringName = &"Skeleton/Spawn"
@export var anim_idle:   StringName = &"Skeleton/Idle"
@export var anim_run:    StringName = &"Skeleton/Run"
@export var anim_death:  StringName = &"Skeleton/Death"
@export var anim_attack: StringName = &"Skeleton/Attack"
@onready var anim_player: AnimationPlayer = get_node(anim_player_path) as AnimationPlayer

# AI
enum State { SPAWN, IDLE, RUN, ATTACK }
var state: State = State.SPAWN
var _attack_cd: float = 0.0
var _tower: Node3D = null
var _attack_range_sq: float = 1.0

# --- climbing / stepping ---
@export var step_height: float = 0.6      # max ledge height to auto-step
@export var step_clearance: float = 0.12  # small forward seat after lift
@export var wall_detect_dot: float = 0.2  # < 0.2 => treat as wall (near vertical)
@export var climb_up_boost: float = 2.0   # upward nudge when hugging walls
@export var floor_snap: float = 0.05      # small snap helps stick to ground with Jolt

var _move_dir: Vector3 = Vector3.ZERO     # normalized horizontal intent

func _ready() -> void:
	add_to_group("monsters")
	health = max_health
	_attack_range_sq = attack_range * attack_range
	_tower = _get_tower()

	# Jolt-friendly defaults (fine with standard backend too)
	up_direction = Vector3.UP
	floor_max_angle = deg_to_rad(50.0)     # allow steeper ramps if you have them
	floor_snap_length = floor_snap         # tiny snap for contact stability

	if anim_player and anim_player.has_animation(anim_spawn):
		anim_player.animation_finished.connect(_on_animation_finished)
		_play(anim_spawn)
		state = State.SPAWN
	else:
		_set_state(State.IDLE)

func _physics_process(delta: float) -> void:
	if GameManager.state != GameManager.State.PLAYING:
		return
	
	if state == State.SPAWN:
		return

	# cooldowns
	if _attack_cd > 0.0:
		_attack_cd -= delta

	# refresh tower (cheap)
	if _tower == null or not _tower.is_inside_tree():
		_tower = _get_tower()
		if _tower == null:
			velocity.x = 0.0; velocity.z = 0.0
			_move_dir = Vector3.ZERO
			_set_state(State.IDLE)
			_apply_gravity_and_move(delta)
			return

	# vector to tower (XZ only)
	var dx := _tower.global_position.x - global_position.x
	var dz := _tower.global_position.z - global_position.z
	var dist_sq := dx*dx + dz*dz

	if dist_sq <= _attack_range_sq:
		# ATTACK
		velocity.x = 0.0; velocity.z = 0.0
		_move_dir = Vector3.ZERO
		var yaw := atan2(dx, dz)
		rotation.y = lerp_angle(rotation.y, yaw, 8.0 * delta)
		if state != State.ATTACK: _set_state(State.ATTACK)
		if _attack_cd <= 0.0 and "take_damage" in _tower:
			_tower.take_damage(attack_damage)
			_attack_cd = attack_interval
			_play_attack_once()
			return
	else:
		# RUN toward tower
		var inv_len := 1.0 / sqrt(dist_sq)
		velocity.x = dx * inv_len * speed
		velocity.z = dz * inv_len * speed
		_move_dir = Vector3(dx, 0.0, dz) * inv_len
		var yaw2 := atan2(dx, dz)
		rotation.y = lerp_angle(rotation.y, yaw2, 5.0 * delta)
		if state != State.RUN: _set_state(State.RUN)

	# move with climbing helpers
	_apply_gravity_and_move(delta)


# --- movement core with wall-glide + auto-step ---
func _apply_gravity_and_move(delta: float) -> void:
	# gravity
	if !is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# first slide
	move_and_slide()

	# Wall glide + gentle lift (prevents sticking on near-vertical faces)
	if _move_dir.length() > 0.001:
		var hit_wall := false
		for i in range(get_slide_collision_count()):
			var c := get_slide_collision(i)
			var n := c.get_normal()
			# treat near-vertical as walls (ignore floors/ramps)
			if n.dot(Vector3.UP) < wall_detect_dot:
				hit_wall = true
				# remove into-the-wall horizontal component
				var horiz := Vector3(velocity.x, 0.0, velocity.z)
				var along_plane := horiz - n * horiz.dot(n)
				# only redirect if pressing into wall
				if horiz.dot(-n) > 0.0 and along_plane.length() > 0.001:
					velocity.x = along_plane.x
					velocity.z = along_plane.z
					velocity.y = max(velocity.y, climb_up_boost)
		if hit_wall:
			move_and_slide()  # re-resolve with adjusted velocity

	# Auto-step over low ledges when grounded and blocked
	if is_on_floor() and _move_dir.length() > 0.001 and is_on_wall_only():
		_try_step_up()


func _try_step_up() -> void:
	# Save state to revert if step fails
	var prev_pos := global_position
	var prev_vel := velocity

	# Try a clear lift
	var up := Vector3.UP * step_height
	if test_move(global_transform, up):
		return # blocked above

	# Move up temporarily
	global_position += up

	# Tiny forward seat
	var forward := _move_dir * step_clearance
	if test_move(global_transform, forward):
		# still blocked -> revert
		global_position = prev_pos
		velocity = prev_vel
		return

	global_position += forward

	# Reattempt motion from the lifted position
	velocity = prev_vel
	move_and_slide()

	# Safety: if nothing changed, revert
	if global_position.distance_squared_to(prev_pos) < 1e-6:
		global_position = prev_pos
		velocity = prev_vel


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
	var desired_len: float = maxf(0.05, attack_interval)
	var speed_scale: float = clampf(original_len / desired_len, 0.1, 5.0)
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

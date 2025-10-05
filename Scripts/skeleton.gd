extends CharacterBody3D

@export var speed: float = 0.3
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
@export var target: Vector3 = Vector3.ZERO

# add near the top of your skeleton script
@export_node_path("GeometryInstance3D") var mesh_path: NodePath
@onready var mesh: GeometryInstance3D = get_node_or_null(mesh_path) as GeometryInstance3D

@export_node_path("AnimationPlayer") var anim_player_path: NodePath
@export var anim_spawn: StringName = &"Skeleton/Spawn"
@export var anim_idle:  StringName = &"Skeleton/Idle"
@export var anim_run:   StringName = &"Skeleton/Run"
@export var anim_death: StringName = &"Skeleton/Death"


@onready var anim_player: AnimationPlayer = get_node(anim_player_path)

@export var max_health: int = 3
var health: int

enum State { SPAWN, IDLE, RUN }
var state: State = State.SPAWN

func _ready() -> void:
	add_to_group("monsters")
	health = max_health
	if anim_player and anim_player.has_animation(anim_spawn):
		anim_player.animation_finished.connect(_on_animation_finished)
		_play(anim_spawn)
		state = State.SPAWN
	else:
		_set_state(State.IDLE)

func take_damage(amount: int) -> void:
	if state == State.SPAWN:
		return
	health -= amount
	_flash_red()  # <- add this line
	if health <= 0:
		die()

func _flash_red() -> void:
	if mesh == null:
		# auto-find first visible mesh under this character if not wired
		var found := find_children("", "GeometryInstance3D", true, false)
		if found.size() == 0:
			return
		mesh = found[0] as GeometryInstance3D

	# Save current override, apply a red override, then restore
	var original: Material = mesh.material_override

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 0.2, 0.2)          # red tint
	mat.emission_enabled = true
	mat.emission = Color(1, 0.1, 0.1)              # subtle glow (optional)

	mesh.material_override = mat
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(mesh):
		mesh.material_override = original


func die() -> void:
	if state == State.SPAWN:
		return
	state = State.SPAWN  # lock movement
	velocity = Vector3.ZERO
	if anim_player and anim_player.has_animation(anim_death):
		anim_player.play(anim_death)
		anim_player.animation_finished.connect(_on_death_finished)
	else:
		queue_free()

func _on_death_finished(anim_name: StringName) -> void:
	if anim_name == anim_death:
		queue_free()

func _physics_process(delta: float) -> void:
	# skip all movement while spawning
	if state == State.SPAWN:
		return

	var dir := target - global_position
	dir.y = 0.0
	var dist := dir.length()

	if dist > 0.05:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed

		var target_yaw := atan2(dir.x, dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, 5.0 * delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	move_and_slide()

	if anim_player:
		var speed_xz := Vector2(velocity.x, velocity.z).length()
		if speed_xz > 0.01:
			_set_state(State.RUN)
		else:
			_set_state(State.IDLE)

func _on_animation_finished(anim_name: StringName) -> void:
	if anim_name == anim_spawn:
		_set_state(State.IDLE)

func _set_state(next: State) -> void:
	if state == next:
		return
	state = next
	match state:
		State.IDLE:
			_play(anim_idle)
		State.RUN:
			_play(anim_run)
		State.SPAWN:
			_play(anim_spawn)

func _play(name: StringName) -> void:
	if anim_player and anim_player.has_animation(name) and anim_player.current_animation != name:
		anim_player.play(name)

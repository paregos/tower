extends CharacterBody3D

@export var speed: float = 0.3
@export var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity") as float
@export var target: Vector3 = Vector3.ZERO

@export_node_path("AnimationPlayer") var anim_player_path: NodePath
@export var anim_spawn: StringName = &"Skeleton/Spawn"
@export var anim_idle:  StringName = &"Skeleton/Idle"
@export var anim_run:   StringName = &"Skeleton/Run"

@onready var anim_player: AnimationPlayer = get_node(anim_player_path)

enum State { SPAWN, IDLE, RUN }
var state: State = State.SPAWN

func _ready() -> void:
	if anim_player and anim_player.has_animation(anim_spawn):
		anim_player.animation_finished.connect(_on_animation_finished)
		_play(anim_spawn)
		state = State.SPAWN
	else:
		_set_state(State.IDLE)

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

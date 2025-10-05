extends Camera3D

@export var move_speed: float = 10.0
@export var boost_speed: float = 30.0
@export var mouse_sensitivity: float = 0.003
@export var scroll_speed: float = 2.0

var yaw: float = 0.0
var pitch: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, deg_to_rad(-89), deg_to_rad(89))
		rotation = Vector3(pitch, yaw, 0)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			translate_object_local(Vector3(0, 0, -scroll_speed * get_process_delta_time()))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			translate_object_local(Vector3(0, 0,  scroll_speed * get_process_delta_time()))

func _process(delta: float) -> void:
	var input_dir := Vector3.ZERO

	if Input.is_action_pressed("move_forward"):  input_dir.z -= 1
	if Input.is_action_pressed("move_back"):     input_dir.z += 1
	if Input.is_action_pressed("move_left"):     input_dir.x -= 1
	if Input.is_action_pressed("move_right"):    input_dir.x += 1
	if Input.is_action_pressed("move_up"):       input_dir.y += 1
	if Input.is_action_pressed("move_down"):     input_dir.y -= 1

	if input_dir != Vector3.ZERO:
		input_dir = input_dir.normalized()

	var speed := move_speed
	if Input.is_action_pressed("boost"):
		speed = boost_speed

	translate_object_local(input_dir * speed * delta)

extends CharacterBody2D

# ─────────────────────────────────────────────
#  MOVIMIENTO HORIZONTAL
# ─────────────────────────────────────────────
@export_group("Movimiento horizontal")
@export var max_speed := 300.0
@export var acceleration := 2400.0        # en el suelo
@export var deceleration := 2800.0        # frenado en el suelo
@export var turn_acceleration := 4000.0   # al cambiar de dirección (giro rápido)
@export var air_acceleration := 2000.0    # más control en el aire para saltos más largos
@export var air_deceleration := 900.0     # en el aire conserva más el impulso

# ─────────────────────────────────────────────
#  SALTO (se define por altura y tiempo, no por velocidad)
# ─────────────────────────────────────────────
@export_group("Salto")
@export var jump_height := 160.0          # píxeles que sube con el salto completo (antes 100)
@export var jump_time_to_peak := 0.42     # segundos hasta el punto más alto
@export var jump_time_to_descent := 0.34  # segundos para caer (más corto = caída más pesada)
@export var jump_cut_multiplier := 0.4    # al soltar el salto antes de tiempo
@export var coyote_time := 0.1            # margen para saltar después de salir de un borde
@export var jump_buffer_time := 0.12      # margen para pulsar salto antes de tocar el suelo

# ─────────────────────────────────────────────
#  CAÍDA
# ─────────────────────────────────────────────
@export_group("Caída")
@export var max_fall_speed := 1100.0      # más alto porque el salto también lo es
@export var fast_fall_multiplier := 1.6   # mantener S para caer más rápido
@export var apex_threshold := 70.0        # rango de velocidad Y que cuenta como "cima"
@export var apex_gravity_multiplier := 0.5

# Valores físicos derivados de la altura y el tiempo del salto
@onready var jump_velocity := -2.0 * jump_height / jump_time_to_peak
@onready var jump_gravity := 2.0 * jump_height / (jump_time_to_peak * jump_time_to_peak)
@onready var fall_gravity := 2.0 * jump_height / (jump_time_to_descent * jump_time_to_descent)

var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _was_jump_held := false
var _is_jumping := false


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	var jump_held := _is_jump_held()
	var jump_pressed := jump_held and not _was_jump_held
	var jump_released := not jump_held and _was_jump_held
	_was_jump_held = jump_held

	_update_timers(delta, on_floor, jump_pressed)
	_handle_jump(jump_released)
	_apply_gravity(delta, on_floor, jump_held)
	_handle_horizontal(delta, on_floor)

	move_and_slide()


func _update_timers(delta: float, on_floor: bool, jump_pressed: bool) -> void:
	# Coyote time: se recarga en el suelo y se gasta en el aire
	if on_floor:
		_coyote_timer = coyote_time
		_is_jumping = false
	else:
		_coyote_timer -= delta

	# Jump buffer: recuerda la pulsación unos instantes
	if jump_pressed:
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer -= delta


func _handle_jump(jump_released: bool) -> void:
	# Saltar si hay una pulsación reciente y estamos (o estábamos hace poco) en el suelo
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		_is_jumping = true

	# Salto variable: soltar antes de tiempo corta la subida
	if jump_released and _is_jumping and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
		_is_jumping = false


func _apply_gravity(delta: float, on_floor: bool, jump_held: bool) -> void:
	if on_floor:
		return

	var gravity := jump_gravity if velocity.y < 0.0 else fall_gravity

	# Flotación en la cima: da más control y se siente "jugoso"
	if jump_held and absf(velocity.y) < apex_threshold:
		gravity *= apex_gravity_multiplier

	var fall_limit := max_fall_speed
	if _is_fast_fall_held() and velocity.y > 0.0:
		gravity *= fast_fall_multiplier
		fall_limit *= fast_fall_multiplier

	velocity.y = minf(velocity.y + gravity * delta, fall_limit)


func _handle_horizontal(delta: float, on_floor: bool) -> void:
	var direction := _get_input_direction()
	var target_speed := direction * max_speed
	var rate: float

	if direction != 0.0:
		var turning := velocity.x != 0.0 and signf(direction) != signf(velocity.x)
		if turning:
			rate = turn_acceleration
		else:
			rate = acceleration if on_floor else air_acceleration
	else:
		rate = deceleration if on_floor else air_deceleration

	velocity.x = move_toward(velocity.x, target_speed, rate * delta)


# ─────────────────────────────────────────────
#  INPUT
# ─────────────────────────────────────────────
func _get_input_direction() -> float:
	var direction := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction += 1.0
	return direction


func _is_jump_held() -> bool:
	return Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP)


func _is_fast_fall_held() -> bool:
	return Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)

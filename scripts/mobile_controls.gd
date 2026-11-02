extends Control
class_name MobileControls

const MAX_JOYSTICK_RADIUS: float = 64.0
const JOYSTICK_DEADZONE: float = 0.12
const MAX_BUTTON_RADIUS: float = 42.0

var joystick_touch_index: int = -1
var look_touch_index: int = -1
var sprint_touch_index: int = -1
var jump_touch_index: int = -1
var joystick_position: Vector2 = Vector2.ZERO
var look_delta: Vector2 = Vector2.ZERO
var jump_requested: bool = false
var _mobile_enabled: bool = false

static func calculate_safe_insets(viewport_size: Vector2, screen_size: Vector2, safe_rect: Rect2i) -> Vector4:
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return Vector4.ZERO
	var scale := viewport_size / screen_size
	var right := float(screen_size.x - safe_rect.end.x) * scale.x
	var bottom := float(screen_size.y - safe_rect.end.y) * scale.y
	return Vector4(
		clampf(float(safe_rect.position.x) * scale.x, 0.0, viewport_size.x),
		clampf(float(safe_rect.position.y) * scale.y, 0.0, viewport_size.y),
		clampf(right, 0.0, viewport_size.x),
		clampf(bottom, 0.0, viewport_size.y)
	)

func _safe_area_insets(viewport_size: Vector2) -> Vector4:
	var screen_size := Vector2(DisplayServer.screen_get_size())
	var safe_rect := DisplayServer.get_display_safe_area()
	return calculate_safe_insets(viewport_size, screen_size, safe_rect)

static func joystick_vector(center: Vector2, touch_position: Vector2, radius: float, deadzone: float = JOYSTICK_DEADZONE) -> Vector2:
	if radius <= 0.0:
		return Vector2.ZERO
	var raw_vector := (touch_position - center) / radius
	var strength := raw_vector.length()
	if strength <= deadzone:
		return Vector2.ZERO
	var clamped_strength := minf(strength, 1.0)
	var remapped_strength := (clamped_strength - deadzone) / (1.0 - deadzone)
	return raw_vector.normalized() * remapped_strength

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mobile_enabled = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	visible = _mobile_enabled
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		joystick_touch_index = -1
		look_touch_index = -1
		sprint_touch_index = -1
		jump_touch_index = -1
		joystick_position = _joystick_center()
		look_delta = Vector2.ZERO
		jump_requested = false
		queue_redraw()

func _input(event: InputEvent) -> void:
	if not _mobile_enabled:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_touch(event.index, event.position)
		else:
			_end_touch(event.index)
	elif event is InputEventScreenDrag:
		if event.index == joystick_touch_index:
			joystick_position = event.position
			queue_redraw()
		elif event.index == look_touch_index:
			look_delta += event.relative

func _begin_touch(index: int, position: Vector2) -> void:
	var size := get_viewport_rect().size
	if position.x <= size.x * 0.45 and position.y >= size.y * 0.45 and joystick_touch_index == -1:
		joystick_touch_index = index
		joystick_position = position
	elif _is_sprint_button(position, size) and sprint_touch_index == -1:
		sprint_touch_index = index
	elif _is_jump_button(position, size) and jump_touch_index == -1:
		jump_touch_index = index
		jump_requested = true
	elif position.x >= size.x * 0.45 and look_touch_index == -1:
		look_touch_index = index

func _end_touch(index: int) -> void:
	if index == joystick_touch_index:
		joystick_touch_index = -1
		joystick_position = _joystick_center()
	elif index == look_touch_index:
		look_touch_index = -1
	elif index == sprint_touch_index:
		sprint_touch_index = -1
	elif index == jump_touch_index:
		jump_touch_index = -1
	queue_redraw()

func _joystick_radius() -> float:
	return minf(MAX_JOYSTICK_RADIUS, get_viewport_rect().size.x * 0.17)

func _button_radius(size: Vector2) -> float:
	return minf(MAX_BUTTON_RADIUS, size.x * 0.105)

func _joystick_center() -> Vector2:
	var size := get_viewport_rect().size
	var insets := _safe_area_insets(size)
	var margin := _joystick_radius() + 24.0
	return Vector2(maxf(margin + insets.x, size.x * 0.22), size.y - maxf(margin + insets.w, size.y * 0.19))

func _sprint_center(size: Vector2) -> Vector2:
	var radius := _button_radius(size)
	var insets := _safe_area_insets(size)
	return Vector2(size.x - radius * 3.5 - insets.z, size.y - radius * 2.3 - insets.w)

func _jump_center(size: Vector2) -> Vector2:
	var radius := _button_radius(size)
	var insets := _safe_area_insets(size)
	return Vector2(size.x - radius - insets.z, size.y - radius * 4.2 - insets.w)

func _is_sprint_button(position: Vector2, size: Vector2) -> bool:
	return position.distance_to(_sprint_center(size)) <= _button_radius(size) * 1.15

func _is_jump_button(position: Vector2, size: Vector2) -> bool:
	return position.distance_to(_jump_center(size)) <= _button_radius(size) * 1.15

func get_move_vector() -> Vector2:
	if joystick_touch_index == -1:
		return Vector2.ZERO
	return joystick_vector(_joystick_center(), joystick_position, _joystick_radius())

func is_sprint_pressed() -> bool:
	return sprint_touch_index != -1

func consume_jump_request() -> bool:
	var requested := jump_requested
	jump_requested = false
	return requested

func consume_look_delta() -> Vector2:
	var result := look_delta
	look_delta = Vector2.ZERO
	return result

func _draw() -> void:
	if not _mobile_enabled:
		return
	var size := get_viewport_rect().size
	var center := _joystick_center()
	var joystick_radius := _joystick_radius()
	var knob := center
	if joystick_touch_index != -1:
		var offset := joystick_position - center
		knob += offset.limit_length(joystick_radius)
	draw_circle(center, joystick_radius, Color(0.04, 0.06, 0.08, 0.34))
	draw_arc(center, joystick_radius, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.55), 2.0)
	draw_circle(knob, joystick_radius * 0.42, Color(0.88, 0.91, 0.94, 0.68))
	_draw_action_button(_sprint_center(size), "RUN", sprint_touch_index != -1)
	_draw_action_button(_jump_center(size), "JUMP", jump_touch_index != -1)

func _draw_action_button(center: Vector2, caption: String, pressed: bool) -> void:
	var radius := _button_radius(get_viewport_rect().size)
	var fill := Color(0.12, 0.16, 0.20, 0.78) if not pressed else Color(0.24, 0.48, 0.72, 0.92)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.72), 2.0)
	var font := ThemeDB.fallback_font
	var font_size := 15
	var text_size := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	draw_string(font, center + Vector2(-text_size.x * 0.5, 5.0), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

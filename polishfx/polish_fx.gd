class_name PolishFX
extends RefCounted
## PolishFX LITE — one-line juice for any CanvasItem (free edition).  (Tavryx)
##
## [codeblock]
## PolishFX.flash($Sprite2D)                     # white hit flash
## PolishFX.tint($Sprite2D, Color.GREEN, 0.6)    # poison tint (until untint)
## await PolishFX.dissolve_out($Enemy).finished  # burn away, awaitable
## PolishFX.shine($Coin)                         # gleam sweep
## PolishFX.pulse_outline($Sprite2D)             # one outline pulse
## [/codeblock]
##
## Live params are per-node instance uniforms: hundreds of sprites can share
## ONE material and still animate independently.
##
## ── This is the free LITE edition (8 effects). ─────────────────────────────
## The full version adds 20 more effects (glow, glitch, hologram, freeze,
## squash & stretch, sprite shake, hsv, rainbow, bulge, wave, ghost, sway,
## shadow, posterize…), 14 ready-made presets and the interactive gallery:
## https://tavryx.itch.io/polishfx

static var _shader: Shader = null


static func _polish_shader() -> Shader:
	if _shader == null:
		var dir := (PolishFX as GDScript).resource_path.get_base_dir()
		_shader = load(dir + "/polishfx.gdshader")
	return _shader


## Ensure the item carries the PolishFX material; returns it.
static func apply(item: CanvasItem) -> ShaderMaterial:
	var mat := item.material as ShaderMaterial
	if mat != null and mat.shader == _polish_shader():
		return mat
	if item.material != null:
		push_warning("PolishFX: replacing existing material on %s" % item.name)
	mat = ShaderMaterial.new()
	mat.shader = _polish_shader()
	item.material = mat
	return mat


# --- Tween lifecycle (deterministic cancellation) --------------------------
# Every one-liner returns an await-able Tween with these guarantees:
#  • one active helper tween per live param per node — a new call on the same
#    param CANCELS the previous tween (it is killed and its `finished` fires,
#    deferred to end-of-frame, so awaiters always resume), then starts fresh;
#    the cancelling call owns the parameter's state from that moment;
#  • clear() cancels ALL helper tweens the same way before resetting;
#  • when the node leaves the tree (queue_free/free/reparent) its helper
#    tweens are cancelled the same way;
#  → `await PolishFX.xxx(...).finished` can never stay pending forever.

static func _finish_tween(t: Tween) -> void:
	if t == null or not t.is_valid():
		return
	# Cancellation contract: the old tween is killed (the engine then never
	# emits its `finished`) and we emit `finished` OURSELVES, deferred to the
	# end of the frame. One deterministic emission, on every Godot 4.4+,
	# reaching awaiters registered before OR after the cancellation within
	# the frame. The cancelling call takes over the parameter's state.
	t.kill()
	t.finished.emit.call_deferred()


static func _finish_all_tweens(item: CanvasItem) -> void:
	var reg: Dictionary = item.get_meta(&"_pfx_tweens", {})
	item.set_meta(&"_pfx_tweens", {})
	for param in reg:
		_finish_tween(reg[param])


static func _on_item_exiting(item: CanvasItem) -> void:
	_finish_all_tweens(item)


static func _juice_tween(item: CanvasItem, param: StringName) -> Tween:
	var reg: Dictionary = item.get_meta(&"_pfx_tweens", {})
	_finish_tween(reg.get(param))
	if not item.get_meta(&"_pfx_exit_hooked", false):
		item.tree_exiting.connect(_on_item_exiting.bind(item))
		item.set_meta(&"_pfx_exit_hooked", true)
	var t := item.create_tween()
	reg = item.get_meta(&"_pfx_tweens", {})  # completion may have run user code
	reg[param] = t
	item.set_meta(&"_pfx_tweens", reg)
	return t


# Make this node's material its own copy, so material-level tweaks from
# one-liners never leak to other nodes sharing the same material. Ownership is
# tied to the material INSTANCE: re-sharing a material duplicates again.
static func _own_material(item: CanvasItem) -> ShaderMaterial:
	var mat := apply(item)
	if item.get_meta(&"_pfx_owned_mat", 0) != mat.get_instance_id():
		mat = mat.duplicate()
		item.material = mat
		item.set_meta(&"_pfx_owned_mat", mat.get_instance_id())
	return mat


## Set one live per-node parameter (fx_flash, fx_tint, fx_dissolve, fx_shine,
## fx_fade, fx_outline_boost).
static func set_fx(item: CanvasItem, param: StringName, value: Variant) -> void:
	apply(item)
	item.set_instance_shader_parameter(param, value)


## Set material ("look") uniforms from a dictionary, e.g.
## configure($Sprite2D, {"outline_enabled": true, "outline_color": Color.CYAN}).
static func configure(item: CanvasItem, settings: Dictionary) -> ShaderMaterial:
	var mat := apply(item)
	for key in settings:
		mat.set_shader_parameter(key, settings[key])
	return mat


## Reset every live per-node parameter to neutral (and stop any running
## PolishFX one-liner tweens so they can't re-animate old values).
static func clear(item: CanvasItem) -> void:
	_finish_all_tweens(item)
	if not (item.material is ShaderMaterial):
		return
	item.set_instance_shader_parameter(&"fx_flash", Color(1, 1, 1, 0))
	item.set_instance_shader_parameter(&"fx_tint", Color(1, 1, 1, 0))
	item.set_instance_shader_parameter(&"fx_dissolve", 0.0)
	item.set_instance_shader_parameter(&"fx_shine", 0.0)
	item.set_instance_shader_parameter(&"fx_fade", 1.0)
	item.set_instance_shader_parameter(&"fx_outline_boost", 1.0)


# --- One-line juice --------------------------------------------------------

## Flash the silhouette to a color and back. Returns the Tween (awaitable).
static func flash(item: CanvasItem, color: Color = Color.WHITE, duration: float = 0.16) -> Tween:
	var t := _juice_tween(item, &"fx_flash")
	set_fx(item, &"fx_flash", Color(color.r, color.g, color.b, maxf(color.a, 0.85)))
	t.tween_property(item, "instance_shader_parameters/fx_flash:a", 0.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return t


## Hold a status tint (poison green, burn red…). Remove with [method untint].
static func tint(item: CanvasItem, color: Color, amount: float = 0.7, duration: float = 0.2) -> Tween:
	var t := _juice_tween(item, &"fx_tint")
	var cur0 = item.get_instance_shader_parameter(&"fx_tint")
	var start_a := 0.0 if cur0 == null else (cur0 as Color).a
	set_fx(item, &"fx_tint", Color(color.r, color.g, color.b, start_a))
	t.tween_property(item, "instance_shader_parameters/fx_tint:a", amount, duration)
	return t


## Fade the current tint out.
static func untint(item: CanvasItem, duration: float = 0.25) -> Tween:
	var t := _juice_tween(item, &"fx_tint")
	var cur = item.get_instance_shader_parameter(&"fx_tint")
	set_fx(item, &"fx_tint", Color(1, 1, 1, 0) if cur == null else cur)
	t.tween_property(item, "instance_shader_parameters/fx_tint:a", 0.0, duration)
	return t


## Burn the sprite away (uses the material's Dissolve settings). Awaitable.
static func dissolve_out(item: CanvasItem, duration: float = 0.6) -> Tween:
	var t := _juice_tween(item, &"fx_dissolve")
	set_fx(item, &"fx_dissolve", 0.0)
	t.tween_property(item, "instance_shader_parameters/fx_dissolve", 1.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return t


## Re-materialize a dissolved sprite. Awaitable.
static func dissolve_in(item: CanvasItem, duration: float = 0.6) -> Tween:
	var t := _juice_tween(item, &"fx_dissolve")
	set_fx(item, &"fx_dissolve", 1.0)
	t.tween_property(item, "instance_shader_parameters/fx_dissolve", 0.0, duration)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return t


## Sweep one gleam across the sprite (uses the material's Shine settings).
static func shine(item: CanvasItem, duration: float = 0.7) -> Tween:
	var t := _juice_tween(item, &"fx_shine")
	set_fx(item, &"fx_shine", 0.0)
	t.tween_property(item, "instance_shader_parameters/fx_shine", 1.0, duration)
	t.tween_callback(func() -> void:
		if is_instance_valid(item):
			item.set_instance_shader_parameter(&"fx_shine", 0.0))
	return t


## Tween the sprite's alpha multiplier (0 = invisible).
static func fade(item: CanvasItem, to: float = 0.0, duration: float = 0.3) -> Tween:
	var t := _juice_tween(item, &"fx_fade")
	var cur = item.get_instance_shader_parameter(&"fx_fade")
	set_fx(item, &"fx_fade", 1.0 if cur == null else cur)
	t.tween_property(item, "instance_shader_parameters/fx_fade", to, duration)
	return t


## One outline pulse (enables Outline, then shrinks it away). Material-level
## tweak → this node's material is made unique first, so the pulse can never
## draw outlines on other sprites sharing the same material.
static func pulse_outline(item: CanvasItem, color: Color = Color.WHITE, width: float = 3.0,
		duration: float = 0.4) -> Tween:
	var t := _juice_tween(item, &"fx_outline_boost")
	var mat := _own_material(item)
	var was_enabled: bool = mat.get_shader_parameter("outline_enabled") == true
	mat.set_shader_parameter("outline_enabled", true)
	mat.set_shader_parameter("outline_color", color)
	mat.set_shader_parameter("outline_width", width)
	set_fx(item, &"fx_outline_boost", 1.6)
	t.tween_property(item, "instance_shader_parameters/fx_outline_boost", 0.0, duration)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(func() -> void:
		if is_instance_valid(item):
			item.set_instance_shader_parameter(&"fx_outline_boost", 1.0)
			if not was_enabled and item.material == mat:
				mat.set_shader_parameter("outline_enabled", false))
	return t

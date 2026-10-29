shader_type canvas_item;
// ============================================================================
//  PolishFX LITE — free edition · 8 stackable 2D sprite effects   (by Tavryx)
//
//  flash · tint · outline · dissolve · shine · fade · pixelate · grayscale
//  All combinable on one material, configurable from the Inspector.
//  The full version adds 20 more effects (glow, glitch, hologram, freeze,
//  squash & stretch, shake, hsv, rainbow, bulge, wave, ghost, …) plus 14
//  ready-made presets:  https://tavryx.itch.io/polishfx
//
//  • The [instance] params are per-node: many sprites can SHARE this material
//    while each one flashes/dissolves on its own (see the PolishFX class).
//  • Godot 4.4+ · Forward+/Mobile/Compatibility (incl. web).
// ============================================================================

group_uniforms Live_PerNode;
// Flash the whole silhouette to a color. rgb = color, a = strength 0..1.
instance uniform vec4 fx_flash : source_color = vec4(1.0, 1.0, 1.0, 0.0);
// Status tint. rgb = color, a = blend 0..1.
instance uniform vec4 fx_tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
// 0 = intact, 1 = fully dissolved (uses Dissolve group settings below).
instance uniform float fx_dissolve : hint_range(0.0, 1.0) = 0.0;
// Sweep a gleam band across the sprite: 0 = before, 1 = past (see Shine group).
instance uniform float fx_shine : hint_range(0.0, 1.0) = 0.0;
// Alpha multiplier.
instance uniform float fx_fade : hint_range(0.0, 1.0) = 1.0;
// Multiplies Outline width (1 = as configured). Animate for pulses.
instance uniform float fx_outline_boost : hint_range(0.0, 4.0) = 1.0;
group_uniforms;

group_uniforms Pixelate;
uniform bool pixelate_enabled = false;
uniform float pixelate_size : hint_range(1.0, 64.0) = 4.0;
group_uniforms;

group_uniforms Outline;
uniform bool outline_enabled = false;
uniform float outline_width : hint_range(0.0, 16.0) = 2.0;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
group_uniforms;

group_uniforms Grayscale;
uniform bool grayscale_enabled = false;
uniform float grayscale_amount : hint_range(0.0, 1.0) = 1.0;
group_uniforms;

group_uniforms Shine;
uniform float shine_width : hint_range(0.02, 0.6) = 0.18;
uniform float shine_angle : hint_range(-1.6, 1.6) = 0.5;
uniform vec4 shine_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float shine_intensity : hint_range(0.0, 2.0) = 0.9;
group_uniforms;

group_uniforms Dissolve;
uniform float dissolve_scale : hint_range(2.0, 80.0) = 22.0;
uniform float dissolve_edge : hint_range(0.0, 0.3) = 0.09;
uniform vec4 dissolve_edge_color : source_color = vec4(1.0, 0.62, 0.12, 1.0);
uniform float dissolve_edge_glow : hint_range(0.0, 4.0) = 1.6;
group_uniforms;

// Node tint (modulate * self_modulate), captured in vertex() where COLOR is
// the pure vertex color (in fragment() it already includes the texture).
varying vec4 v_modulate;

void vertex() {
	v_modulate = COLOR;
}

float pfx_hash(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float pfx_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = pfx_hash(i);
	float b = pfx_hash(i + vec2(1.0, 0.0));
	float c = pfx_hash(i + vec2(0.0, 1.0));
	float d = pfx_hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Source alpha at a UV (0 outside [0,1]) — macro so TEXTURE stays a direct
// built-in reference (passing it as a function arg trips the headless
// shader compiler with a harmless-but-noisy error).
#define PFX_A(P) ((((P).x < 0.0) || ((P).x > 1.0) || ((P).y < 0.0) || ((P).y > 1.0)) ? 0.0 : texture(TEXTURE, (P)).a)

void fragment() {
	vec2 uv = UV;
	vec2 texel = TEXTURE_PIXEL_SIZE;

	if (pixelate_enabled) {
		vec2 grid = texel * pixelate_size;
		uv = (floor(uv / grid) + 0.5) * grid;
	}

	vec4 col = texture(TEXTURE, uv);

	vec4 under = vec4(0.0);
	float ow = outline_width * fx_outline_boost;
	if (outline_enabled && ow > 0.01) {
		float edge = 0.0;
		for (int i = 0; i < 8; i++) {
			float ang = float(i) * 0.78539816;
			vec2 ouv = uv + vec2(cos(ang), sin(ang)) * ow * texel;
			edge = max(edge, PFX_A(ouv));
		}
		float ol = clamp(edge - col.a, 0.0, 1.0);
		vec4 oc = vec4(outline_color.rgb, ol * outline_color.a);
		under.rgb = mix(under.rgb, oc.rgb, min(oc.a * 4.0, 1.0));
		under.a = max(under.a, oc.a);
	}

	if (grayscale_enabled) {
		float g = dot(col.rgb, vec3(0.299, 0.587, 0.114));
		col.rgb = mix(col.rgb, vec3(g), grayscale_amount);
	}
	if (fx_shine > 0.001 && fx_shine < 0.999) {
		vec2 rot = vec2(cos(shine_angle), sin(shine_angle));
		float coord = dot(uv - 0.5, rot) + 0.5;
		float pos = mix(-shine_width, 1.0 + shine_width, fx_shine);
		float band = 1.0 - smoothstep(0.0, shine_width, abs(coord - pos));
		col.rgb += shine_color.rgb * band * shine_intensity * col.a;
	}
	col.rgb = mix(col.rgb, fx_tint.rgb, fx_tint.a);

	if (fx_dissolve > 0.001) {
		float d_edge = max(dissolve_edge, 0.001); // smoothstep(a,a,x) is UB
		float n = pfx_noise(uv * dissolve_scale);
		float span = 1.0 + d_edge * 2.0;
		float thr = fx_dissolve * span;
		float burn = smoothstep(thr - d_edge, thr, n + d_edge);
		col.rgb = mix(dissolve_edge_color.rgb * dissolve_edge_glow, col.rgb, burn);
		float keep = step(thr - d_edge * 2.0, n);
		col.a *= keep;
		under.a *= keep; // the outline burns away with the sprite
	}
	col.a *= fx_fade;
	under.a *= fx_fade;
	col.rgb = mix(col.rgb, fx_flash.rgb, fx_flash.a);

	// Proper "over" composite with un-premultiply (no dark fringes on soft art).
	float out_a = col.a + under.a * (1.0 - col.a);
	vec3 out_rgb = (col.rgb * col.a + under.rgb * under.a * (1.0 - col.a)) / max(out_a, 1e-5);
	COLOR = vec4(out_rgb, out_a) * v_modulate;
}

# PolishFX Lite — Changelog

## 1.0.0 — 2026-08-08
- Initial release (free edition, MIT).
- 8 stackable effects in one canvas_item uber-shader: hit flash, tint,
  outline, dissolve (burn edge), shine sweep, fade, pixelate, grayscale.
- 6 per-node live params via canvas instance uniforms (share one material
  across hundreds of sprites, animate each independently).
- Static `PolishFX` class, no autoload: apply, set_fx, configure, clear,
  flash, tint, untint, dissolve_out, dissolve_in, shine, fade, pulse_outline.
- Deterministic await semantics: a helper tween that is replaced, cleared or
  orphaned by the node leaving the tree COMPLETES instantly (its `finished`
  signal fires) — awaits never hang.
- Verified on Godot 4.4.1 / 4.5 / 4.6 / 4.7 — Forward+, Mobile and
  Compatibility (desktop + web export).
- The full version adds 20 more effects, 14 presets, shake/squash/
  glitch_burst/hue_spin/preset API and the interactive gallery.

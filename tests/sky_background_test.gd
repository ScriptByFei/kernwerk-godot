extends SceneTree

## Test suite for SkyBackground: Prüft Theme-Lookups, Interpolation und Datenintegrität.

const SkyBackground = preload("res://scripts/jump/sky_background.gd")

var failures := 0

func _init() -> void:
	_test_theme_lookups()
	_test_theme_interpolation()
	_test_theme_properties()
	print("SKY BACKGROUND: ALLE OK" if failures == 0 else "SKY BACKGROUND: %d FEHLER" % failures)
	quit(1 if failures > 0 else 0)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("  ✗ FAIL: ", msg)
	else:
		print("  ✓ ", msg)

func _test_theme_lookups() -> void:
	for idx in [0.0, 1.0, 2.0, 3.0, 4.0]:
		var theme := SkyBackground.get_theme(idx)
		_check(theme.has("sky_top") and theme.sky_top is Color, "theme %f has sky_top Color" % idx)
		_check(theme.has("sky_bottom") and theme.sky_bottom is Color, "theme %f has sky_bottom Color" % idx)
		_check(theme.has("cloud_body") and theme.cloud_body is Color, "theme %f has cloud_body Color" % idx)
		_check(theme.has("cloud_shadow") and theme.cloud_shadow is Color, "theme %f has cloud_shadow Color" % idx)
		_check(theme.has("ray_color") and theme.ray_color is Color, "theme %f has ray_color Color" % idx)

func _test_theme_interpolation() -> void:
	var t_mid := SkyBackground.get_theme(0.5)
	var t_0 := SkyBackground.get_theme(0.0)
	var t_1 := SkyBackground.get_theme(1.0)
	
	# Interpolated sky_top must lie between t_0 and t_1
	var expected_r := ((t_0.sky_top as Color).r + (t_1.sky_top as Color).r) * 0.5
	_check(is_equal_approx((t_mid.sky_top as Color).r, expected_r), "theme mid-point interpolates sky_top red component")
	
	# Out of bounds clamping check
	var t_neg := SkyBackground.get_theme(-2.0)
	var t_overflow := SkyBackground.get_theme(99.0)
	_check(t_neg.sky_top == t_0.sky_top, "negative zone index clamps to zone 0")
	var t_last := SkyBackground.get_theme(float(SkyBackground.SKY_THEMES.size() - 1))
	_check(t_overflow.sky_top == t_last.sky_top, "overflow zone index clamps to last zone")

func _test_theme_properties() -> void:
	# Zone 1 should have balloons but no stars
	var z1 := SkyBackground.get_theme(0.0)
	_check(z1.has_balloons == true, "Zone 1 has balloons")
	_check(z1.has_stars == false, "Zone 1 has no stars")
	_check(z1.has_aurora == false, "Zone 1 has no aurora")
	
	# Zone 5 should have aurora and stars, but no balloons
	var z5 := SkyBackground.get_theme(4.0)
	_check(z5.has_balloons == false, "Zone 5 has no balloons")
	_check(z5.has_stars == true, "Zone 5 has stars")
	_check(z5.has_aurora == true, "Zone 5 has aurora")

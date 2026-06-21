class_name PaletteParameterDef
extends abstractParameterDef

@export var default_colors: Array[Color] = [
	Color.BLACK,
	Color.WHITE
]

@export_range(2, 8)
var max_colors := 8


func get_color_count(value: Variant) -> int:
	var colors: Array = value

	if colors.is_empty():
		colors = default_colors

	return mini(colors.size(), max_colors)


func get_default_value() -> Variant:
	return default_colors

func generate_glsl_declaration(value: Variant, var_name: String) -> String:

	var colors: Array = value
	if colors.is_empty():
		colors = default_colors

	var lines := PackedStringArray()

	# fill actual colors
	for i in range(max_colors):
		if i < colors.size():
			var c: Color = colors[i]
			lines.append("vec3(%.3f, %.3f, %.3f)" % [c.r, c.g, c.b])
		else:
			lines.append("vec3(0.0)")

	return "vec3 %s[%d] = vec3[](\n\t%s\n);" % [
		var_name,
		max_colors,
		",\n\t".join(lines)
	]



func value_to_glsl(value: Variant,var_name: String = "") -> String:
	return var_name

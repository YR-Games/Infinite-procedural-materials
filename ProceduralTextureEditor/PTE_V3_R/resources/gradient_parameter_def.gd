class_name GradientParameterDef
extends abstract_parameter_def

# A default gradient used when no user value is set.
@export var default_value: Gradient = preload("res://PTE_V3_R/misc/default_gradient.tres")

# If true, the gradient will be embedded as an array of colors in the shader.
# If false, you might upload a texture at export time (advanced).
@export var embed_in_shader: bool = true
@export var max_stops: int = 8   # how many stops to embed

func value_to_glsl(value: Variant) -> String:
	# value should be a Gradient resource
	var grad: Gradient = value as Gradient
	if not grad:
		grad = default_value

	if embed_in_shader:
		return _gradient_to_glsl_array(grad)
	else:
		# Advanced – generate a texture uniform; not covered here.
		return "/* gradient texture uniform required */"


func _gradient_to_glsl_array(grad: Gradient) -> String:
	var colors = PackedStringArray()
	var offsets = PackedStringArray()
	var count = mini(grad.points_count, max_stops)

	for i in range(count):
		var point = grad.get_point(i)
		colors.append("vec4(%.6f, %.6f, %.6f, %.6f)" % [point.color.r, point.color.g, point.color.b, point.color.a])
		offsets.append(str(point.offset))

	# Produce a function that takes a float and returns a vec4.
	# Simple step interpolation (you can add smoothing later).
	return (
		"vec4 gradient_sample(float t) {\n" +
		"\tvec4 colors[%d] = {%s};\n" % [count, ", ".join(colors)] +
		"\tfloat offsets[%d] = {%s};\n" % [count, ", ".join(offsets)] +
		"\tfor (int i = 0; i < %d - 1; i++) {\n" % count +
		"\t\tif (t <= offsets[i + 1]) {\n" +
		"\t\t\tfloat f = (t - offsets[i]) / (offsets[i + 1] - offsets[i]);\n" +
		"\t\t\treturn mix(colors[i], colors[i + 1], f);\n" +
		"\t\t}\n" +
		"\t}\n" +
		"\treturn colors[%d];\n" % (count - 1) +
        "}"
	)

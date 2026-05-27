extends Node

# Each entry contains:
#   name        – display name
#   code        – full shader function(s), including helpers
#   params      – array of { name, type, default, ui_hint... } for uniforms
#   call        – string used to call the function, with placeholders for params

enum FuncId {SOLIDCOLOR, CHECKER} 
var functions = {}

func _ready():
	add_function(FuncId.SOLIDCOLOR, "Solid Color",
		"""vec3 func_solid_color(vec2 uv, vec3 color) {
			return color;
		}""",
		[{"name": "color", "type": "vec3", "default": "vec3(1.0, 0.0, 0.0)"}],
		"func_solid_color(UV, {color})")

	add_function(FuncId.CHECKER, "Checker",
		"""vec3 func_checker(vec2 uv, float scale, vec3 col1, vec3 col2) {
			vec2 sc = uv * scale;
			vec2 ip = floor(sc);
			float v = mod(ip.x + ip.y, 2.0);
			return mix(col1, col2, step(0.5, v));
		}""",
		[
			{"name": "scale", "type": "float", "default": "4.0"},
			{"name": "col1", "type": "vec3", "default": "vec3(1.0)"},
			{"name": "col2", "type": "vec3", "default": "vec3(0.0)"}
		],
		"func_checker(UV, {scale}, {col1}, {col2})")
	# … add noise, voronoi, etc.

func add_function(id: int, name: String, code: String, params: Array, call_template: String):
	functions[id] = {
		"name": name,
		"code": code,
		"params": params,
		"call": call_template
	}

func get_function_name(id: int) -> String:
	return functions[id]["name"]

func get_ids() -> Array:
	return functions.keys()

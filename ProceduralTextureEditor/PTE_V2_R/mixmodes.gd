extends Node

enum MixId { NORMAL, MULTIPLY, SCREEN, OVERLAY } 
var mix_modes = {}

func _ready():
	add_mix_mode(MixId.NORMAL, "Normal",
		"""vec3 mix_normal(vec3 base, vec3 blend, float opacity) {
			return mix(base, blend, opacity);
		}""")
	add_mix_mode(MixId.MULTIPLY, "Multiply",
		"""vec3 mix_multiply(vec3 base, vec3 blend, float opacity) {
			vec3 multiplied = base * blend;
			return mix(base, multiplied, opacity);
		}""")
	# … add screen, overlay, etc.

func add_mix_mode(id: int, name: String, code: String):
	mix_modes[id] = {"name": name, "code": code}

func get_mix_mode_name(id: int) -> String:
	return mix_modes[id]["name"]

func get_code(id: int) -> String:
	return mix_modes[id]["code"]

func get_ids() -> Array:
	return mix_modes.keys()

# layer_data.gd
class_name LayerData extends Resource


@export var layer_name: String = "Layer"
@export var active: bool = true
@export var mix_mode: int = MixDB.MixId.NORMAL
@export var func_id: int = FuncDB.FuncId.SOLIDCOLOR
@export var opacity: float = 1.0
@export var func_params: Dictionary = {}   # e.g. {"color": Color.RED, "scale": 4.0}

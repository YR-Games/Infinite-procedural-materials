# signal_bus.gd
extends Node

# Emitted whenever any material value changes.
signal material_value_changed(path: Array[StringName], value: Variant)

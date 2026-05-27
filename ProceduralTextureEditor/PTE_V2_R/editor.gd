extends Control

@onready var layer_list: VBoxContainer = $HSplit/Left/VBox/LayerList/ScrollContainer/LayerContainer
@onready var final_preview: ColorRect = $HSplit/Right/Panel/PreviewRect
@onready var add_button = $HSplit/Left/VBox/AddButton
@onready var show_code_button = $HSplit/Left/VBox/ShowCodeButton
@onready var code_popup = $CodePopup
@onready var code_popup_text = $CodePopup/Panel/CodeText
@onready var save_button = $HSplit/Left/VBox/HBoxContainer/SaveButton
@onready var load_button = $HSplit/Left/VBox/HBoxContainer/LoadButton
@onready var load_dialog = $LoadDialog
@onready var save_dialog = $SaveFileDialog

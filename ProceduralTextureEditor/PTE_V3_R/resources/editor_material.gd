class_name EditorMaterial extends RefCounted


static var editorMaterialData: Dictionary = { 
		"generators":{},
		"albedo": {
		"layers": []
	},
}


"""Material: Dictionary = {
 Генераторы: Словарь генераторов
 Альбедо: Композиция слоёв,
 ... (аналогично для других каналов (Enum))
}

Композиция слоёв: Array[Dictionary] = [
 {
   &"имя": "слой 1",
   &"генератор": Генератор,
   &"режим смешивания": Режим смешивания (Enum),
   &"модификаторы": Модификаторы,
   ...
 },
 ...
]

Генератор: Dictionary[StringName, Variant] = {
	&"имя генератора": генератор1,
	&"параметры": Dictionary[StringName, Variant] = {
	  &"scale" = 0.2,
   }
}

Модификаторы: Array[Dictionary] = [
 {
   &"ключ функции": remap (Enum),
   &"параметры": Dictionary[StringName, Variant] = {
	  &"old_min_max" = Vector2(0, 21),
	  &"new_min_max" = Vector2(0, 1)
   }
 }
]

Есть синглтон со словарём, описанным выше.
Скрипт элемента интерфейса:
1) получает при загрузке свои значения от словаря
2) обрабатывает элементы интерфейса и пишет новые значения в словарь
"""

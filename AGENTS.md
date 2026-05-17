Never implement fallbacks, fix the root problem instead.
Never keep old code just for compatability, unless explicitly requested.
During a big change, you can refactor the code so it stays clean code.
Always prefer named classes and instead of dynamically loading scripts or scenes by path. (i.e. dont do something like that const AI_CONTROLLER_SCENE: PackedScene = preload("res://player/controllers/ai_controller.tscn"))
Never change anything inside the addons folder.

class_name ArthurAsheMaterials
extends RefCounted
## Materials of Arthur Ashe Stadium (see ArthurAsheBuilder). Most take their color from the
## vertex colors too, which vary the surfaces' gray levels a little.

const BRICK_SHADER: Shader = preload("res://scenes/environments/us_open/arthur_ashe/brick.gdshader")


## The stadium's materials by name.
static func make() -> Dictionary[String, Material]:
	var materials: Dictionary[String, Material] = {}
	var concrete := _material(materials, "concrete", Color(0.73, 0.71, 0.67), 0.92)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.05
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.seamless = true
	texture.width = 256
	texture.height = 256
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.86, 0.86, 0.86))
	ramp.set_color(1, Color(1.0, 1.0, 1.0))
	texture.color_ramp = ramp
	concrete.albedo_texture = texture
	concrete.uv1_triplanar = true
	concrete.uv1_world_triplanar = true
	concrete.uv1_scale = Vector3.ONE * 0.25
	_material(materials, "step", Color(0.83, 0.82, 0.79), 0.9)
	_material(materials, "nosing", Color(0.93, 0.75, 0.16), 0.7)
	_material(materials, "terracotta", Color(0.6, 0.32, 0.24), 0.85)
	_material(materials, "fascia", Color(0.06, 0.14, 0.4), 0.45)
	_material(materials, "wall", Color(0.09, 0.2, 0.5), 0.55)
	_material(materials, "field", Color(0.25, 0.47, 0.36), 0.85)
	_material(materials, "seat", Color(0.1, 0.22, 0.56), 0.42)
	_material(materials, "seat_frame", Color(0.2, 0.21, 0.23), 0.5, 0.6)
	var glass := _material(materials, "glass", Color(0.05, 0.07, 0.1), 0.06, 0.85)
	glass.emission_enabled = true
	glass.emission = Color(0.3, 0.24, 0.17)
	glass.emission_energy_multiplier = 0.35
	_material(materials, "partition", Color(0.88, 0.88, 0.86), 0.7)
	_material(materials, "steel", Color(0.86, 0.87, 0.89), 0.35, 0.55)
	_material(materials, "dark_steel", Color(0.32, 0.34, 0.37), 0.4, 0.6)
	var membrane := _material(materials, "membrane", Color(0.93, 0.93, 0.92), 0.75)
	membrane.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material(materials, "black", Color(0.025, 0.025, 0.03), 0.6)
	var lamp := _material(materials, "lamp", Color(0.9, 0.9, 0.88), 0.3)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.97, 0.9)
	lamp.emission_energy_multiplier = 3.0
	_material(materials, "plaza", Color(0.62, 0.61, 0.58), 0.95)
	_material(materials, "white", Color(0.92, 0.92, 0.9), 0.5)
	_material(materials, "pit", Color(0.2, 0.22, 0.26), 0.9)
	_material(materials, "display", Color(1.0, 1.0, 1.0), 0.3)
	_material(materials, "towel", Color(0.12, 0.13, 0.2), 0.95)
	var ribbon := _material(materials, "ribbon", Color(0.05, 0.12, 0.45), 0.4)
	ribbon.emission_enabled = true
	ribbon.emission = Color(0.12, 0.35, 1.0)
	ribbon.emission_energy_multiplier = 1.4
	var brick := ShaderMaterial.new()
	brick.resource_name = "brick"
	brick.shader = BRICK_SHADER
	materials["brick"] = brick
	materials["logos"] = UsOpenLogos.make_material()
	return materials


static func _material(
	materials: Dictionary[String, Material],
	material_name: String,
	color: Color,
	roughness: float,
	metallic: float = 0.0
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.vertex_color_use_as_albedo = true
	materials[material_name] = material
	return material

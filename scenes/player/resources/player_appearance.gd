class_name PlayerAppearance
extends Resource

@export var body_mesh: Mesh
@export var shirt_mesh: Mesh
@export var shorts_mesh: Mesh
@export var shoes_mesh: Mesh
@export var hair_mesh: Mesh

@export var body_texture: Texture2D
@export var shirt_texture: Texture2D
@export var shorts_texture: Texture2D
@export var shoes_texture: Texture2D
@export var hair_texture: Texture2D

@export var skin_texture: Texture2D
@export var face_texture: Texture2D
@export var racket_texture: Texture2D
@export var racket_strings_texture: Texture2D

## Schema-only in phase one. Application is handled by Model hooks.
@export var body_proportions: Dictionary = {}


func has_any_mesh() -> bool:
	return (
		body_mesh != null
		or shirt_mesh != null
		or shorts_mesh != null
		or shoes_mesh != null
		or hair_mesh != null
	)

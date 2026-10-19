# Generates the player bodies: for every MPFB human preset in pelota-files/player/presets/, the
# human with the game's rig, dressed in the tennis kit (see make_player_kit.py), exported as
# assets/models/players/<name>/<name>.glb for the player body importer
# (scenes/player/rig/player_body_import.gd).
#
# A preset is MPFB's own human format: shape it in MPFB (New human, Model, Apply assets: eyebrows,
# eyelashes, hair) and save it with Presets > Save human preset, then copy the .json here. Only
# the shape and the hair, eyebrows and eyelashes are used: the rig, the clothes and all materials
# are the game's (skin, eye and hair colors are set in the player's appearance in Godot).
#
# Usage (from anywhere):
#   blender -b --python tools/blender/generate_players.py [-- [--preview DIR] name ...]
#
#   name           generates only the listed presets (default: all)
#   --preview DIR  also renders a front and a face view of each player into DIR

import json
import os
import sys

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, os.path.dirname(__file__))
import mpfb_setup  # noqa: E402

RIG = "default_no_toes"
## Kit garments every body wears, by mesh slot (see make_player_kit.py)
KIT = {
    "Shirt": "shirt",
    "Shorts": "shorts",
    "Socks": "socks",
    "Shoes": "shoes",
    "WristbandLeft": "wristband_left",
    "WristbandRight": "wristband_right",
    "Headband": "headband",
}
## Body parts of the preset that are exported, by mesh slot (their MPFB object type)
BODY_PARTS = {"Eyes": "Eyes", "Eyebrows": "Eyebrows", "Eyelashes": "Eyelashes", "Hair": "Hair"}
## Slots exported with their MakeHuman texture (strands as alpha), which the game's hair material
## takes; the other slots get their materials in the game.
TEXTURED_SLOTS = ("Eyebrows", "Eyelashes", "Hair")
## The racket grip bone: a child of the right palm (metacarpal2.R), placed in the frame the hand spans (x from
## the wrist to the middle knuckle, z the back of the hand, y toward the thumb side; offsets in
## hand lengths) as the racket in scenes/player/model.tscn expects it.
GRIP_BONE = "racket_grip.R"
GRIP_PARENT = "metacarpal2.R"
GRIP_OFFSET = Vector((0.1367, -0.4096, -0.5144))
GRIP_ROTATION = Matrix(((-0.4269, 0.7694, 0.4751), (0.5028, 0.6387, -0.5825), (-0.7516, -0.0098, -0.6595)))
OUTPUT = os.path.join(mpfb_setup.PROJECT_ROOT, "assets", "models", "players")


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    preview_dir = None
    if "--preview" in args:
        index = args.index("--preview")
        preview_dir = args[index + 1]
        del args[index : index + 2]
    presets = sorted(f[:-5] for f in os.listdir(mpfb_setup.PRESETS_DIR) if f.endswith(".json"))
    for name in args or presets:
        assert name in presets, "No preset %s in %s" % (name, mpfb_setup.PRESETS_DIR)
        mpfb_setup.empty_scene()
        mpfb_setup.enable_mpfb()
        rig, meshes = build(name)
        export(name, rig, meshes)
        if preview_dir:
            render_preview(os.path.join(preview_dir, name))


def build(name):
    """The human of preset `name` with the rig and the kit: its armature and meshes by slot."""
    from bl_ext.blender_org.mpfb.services.humanservice import HumanService
    from bl_ext.blender_org.mpfb.services.objectservice import ObjectService

    with open(os.path.join(mpfb_setup.PRESETS_DIR, name + ".json")) as preset_file:
        preset = json.load(preset_file)
    for part in ("teeth", "tongue", "proxy"):
        preset[part] = ""
    preset["clothes"] = []
    preset["eyes"] = preset.get("eyes") or "high-poly/high-poly.mhclo"
    settings = HumanService.get_default_deserialization_settings()
    settings["subdiv_levels"] = 0
    settings["override_rig"] = RIG
    settings["override_skin_model"] = "MAKESKIN"
    basemesh = HumanService.deserialize_from_dict(preset, settings)
    rig = basemesh.parent
    for slot, garment in KIT.items():
        path = os.path.join(mpfb_setup.KIT_DIR, garment, garment + ".mhclo")
        assert os.path.exists(path), "%s is missing: run make_player_kit.py" % path
        HumanService.add_mhclo_asset(path, basemesh, asset_type="Clothes", subdiv_levels=0)
    meshes = {"Body": basemesh}
    for child in rig.children:
        object_type = ObjectService.get_object_type(child)
        for slot, part_type in BODY_PARTS.items():
            if object_type == part_type:
                meshes[slot] = child
        source = _asset_name(child)
        for slot, garment in KIT.items():
            if source == garment:
                meshes[slot] = child
    missing = (set(KIT) | {"Eyes"}) - set(meshes)
    assert not missing, "%s: no %s" % (name, missing)
    add_grip_bone(rig)
    hang_thumbs_off_palms(rig)
    return rig, meshes


def _asset_name(obj):
    from bl_ext.blender_org.mpfb.entities.objectproperties import GeneralObjectProperties

    source = GeneralObjectProperties.get_value("asset_source", entity_reference=obj) or ""
    return os.path.splitext(os.path.basename(source))[0]


def add_grip_bone(rig):
    """Adds the racket grip bone to the right hand (see GRIP_OFFSET)."""
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    bones = rig.data.edit_bones
    wrist = bones["wrist.R"]
    knuckles = bones["finger3-1.R"].head
    index, pinky = bones["finger2-1.R"].head, bones["finger5-1.R"].head
    x = knuckles - wrist.head
    length = x.length
    x.normalize()
    z = x.cross(index - pinky).normalized()
    y = z.cross(x)
    frame = Matrix((x, y, z)).transposed()
    grip = bones.new(GRIP_BONE)
    grip.parent = bones[GRIP_PARENT]
    grip.use_deform = False
    head = wrist.head + frame @ (GRIP_OFFSET * length)
    rotation = frame @ GRIP_ROTATION
    grip.head = head
    grip.tail = head + rotation.col[1] * 0.1
    grip.align_roll(rotation.col[2])
    bpy.ops.object.mode_set(mode="OBJECT")


def hang_thumbs_off_palms(rig):
    """Parents each thumb to the index finger's metacarpal, as in the rig the animations were made
    on, where the thumb moves with it (see mpfb_bone_map.tres)."""
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    bones = rig.data.edit_bones
    for side in ("L", "R"):
        bones["finger1-1." + side].parent = bones["metacarpal1." + side]
    bpy.ops.object.mode_set(mode="OBJECT")


def export(name, rig, meshes):
    """Exports the rig and the meshes, named by slot, in the rest pose."""
    exported = []
    for slot, obj in meshes.items():
        texture = _texture(obj) if slot in TEXTURED_SLOTS else None
        baked = _baked(obj, slot, rig)
        if texture:
            baked.data.materials.append(_textured_material(slot, texture))
        exported.append(baked)
    rig.name = "Rig"
    rig.data.pose_position = "REST"
    directory = os.path.join(OUTPUT, name)
    os.makedirs(directory, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [rig] + exported:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(directory, name + ".glb"),
        use_selection=True,
        export_format="GLB",
        export_yup=True,
        export_apply=True,
        export_animations=False,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_morph=False,
        export_skins=True,
        export_all_influences=False,
        export_def_bones=False,
        export_extras=False,
    )
    print("EXPORTED", name, {o.name: len(o.data.polygons) for o in exported})


def _texture(obj):
    """The image the MakeHuman material of `obj` takes its color (and alpha) from."""
    for slot in obj.material_slots:
        trees = [slot.material.node_tree]
        while trees:
            tree = trees.pop()
            for node in tree.nodes:
                if node.type == "TEX_IMAGE" and node.image and "normal" not in node.image.name.lower():
                    return node.image
                if node.type == "GROUP":
                    trees.append(node.node_tree)
    raise AssertionError("%s has no texture" % obj.name)


def _textured_material(name, image):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    material.node_tree.links.new(texture.outputs["Alpha"], shader.inputs["Alpha"])
    material.blend_method = "HASHED"
    return material


def _baked(obj, slot, rig):
    """`obj` as a plain mesh named `slot`: its shape (shape keys) and the parts hidden under the
    clothes (mask modifiers) applied, skinned to `rig`."""
    for modifier in obj.modifiers:
        modifier.show_viewport = modifier.type != "ARMATURE"
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph), preserve_all_data_layers=True, depsgraph=depsgraph)
    mesh.materials.clear()
    baked = bpy.data.objects.new(slot, mesh)
    bpy.context.scene.collection.objects.link(baked)
    for group in obj.vertex_groups:
        baked.vertex_groups.new(name=group.name)
    baked.parent = rig
    baked.modifiers.new("Armature", "ARMATURE").object = rig
    obj.hide_set(True)
    obj.hide_render = True
    return baked


def render_preview(path):
    """Renders the player from the front and the face, in plain materials."""
    scene = bpy.context.scene
    skin = _preview_material("Skin", (0.75, 0.55, 0.45, 1.0), 0.5)
    hair = _preview_material("Hair", (0.08, 0.05, 0.03, 1.0), 0.6)
    shorts = _preview_material("Shorts", (0.1, 0.12, 0.3, 1.0), 0.9)
    cloth = _preview_material("Cloth", (0.85, 0.85, 0.88, 1.0), 0.9)
    materials = {"Body": skin, "Eyes": skin, "Hair": hair, "Eyebrows": hair, "Eyelashes": hair, "Shorts": shorts}
    for obj in scene.objects:
        if obj.type == "MESH" and not obj.hide_render:
            obj.data.materials.clear()
            obj.data.materials.append(materials.get(obj.name, cloth))
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = 700, 1000
    camera = bpy.data.objects.new("Camera", bpy.data.cameras.new("Camera"))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.lens = 70
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (0.7, 0.3, 0.4)
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.7
    head = bpy.data.objects["Rig"].data.bones["head"].head_local
    for view, location, target in (
        ("front", Vector((0.8, -4.6, 1.1)), Vector((0.0, 0.0, 1.0))),
        ("face", head + Vector((0.25, -0.8, 0.1)), head + Vector((0.0, 0.0, 0.08))),
    ):
        camera.location = location
        camera.rotation_euler = (target - location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = "%s_%s.png" % (path, view)
        bpy.ops.render.render(write_still=True)


def _preview_material(name, color, roughness):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    shader = material.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Roughness"].default_value = roughness
    return material


if __name__ == "__main__":
    main()

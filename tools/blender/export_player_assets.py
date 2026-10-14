# Exports the player bodies and animation sets listed in player_assets.json from their Blender
# files into the Godot project as glTF binaries, ready for the importers to pick up (see
# scenes/player/rig/). The .blend files are only read, never saved.
#
# Usage (from anywhere; paths in player_assets.json are relative to the project root):
#   blender -b --python tools/blender/export_player_assets.py [-- name ...]
#
#   name    exports only the listed bodies / animation sets (default: all)
#
# A body is the rig with its meshes, in the rest pose, without animations. Its armature is
# exported as "Rig" and its meshes under their slot names (Body, Shirt, Shorts, Shoes, Hair, ...),
# which the player model looks up.
# An animation set is the rig with one glTF animation per NLA track whose name starts with the
# set's prefix (the prefix is dropped from the animation name). The tracks hold baked actions: the
# rig's bone constraints (e.g. copying a control rig) are muted for the export. A one-triangle mesh skinned to the
# rig ("SkinProxy") is exported along, so that Godot imports the bones as a skeleton; the
# importer removes it again.

import json
import os
import sys

import bpy

PROJECT_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
CONFIG = os.path.join(os.path.dirname(__file__), "player_assets.json")
RIG_NAME = "Rig"
SKIN_PROXY_NAME = "SkinProxy"


def main():
    names = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    with open(CONFIG) as config_file:
        config = json.load(config_file)
    for name, body in config["bodies"].items():
        if not names or name in names:
            _open(body["blend"])
            export_body(body)
    for name, animation_set in config["animation_sets"].items():
        if not names or name in names:
            _open(animation_set["blend"])
            export_animation_set(animation_set)


def export_body(body):
    rig = _rig(body["rig"])
    _mute_animation(rig)
    meshes = []
    for slot, object_name in body["meshes"].items():
        mesh = bpy.data.objects[object_name]
        assert mesh.parent == rig, "%s is not parented to the rig %s" % (object_name, rig.name)
        mesh.name = slot
        meshes.append(mesh)
    rig.name = RIG_NAME
    _select([rig] + meshes)
    _export(body["output"], animations=False)


def export_animation_set(animation_set):
    rig = _rig(animation_set["rig"])
    prefix = animation_set["prefix"]
    for track in rig.animation_data.nla_tracks:
        track.mute = not track.name.startswith(prefix)
        if not track.mute:
            track.name = track.name[len(prefix) :]
    rig.animation_data.action = None
    for pose_bone in rig.pose.bones:
        for constraint in pose_bone.constraints:
            constraint.mute = True
    rig.name = RIG_NAME
    _select([rig, _skin_proxy(rig)])
    _export(animation_set["output"], animations=True)


def _open(blend):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(PROJECT_ROOT, blend), load_ui=False)


def _rig(name):
    rig = bpy.data.objects[name]
    assert rig.type == "ARMATURE", "%s is not an armature" % name
    return rig


def _mute_animation(rig):
    if not rig.animation_data:
        return
    rig.animation_data.action = None
    for track in rig.animation_data.nla_tracks:
        track.mute = True


# A single triangle skinned to the rig, so the bones are exported as a glTF skin.
def _skin_proxy(rig):
    mesh = bpy.data.meshes.new(SKIN_PROXY_NAME)
    mesh.from_pydata([(0, 0, 0), (0.01, 0, 0), (0, 0.01, 0)], [], [(0, 1, 2)])
    proxy = bpy.data.objects.new(SKIN_PROXY_NAME, mesh)
    bpy.context.scene.collection.objects.link(proxy)
    proxy.parent = rig
    root = next(bone for bone in rig.data.bones if bone.parent is None and bone.use_deform)
    group = proxy.vertex_groups.new(name=root.name)
    group.add([0, 1, 2], 1.0, "REPLACE")
    proxy.modifiers.new("Armature", "ARMATURE").object = rig
    return proxy


def _select(objects):
    for obj in bpy.context.view_layer.objects:
        obj.select_set(False)
    for obj in objects:
        obj.hide_viewport = False
        obj.hide_set(False)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def _export(output, animations):
    path = os.path.join(PROJECT_ROOT, output)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_skins=True,
        export_def_bones=False,
        export_rest_position_armature=True,
        export_animations=animations,
        export_animation_mode="NLA_TRACKS",
        export_force_sampling=True,
        export_frame_step=1,
        export_anim_single_armature=True,
        export_reset_pose_bones=True,
        export_optimize_animation_size=False,
        export_morph=False,
        export_extras=False,
    )
    print("Exported %s" % path)


main()

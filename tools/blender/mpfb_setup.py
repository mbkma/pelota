# Shared setup of the player scripts in this folder: enables MPFB (the MakeHuman add-on for
# Blender, see https://static.makehumancommunity.org/mpfb.html) and finds the folders the scripts
# read and write.

import os

import addon_utils
import bpy

MPFB_MODULE = "bl_ext.blender_org.mpfb"
PROJECT_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
## Source files of the players (presets, kit garments), in the pelota-files repository next to
## the project
PLAYER_FILES = os.path.normpath(os.path.join(PROJECT_ROOT, "..", "pelota-files", "player"))
PRESETS_DIR = os.path.join(PLAYER_FILES, "presets")
KIT_DIR = os.path.join(PLAYER_FILES, "kit")


def enable_mpfb():
    """Enables MPFB; fails if it is not installed or its system assets are missing."""
    addon_utils.enable(MPFB_MODULE, default_set=True)
    assert MPFB_MODULE in bpy.context.preferences.addons, (
        "MPFB is not installed: install it in Blender (Edit > Preferences > Get Extensions)"
    )
    from bl_ext.blender_org.mpfb.services.assetservice import AssetService

    assert AssetService.system_assets_pack_is_installed(), (
        "The MakeHuman system assets are not installed: in the MPFB panel, Settings > Assets, "
        "install makehuman_system_assets_cc0.zip"
    )


def empty_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)

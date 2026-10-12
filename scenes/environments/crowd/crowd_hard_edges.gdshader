// A spectator of the crowd (see crowd.gdshaderinc) without alpha to coverage: the hair and lashes
// have hard edges, and the crowd is drawn in one pass less (for the lower crowd details).
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

#define HARD_EDGES
#include "res://scenes/environments/crowd/crowd.gdshaderinc"

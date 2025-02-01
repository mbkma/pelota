class_name Drawing
extends ImmediateMesh


#func drawline(a: Vector3, b: Vector3):
	#begin(Mesh.PRIMITIVE_LINES)
	#set_color(Color(1, 0.54902, 0, 1))
	#add_vertex(a)
	#add_vertex(b)
	#end()

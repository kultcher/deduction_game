## One-off: builds ui/paper_puppet/edda_hair_test.tscn from the Krita layers (mock branch only).
##   godot --headless --path . --script res://tools/paper_puppet_hair_test_scene.gd
extends SceneTree
const DIR = "res://assets/art/paper_puppet_poc/edda_hair_test/"
# name, pivot (canvas px: what it swings from), depth, sway degrees, phase
const PIECES = [
	["body", null, 0, 0.0, 0.0],
	["eyes", null, 0, 0.0, 0.0],
	["hair_under", null, 0, 0.0, 0.0],
	["hair_mass", [560, 230], 3, 1.2, 0.0],
	["ear", null, 1, 0.0, 0.0],
	["hair_waves", [400, 165], 2, 2.0, 1.4],
	["hair_swoop", [395, 120], 3, 2.5, 2.6],
]
func _initialize() -> void:
	var root = Node2D.new()
	root.name = "EddaHairTest"
	root.set_script(load("res://ui/paper_puppet.gd"))
	var body = Node2D.new()
	body.name = "Body"
	body.position = Vector2(512, 1536)
	root.add_child(body)
	var nodes = [body]
	var z = 0
	for p in PIECES:
		z += 2
		var s = Sprite2D.new()
		s.name = String(p[0]).to_pascal_case()
		s.texture = load(DIR + p[0] + ".png")
		s.centered = false
		var pivot = Vector2(p[1][0], p[1][1]) if p[1] != null else Vector2.ZERO
		s.position = pivot - body.position
		s.offset = -pivot
		s.z_index = z
		s.set_meta("depth", p[2])
		if p[3] > 0.0:
			s.set_meta("sway", p[3])
			s.set_meta("phase", p[4])
		body.add_child(s)
		nodes.append(s)
	for n in nodes:
		n.owner = root
	var packed = PackedScene.new()
	print("pack ", packed.pack(root), " save ", ResourceSaver.save(packed, "res://ui/paper_puppet/edda_hair_test.tscn"))
	quit()

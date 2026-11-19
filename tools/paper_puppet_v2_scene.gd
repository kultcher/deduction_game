## One-off (mock branch): builds ui/paper_puppet/edda_v2.tscn from the full-canvas pieces in
## assets/art/paper_puppet_poc/edda_v2/ (Michael's Krita layers plus Limner's fills).
##   godot --headless --path . --script res://tools/paper_puppet_v2_scene.gd
extends SceneTree

const DIR = "res://assets/art/paper_puppet_poc/edda_v2/"
# Back to front: name, pivot (canvas px it swings from, or null), shadow depth, sway degrees, phase.
const PIECES = [
	["hair_under", null, 0, 0.0, 0.0],
	["hair_left", [370, 110], 3, 1.5, 0.9],   # the far side: behind her head
	["hair_neck", [700, 420], 2, 2.0, 3.1],   # behind the neck, which hides its cut edge
	["body", null, 0, 0.0, 0.0],
	["nose", null, 1, 0.0, 0.0],
	["eyes", null, 0, 0.0, 0.0],
	["mouth_0", null, 0, 0.0, 0.0],
	["brow_far", null, 1, 0.0, 0.0],
	["brow_near", null, 1, 0.0, 0.0],
	["hair_mass", [560, 230], 3, 1.2, 0.0],
	["ear", null, 1, 0.0, 0.0],
	["hair_waves", [400, 165], 2, 2.0, 1.4],
	["hair_swoop", [395, 120], 3, 2.5, 2.6],
]

func _initialize() -> void:
	var root = Node2D.new()
	root.name = "EddaV2"
	root.set_script(load("res://ui/paper_puppet.gd"))
	var ref = Sprite2D.new()
	ref.name = "Reference"
	ref.texture = load("res://assets/art/paper_puppet_poc/edda/reference.png")
	ref.centered = false
	ref.modulate = Color(1, 1, 1, 0.45)
	ref.z_index = 100
	ref.visible = false
	root.add_child(ref)
	var body = Node2D.new()
	body.name = "Body"
	body.position = Vector2(512, 1536)
	root.add_child(body)
	var nodes = [ref, body]
	var z = 0
	for p in PIECES:
		z += 2
		var s = Sprite2D.new()
		s.name = "Mouth" if p[0] == "mouth_0" else String(p[0]).to_pascal_case()
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
		if p[0] == "eyes":
			s.set_meta("shut", load(DIR + "eyes_shut.png"))
		if p[0] == "mouth_0":
			var frames: Array[Texture2D] = []
			for i in range(3):
				frames.append(load(DIR + "mouth_%d.png" % i))
			s.set_meta("frames", frames)
		body.add_child(s)
		nodes.append(s)
	for n in nodes:
		n.owner = root
	var packed = PackedScene.new()
	print("pack ", packed.pack(root), " save ", ResourceSaver.save(packed, "res://ui/paper_puppet/edda_v2.tscn"))
	quit()

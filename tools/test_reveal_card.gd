## The end-of-game card reveal (ui/reveal/reveal_card.gd, Limner Nov 21):
##   - a person's whole reveal takes about 3 s, about 3.8 s with a fakeout;
##   - `landed` comes once, when the true card has settled, then `finished` once, after the
##     seal and any burden tag; skip_to_end() emits both from anywhere, and only once;
##   - the deal never shows the true or false role before the end, and a fakeout shows the
##     false role's card, then tears it;
##   - reduced motion deals nothing, is quicker, and still shows a fakeout (struck through);
##   - at the end only the true card, the seal and (with a burden) the tag are showing.
## Headless: checks the timeline and the nodes, not pixels (tools/reveal_card_capture.gd
## records the look).
##   godot --headless --path . --script res://tools/test_reveal_card.gd
extends SceneTree

const RevealCard = preload("res://ui/reveal/reveal_card.gd")

const SCRIPT = ["seer", "dowser", "clerk", "gravedigger", "medium", "nightwatch", "magistrate", "poisoner", "demon"]

var _checks: int = 0
var _fails: int = 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		_fails += 1
		push_error("FAIL: " + label)


func _initialize() -> void:
	call_deferred("_run")


func _step(extra: Dictionary = {}) -> Dictionary:
	var s = {"name": "Odette", "roles": SCRIPT, "role": "poisoner", "evil": true, "guess": "You guessed: Minion"}
	s.merge(extra, true)
	return s


## Plays a step to the end in 1/30 s ticks; returns the times each signal fired and the
## roles any card showed face up while it played.
func _run_step(card, step: Dictionary) -> Dictionary:
	var got = {"landed": [], "finished": [], "faces": {}}
	var on_landed = func(): got.landed.append(card.t)
	var on_finished = func(): got.finished.append(card.t)
	card.landed.connect(on_landed)
	card.finished.connect(on_finished)
	card.play(step)
	var guard = 0
	while card.playing and guard < 600:
		card.advance(1.0 / 30.0)
		guard += 1
		for c in card.dealt + [card.fake_card, card.final_card]:
			if c.visible and c.face.visible:
				got.faces[c.name_label.text] = got.faces.get(c.name_label.text, 0.0) if got.faces.has(c.name_label.text) else card.t
	card.landed.disconnect(on_landed)
	card.finished.disconnect(on_finished)
	return got


func _run() -> void:
	var card = RevealCard.new()
	card.size = Vector2(1730, 800)
	root.add_child(card)
	await process_frame
	card.set_process(false)

	# A straight reveal.
	var dealt_count = [0]
	var on_dealt = func(): dealt_count[0] += 1
	card.card_dealt.connect(on_dealt)
	var got = _run_step(card, _step())
	card.card_dealt.disconnect(on_dealt)
	_check(dealt_count[0] == RevealCard.DEAL, "card_dealt fires once a dealt card (%d)" % dealt_count[0])
	_check(got.landed.size() == 1 and got.finished.size() == 1, "landed and finished each fire once")
	_check(got.landed[0] <= got.finished[0], "landed comes before finished")
	_check(card.ends_at() >= 2.6 and card.ends_at() <= 3.4, "a straight reveal takes about 3 s (%.2f s)" % card.ends_at())
	_check(card.landed_at() >= 1.6, "the deal comes first: the card lands at %.2f s" % card.landed_at())
	_check(got.faces.has("Poisoner"), "the true card was shown face up")
	var first_true = got.faces.get("Poisoner", 99.0)
	_check(first_true >= card._plan.final_at - 0.01, "the true role isn't dealt before its own turn")
	var dealt_roles = card._deal_roles
	_check(dealt_roles.size() == RevealCard.DEAL and not dealt_roles.has("poisoner"), "the deal is %d of the script's other roles" % RevealCard.DEAL)
	_check(dealt_roles.all(func(r): return r in SCRIPT), "the deal draws only on this script's roles")
	_check(card.final_card.visible and card.final_card.face.visible, "at the end the true card is face up")
	_check(card.seal.visible and card.seal.evil, "the evil seal is down")
	_check(not card.tag.visible, "no burden, no tag")
	_check(card.role_label.visible and card.role_label.text == "Poisoner", "the role is named under the card")
	_check(card.dealt.all(func(c): return not c.visible) and card.stack.all(func(c): return not c.visible), "the deal and the deck have cleared")

	# A fakeout.
	got = _run_step(card, _step({"fakeout_role": "seer", "guess_correct": true}))
	_check(card.ends_at() >= 3.3 and card.ends_at() <= 4.3, "a fakeout takes about 3.8 s (%.2f s)" % card.ends_at())
	_check(got.faces.has("Seer") and got.faces.has("Poisoner"), "the false card, then the true one, were shown")
	_check(got.faces.get("Seer", 99.0) < got.faces.get("Poisoner", -1.0), "the false card shows first")
	_check(not card._deal_roles.has("seer"), "the deal doesn't give the fakeout role away")
	_check(not card.fake_card.visible and card.halves.all(func(h): return not h.clip.visible), "the torn card has gone")
	_check(card.mark.visible and card.mark.correct, "the guess is ticked")

	# Mid-tear, the halves are out and the false name is struck through.
	card.play(_step({"fakeout_role": "seer"}))
	while card.t < card._plan.tear + 0.1:
		card.advance(1.0 / 30.0)
	_check(card.halves.all(func(h): return h.clip.visible), "mid-tear, both halves are showing")
	_check(card.strike.visible and card.role_label.text == "Seer", "mid-tear, the false name is struck through")

	# Skipping.
	var counts = {"landed": 0, "finished": 0}
	var on_l = func(): counts.landed += 1
	var on_f = func(): counts.finished += 1
	card.landed.connect(on_l)
	card.finished.connect(on_f)
	card.play(_step({"burden": "…and Delusional", "role": "gravedigger", "evil": false}))
	card.advance(0.5)
	card.skip_to_end()
	card.skip_to_end()
	card.advance(1.0)
	_check(counts.landed == 1 and counts.finished == 1, "skip_to_end emits landed and finished once each")
	_check(not card.playing, "after a skip it has stopped")
	_check(card.tag.visible and card.tag_label.text == "…and Delusional", "the burden tag is up after a skip")
	_check(card.seal.visible and not card.seal.evil, "the good seal is down")
	card.landed.disconnect(on_l)
	card.finished.disconnect(on_f)

	# Reduced motion.
	card.reduced_motion = true
	got = _run_step(card, _step({"fakeout_role": "seer"}))
	_check(got.landed.size() == 1 and got.finished.size() == 1, "reduced motion: landed and finished each fire once")
	_check(card.ends_at() < 2.5, "reduced motion is quicker (%.2f s)" % card.ends_at())
	_check(not got.faces.keys().any(func(n): return n not in ["Seer", "Poisoner"]), "reduced motion deals nothing")
	_check(got.faces.has("Seer"), "reduced motion still shows the false role first")
	card.play(_step({"fakeout_role": "seer"}))
	while card.t < card._plan.strike + 0.05:
		card.advance(1.0 / 30.0)
	_check(card.strike.visible, "reduced motion strikes the false role through")
	card.reduced_motion = false

	# Resizing re-lays it out without losing the state.
	card.play(_step())
	card.skip_to_end()
	card.size = Vector2(1200, 555)
	await process_frame
	_check(card.final_card.visible and card.final_card.size.x < RevealCard.CARD.x, "it scales with its rect")

	card.queue_free()
	await process_frame
	print("%d checks, %d failed" % [_checks, _fails])
	quit(1 if _fails > 0 else 0)

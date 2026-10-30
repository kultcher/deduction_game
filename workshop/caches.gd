## One place to drop every memoised result the shared model keeps in static variables.
##
## The solver and evaluator memoise by their inputs, but tuning values (and probe overrides
## such as CaseEval.prior_k) are not part of those keys. Clearing at each new case keeps one
## case's results from leaking into the next and makes a tuning change take effect at once.
## Settings (reuse switches, engine choice) and id counters are left alone: counters only
## need to stay unique, and resetting them could collide with ids still held by a game.
extends RefCounted

const CaseEval = preload("res://workshop/case_eval.gd")
const ChannelLikelihood = preload("res://workshop/channel_likelihood.gd")
const Chronology = preload("res://workshop/chronology.gd")
const FactoredChannels = preload("res://workshop/factored_channels.gd")
const Jury = preload("res://workshop/jury.gd")
const LiveActivity = preload("res://workshop/live_activity.gd")
const MovementModel = preload("res://workshop/movement_model.gd")
const ReadingChallenges = preload("res://workshop/reading_challenges.gd")
const Reasoner = preload("res://workshop/reasoner.gd")
const RoleConstraints = preload("res://workshop/role_constraints.gd")
const Solver = preload("res://workshop/solver.gd")
const SupportModel = preload("res://workshop/support_model.gd")
const WorldDomain = preload("res://workshop/world_domain.gd")

static func clear_all() -> void:
	CaseEval._valid_cache.clear()
	CaseEval._index_cache.clear()
	CaseEval._premise_cache.clear()
	CaseEval._compiled.clear()
	CaseEval._coarse_cache.clear()
	CaseEval._own_cache.clear()
	CaseEval._fits_cache.clear()
	ChannelLikelihood.cache.clear()
	Chronology._cached_people = null
	Chronology._cached_idx = {}
	FactoredChannels.cache.clear()
	Jury._eval_memo.clear()
	LiveActivity.cache.clear()
	LiveActivity.route_cache.clear()
	LiveActivity.demon_route_cache.clear()
	MovementModel.cache.clear()
	ReadingChallenges.cache.clear()
	ReadingChallenges.fraction_cache.clear()
	Reasoner.matches.clear()
	Reasoner.preparations.clear()
	RoleConstraints.cache.clear()
	Solver.universes.clear()
	Solver.report_matches.clear()
	Solver.movement_cache.clear()
	Solver.solve_cache.clear()
	Solver.conflict_cache.clear()
	Solver._cached_people = null
	Solver._cached_ids = []
	Solver._cached_idx = {}
	Solver._cached_block_masks = {}
	Solver._bits.clear()
	Solver._sig_groups.clear()
	Solver.question_cache.clear()
	SupportModel.cache.clear()
	SupportModel.comparisons.clear()
	SupportModel.priors.clear()
	SupportModel.explanations.clear()
	WorldDomain.cache.clear()
	WorldDomain._cached_people = null
	WorldDomain._cached_idx = {}

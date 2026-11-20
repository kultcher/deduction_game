## Shared by the CaseEval chain (`case_eval_content` <- `case_eval_classes` <- `case_eval`):
## the preloads and the error and likelihood-ratio constants. Split from `workshop/case_eval.gd`.
extends RefCounted

const Tuning = preload("res://sim/tuning.gd")
const Solver = preload("res://workshop/solver.gd")
const Domain = preload("res://workshop/world_domain.gd")
const Graph = preload("res://workshop/case_graph.gd")
const TimeModel = preload("res://workshop/chronology.gd")
const Movement = preload("res://workshop/movement_model.gd")
const PublicEvidence = preload("res://workshop/public_evidence.gd")
const SpeechEvidence = preload("res://workshop/speech_evidence.gd")
const DayPresence = preload("res://workshop/day_presence.gd")

## Chance a healthy reading from a good source is wrong anyway (unmodelled impairment).
## Kept small: the rules make a good, healthy reading accurate, and the failures the
## rules allow (evil, Delusional, Marked registering) are in the worlds themselves. A
## larger value lets "it was just wrong" explain away any surprising reading.
const DEFAULT_ERR = Tuning.Workshop.DEFAULT_ERR
## The same for the listener's own reading: they know what they saw.
const OWN_ERR = Tuning.Workshop.OWN_ERR
## Likelihood-ratio thresholds for the case-strength categories (neutral listener).
const LR_WEAK = Tuning.Workshop.LR_WEAK
const LR_MODERATE = Tuning.Workshop.LR_MODERATE
const LR_STRONG = Tuning.Workshop.LR_STRONG
const LR_DAMNING_CHANCE = Tuning.Workshop.LR_DAMNING_CHANCE

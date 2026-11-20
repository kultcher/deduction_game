## Shared by the LiveActivity chain (`live_activity_profiles` <- `live_activity_pack` <-
## `live_activity_factors` <- `live_activity`): the preloads and the movement constants.
## Split from `workshop/live_activity.gd`.
extends RefCounted
const Tuning = preload("res://sim/tuning.gd")
const C = preload("res://sim/content.gd")
const History = preload("res://workshop/live_history.gd")
const DayPresence = preload("res://workshop/day_presence.gd")
const Chronology = preload("res://workshop/chronology.gd")
const VIGIL_MISS = Tuning.Workshop.VIGIL_MISS
const GOOD_OWN_ALIBI_OUT = Tuning.Workshop.GOOD_OWN_ALIBI_OUT
const WALKER_CLAIM_GIFT = Tuning.Workshop.WALKER_CLAIM_GIFT
const WALKER_CLAIM_HOME = Tuning.Workshop.WALKER_CLAIM_HOME
const WALKER_CLAIM_SECRET = Tuning.Workshop.WALKER_CLAIM_SECRET

# Demonologist Balancing & Tuning Catalogue

This document catalogues balancing and tuning parameters across the codebase (`sim/`, `sim/roles/`, `workshop/`, and `game/`), covering both existing named constants and inline magic numbers that are likely to shift during balancing.

## 1. Global Rules, Setup & World Generation (`sim/content.gd`, `sim/world.gd`)

### 1.1 Game Setup & Feature Toggles (`sim/content.gd`)
| Constant / Location | Current Value | Description |
| :--- | :--- | :--- |
| `SETUPS[7]` (`sim/content.gd:259`) | `{town: 5, minions: 1, secrets: 1}` | 7-player cast composition (plus 1 Demon). |
| `SETUPS[10]` (`sim/content.gd:260`) | `{town: 7, minions: 2, secrets: 1}` | 10-player cast composition (plus 1 Demon). |
| `ALLOW_NO_GIFT_DENIAL` (`sim/content.gd:13`) | `false` | Whether townsfolk can claim to have no gift (`no_gift`). |
| `SHADOW_SELF` (`sim/content.gd:18`) | `true` | Evil roles receive a parallel genuine reading stream on their cover role. |
| `INFO_BEFORE_KILL` (`sim/content.gd:29`) | `true` | Night readings resolve before Demon kill (so night victims still generate a reading). |
| `DEFENCE_MOVES` (`sim/content.gd:36`) | `true` | Nominees perform active defence moves (reveal gift, accuse, name alibi, etc.) on the block. |
| `USE_FLAVOR_SECRETS` (`sim/content.gd:153`) | `false` | Enables personal flavor secrets (`affair`, `feud`, `theft`, `blackmail`, `grief`) alongside `marked`/`sleepwalker`. |
| `SHARED_EXECUTION_PRIORITY_WEIGHT` (`sim/content.gd:24`) | `0.0` | Shared town consensus bonus during nomination target selection (`0.0` disables it). |

### 1.2 Marked Registration & Secret Setup (`sim/world.gd`, `sim/roles/gravedigger.gd`)
| Location | Current Value | Description |
| :--- | :--- | :--- |
| `sim/world.gd:192` | `0.5` | Probability a `marked` townsperson registers as Demon (`is_demon_for_info`). |
| `sim/world.gd:197` | `0.5` | Probability a `marked` townsperson registers as Evil (`is_evil_for_info`). |
| `sim/roles/gravedigger.gd:64` | `0.3` | Probability Gravedigger reads an executed `marked` townsperson as a random evil role. |

### 1.3 Initial Relationships, Suspicion & Trust (`sim/world.gd`)
| Location | Current Value | Description |
| :--- | :--- | :--- |
| `sim/world.gd:355, 360` | `0.3` | Chance each NPC starts with a `friend` (`0.3`) and/or `rival` (`0.3`). |
| `sim/world.gd:375-378` | `0.1` base (`+0.15` rival, `-0.1` friend) | Initial NPC-to-NPC baseline suspicion (`suspicion_base`). |
| `sim/world.gd:381-385` | `0.5 ± 0.05` (`-0.25` rival, `+0.25` friend, `0.9` lover) | Initial NPC-to-NPC trust (`trust_in`), clamped to `[0.1, 0.95]`. |
| `sim/world.gd:391-392` | `clampf(0.3 + 0.25 * (1 - privacy) + rand(-0.05, 0.1), 0.1, 0.9)` | Initial NPC trust in the player (`player_trust`). |
| `sim/world.gd:396` | `1.5` | Weight multiplier on claiming one's own true role in `role_claim_weights`. |

### 1.4 Daytime Movement, Night Traces & Background Gossip (`sim/world.gd`)
| Location | Current Value | Description |
| :--- | :--- | :--- |
| `sim/world.gd:483` | `0.4` | Probability an NPC visits their haunt during a daytime phase (vs. weighted random block). |
| `sim/world.gd:500` | `0.65` | Probability of a background NPC conversation occurring on a block before the player acts. |
| `sim/world.gd:506` | `0.4 * pair_weight` | Multiplier on background NPC conversation probability after the player acts. |
| `sim/world.gd:675, 696` | `0.5` (`sleepwalker`), `0.55` (flavor secret) | Probability a secret-holder walks at night (`0.75` to target block for `affair`/`theft`/`blackmail`). |
| `sim/world.gd:1194, 1205` | `0.35` (demon), `0.15` (other walker), `0.12` (owned item) | Night item-drop probabilities along a walker's route and chance the dropped item has a recognizable owner. |

## 2. Role-Specific Balancing & Native Suspicion Effects (`sim/role_def.gd`, `sim/roles/*.gd`)

### 2.1 Reading Strength, Card Strength & Defend Strength (`0.0` to `1.0`)
| Role / Shape | `reading_strength` | `card_strength` | `defend_strength` | Notes & Location |
| :--- | :--- | :--- | :--- | :--- |
| Default (`sim/role_def.gd`) | `0.3` (`0.9` PING yes; `clamp(0.9*c/n, 0, 0.8)` group count; `0.35` NIGHT_ROUTE) | `0.6` if implicated | `0.5` if cleared | Base fallbacks in `RoleDef`. |
| Seer (`sim/roles/seer.gd`) | `0.9` (yes) / `0.3` (no) | `1.0` (yes) | `0.8` (no) | `public_threat_bonus = 0.2`. |
| Archivist (`sim/roles/archivist.gd`) | `0.6` (demon) / `0.4` (evil) / `0.15` (good) | `0.8` | `0.0` | Pair includes minion/evil role. |
| Clerk (`sim/roles/clerk.gd`) | `0.3` | `0.0` | `0.5` | Pair includes good role. |
| Dowser (`sim/roles/dowser.gd`) | `clamp(0.9 * count / size, 0.0, 0.8)` | `0.6` (count > 0) | `0.5` (count == 0) | Daytime block crowd reading. |
| Hearthwitch (`sim/roles/hearthwitch.gd`) | `clamp(0.9 * count / size, 0.0, 0.8)` | `0.5 * count` | `0.6` (count == 0) | First-night neighbor reading. |
| Gravedigger (`sim/roles/gravedigger.gd`) | `0.3` | `0.3` (evil role) | `0.5` (good role) | Executed player's role. |
| Night Watch (`sim/roles/nightwatch.gd`) | `0.35` | `1.0` (seen walker) | `0.0` | Block walker watch. |
| Medium (`sim/roles/medium.gd`) | `0.5` | `0.6` (if relayed implicates) | `0.5` (if relayed clears) | Relays unshared dead victim reading. |
| Martyr (`sim/roles/martyr.gd`) | `0.9` (evil hang) / `0.3` (chosen clear) | `0.6` (survived hang) | `0.5` (chosen target) | Substitute execution & clear. |

### 2.2 Native `info_effects` Suspicion Deltas (`sim/roles/*.gd`)
| Role | Suspicion / Trust Deltas | Location & Details |
| :--- | :--- | :--- |
| Seer | Yes: `+0.45` each (`+0.85` if 1 left); No: `-0.45` (own) / `-0.30` (heard) | `sim/roles/seer.gd:86-123`. |
| Dowser / Hearthwitch | Count 0: `-0.25` each; Count > 0: `+0.35 * count` (`+0.70 * count` if listener excluded); Impossible count: `+0.50` on source | `sim/roles/dowser.gd:88-137`, `sim/roles/hearthwitch.gd:55-103`. |
| Clerk | `-0.15` on pair members; `-0.30` on Clerk source if listener's own true role is named | `sim/roles/clerk.gd:55-82`. |
| Archivist | `+0.35` on pair members (`+0.75` if 1 candidate left after excluding self/dead-good) | `sim/roles/archivist.gd:65-95`. |
| Gravedigger | Executed: `+1.0` (evil) / `-0.40` (good); Nominator: `+0.25` (if good) / `-0.20` (if evil); Player trust: `-0.06` (backed innocent) / `+0.08 + 0.06*insight` (backed evil) | `sim/roles/gravedigger.gd:94-137`. |
| Night Watch | `+0.50 * night_sighting_scale` on seen walkers; `+0.45` on watcher if listener stayed home on that block | `sim/roles/nightwatch.gd:87-115`. |
| Rumormonger | `-0.12` on both members of the secret pair | `sim/roles/rumormonger.gd:69-82`. |
| Medium | `0.6x` multiplier on inner relayed `info_effects`; `+0.30 * night_sighting_scale` on relayed night sighting | `sim/roles/medium.gd:86-125`. |
| Veteran | `+0.12` on residents of attacker's approach block; `quiet_night_effect = -0.06`, `quiet_night_claim_weight = 0.025` | `sim/roles/veteran.gd:21-22, 62-84`. |
| Warden | `quiet_night_effect = -0.15`, `quiet_night_claim_weight = 0.06` | `sim/roles/warden.gd:21-22`. |
| Martyr | `-0.20` on chosen target; `+1.0` on target if hanged & Martyr lived; `-2.0` on Martyr & saved if Martyr dies in their place | `sim/roles/martyr.gd:100-128`, `sim/world.gd:1027-1029`. |

### 2.3 Role Target Selection & Ability Weights (`sim/roles/*.gd`)
| Role | Parameter | Current Value | Location & Description |
| :--- | :--- | :--- | :--- |
| Seer | Target score | `(0.5 - abs(susp - 0.35)) + (0.2 if unchecked else 0.0) + rand(0, 0.25)` | `sim/roles/seer.gd:56-62`: prefers uncertain (`~0.35` suspicion) and unchecked targets. |
| Warden | Target score | `rand(0, 0.3) + (1.0 - susp if info_claim) + 0.8*trust - 0.5*susp + 1.2*protect_pref` | `sim/roles/warden.gd:44-52`: prioritizes trusted info-claimants and player-suggested targets. |
| Martyr | Pick threshold & score | Threshold `0.62`; score `(1.0 - susp) + 0.4*(trust - 0.5) + rand(-0.08, 0.08)` (`player_trust - 0.5` for player) | `sim/roles/martyr.gd:48-65`: locks onto a cleared/trusted townsperson from night 1 onward. |
| Martyr | Vote reluctance | `0.6 - 0.4*paranoia - 0.3*pressure - 0.4*max(0, base_score - 0.8)` | `sim/roles/martyr.gd:153-162`: Martyr resists voting yes on chosen target unless pressured/paranoid. |
| Sexton | Knell decision | `few_left: 0.35` (`<= 5` alive), `deaths: 0.1 * dead_count` | `sim/roles/sexton.gd:28-35`: weights for spending one-shot knell at dawn. |
| Psychologist | Conversation nudge | `0.5` (real), `0.6` scapegoat pick chance (fake Medium) | `sim/roles/psychologist.gd:18, 63`: boosts weight of picking a conversation partner and framing scapegoat. |
| Breathstealer | Silence phase chances | `[0.3, 0.5, 1.0]` if best score `> 1.0`, else `[0.15, 0.3, 0.7]`; noise `rand(0, 1.0)` | `sim/roles/breathstealer.gd:25-75`: daytime silence target scoring and phase roll. |
| Revenant | Totem & curse weights | Phase chances `[0.45, 0.6, 1.0]`; voter curse suspicion `+0.15`; evil vote roll `0.55` | `sim/roles/revenant.gd:24-112`: daytime totem placement, curse suspicion, and evil pile-on. |

## 3. Core Mind, Evidence Ledger, Trust & Social Dynamics (`sim/mind.gd`, `sim/social.gd`, `sim/world.gd`, `game/game.gd`)

### 3.1 Core Suspicion, Paranoia & Sigmoid Temperature (`sim/mind.gd`)
| Parameter | Current Value | Location & Description |
| :--- | :--- | :--- |
| Decision sigmoid slope | `4.0` (`1.0 / (1.0 + exp(-total * 4.0))`) | `sim/mind.gd:75`: sharpness of all `decide()` rolls across Mind. |
| Paranoia formula | `0.07 * dead * (1.0 - 0.6 * composure)` | `sim/mind.gd:61`: paranoia growth per dead player, damped by composure. |
| Confidence scaling on suspicion | `1.4 - 0.8 * confidence` (range `0.6x` to `1.4x`) | `sim/mind.gd:411`: low-confidence NPCs swing less on evidence; high-confidence swing more (inverse of name—worth reviewing!). |
| Max suspicion cap | `1.5` (`clampf(raw, 0.0, 1.5)`) | `sim/mind.gd:388`: upper bound on total suspicion toward an NPC. |

### 3.2 Evidence Ledger, Credence & Night Reconsideration (`sim/mind.gd`)
| Parameter | Current Value | Location & Description |
| :--- | :--- | :--- |
| `HONESTY_K` & `HONESTY_CAP` | `0.8`, `0.5` | `sim/mind.gd:570-571`: sensitivity and max penalty on `honesty_factor()` from contradictory claims. |
| Rival role-claim delta | `+0.6` (`0.6 * claim_weight(who)`) | `sim/mind.gd:516`: suspicion added when someone claims the listener's own true role. |
| Near-death sighting scale | `1.0` (near victim block/time), `0.12` (elsewhere), `* 0.7` per walk-credence | `sim/mind.gd:530-539`: scales suspicion of night sightings based on proximity to a Demon kill and alibi credence. |
| Sighting suspicion magnitudes | `+0.50` (saw walker), `+0.30` (item trace), `+0.35` (contradicts stay-home) | `sim/mind.gd:645, 654, 718`: base deltas before `night_sighting_scale` and source credence. |
| Demon-victim claim boost | `1.95` (`claim_weight = 1.95`, `walk_credence = 0.95`) | `sim/mind.gd:758-761`: near-certain credence granted to a player killed by the Demon at night. |
| Night reconsideration (`reconsider`) | `doubt = clamp(susp, 0, 0.9)`, `rate = 1.0 - 0.6 * confidence` | `sim/mind.gd:851-859`: overnight discounting of social/claim evidence from suspected sources. |

### 3.3 Player Trust Deltas & Grievances (`sim/mind.gd`, `sim/world.gd`, `game/game.gd`)
| Event / Mechanic | Current Value | Location & Description |
| :--- | :--- | :--- |
| `SERIOUS_GRIEVANCE` threshold | `0.12` | `sim/mind.gd:318`: grievance delta `>= 0.12` requires an explicit apology and damps passive recovery. |
| Apology recovery fraction | `0.25` (serious) / `0.50` (ordinary) | `sim/mind.gd:329`: fraction of `trust_lost_to_player` restored by `apologize()`. |
| End-of-day passive recovery | `(0.03 + 0.04 * privacy) * (0.4 if trust < 0.35 else 1.0)` | `sim/mind.gd:352-353`: overnight recovery of `trust_lost_to_player` when no serious grievance is active. |
| Civil conversation bonus | `+0.04 * (1.0 - 0.5 * privacy)` | `game/game.gd:832`: trust gained when leaving a conversation civilly without pressing. |
| Question fatigue penalty | `-(0.03 + 0.05 * privacy) * (1.0 - 0.5 * composure)` per question `> 3` | `game/game.gd:483-485`: trust penalty when asking more than 3 questions in one conversation. |
| Pressed with evidence | `-(0.03 + 0.06 * privacy)` | `game/game.gd:591`: trust penalty when confronting an NPC with a contradicton/case card. |
| Broke confidence (shared gift) | `-(0.05 + 0.2 * privacy)` | `sim/world.gd:587`: trust penalty when repeating a gift reading shared in confidence. |
| Spread secret | `-(0.08 + 0.4 * privacy)` (trust cap `0.3` if `privacy >= 0.67`) | `sim/world.gd:601-604`: trust penalty and permanent ceiling when exposing a personal secret. |
| Protection / promise keeping | `+0.03` (offered protection), `+0.06` (kept word), `-0.15` (broke word) | `game/game.gd:628`, `sim/world.gd:967, 1084, 1117`: trust changes for promises. |
| Voting & nomination trust | `-0.15` (nominated), `+0.15` (defended & spared), `-0.08` (voted yes) | `sim/world.gd:932, 960, 1003`: direct trust impact on the nominee. |
| Execution grief (`friend`/`lover`) | `-0.3 * strength` (nominated), `-0.2 * strength` (voted yes), cap `0.55` | `sim/world.gd:1039-1047`: bereaved friend/lover loses trust in the player if an innocent dies. |
| Night pressure decay | `pressure *= 0.6` | `sim/world.gd:1278`: overnight decay of accumulated conversational pressure. |

### 3.4 Background Social Gossip & Approaches (`sim/social.gd`)
| Parameter | Current Value | Location & Description |
| :--- | :--- | :--- |
| Idle chat weight (`nothing`) | `0.3` | `sim/social.gd:51`: baseline weight for chatting about nothing vs. sharing facts/suspicions. |
| Hearsay suspicion weight | `clampf(0.75 * trust, 0.0, 0.55)` | `sim/social.gd:148`: how strongly an NPC adopts a trusted peer's suspicion during gossip. |
| Paranoia drift | `0.06 * paranoia` | `sim/social.gd:268`: per-phase upward drift in suspicion toward the most-suspected person. |
| NPC approach roll & threshold | `0.4` roll chance, `0.35` score threshold | `sim/social.gd:302, 315`: probability and minimum urgency score for an NPC to seek out the player. |

## 4. Town Meeting: Claims, Accusations, Nominations, Defence & Voting (`sim/mind_meeting.gd`)

| Subsystem | Parameter | Current Value | Location & Description |
| :--- | :--- | :--- | :--- |
| Sightings | Volunteer sighting threshold | `1.2 - paranoia` (score `= susp + 0.4*gossip`) | `sim/mind_meeting.gd:103-104`: when an NPC volunteers a night sighting unprompted at meeting start. |
| Public claim | `openness` / `day` / `pressure` / `base` | `1.2*openness`, `0.3*(day-1)`, `0.8*pressure`, `-0.35` base | `sim/mind_meeting.gd:199-219`: core weights for volunteering a role/reading in town meeting. |
| Public claim | Role modifiers | `-0.5` (`hides_from_demon`), `-0.4` (`gift_keeps_giving`), `+0.3` (one-shot), `+0.8` (`<= 5` alive), `-0.6` (promised player first) | `sim/mind_meeting.gd:204-217`: role-protection and urgency modifiers on public claiming. |
| Reveal cost | `reveal_cost()` weights | `0.8*privacy + 0.2 + 0.5*hides + 0.4*keeps_giving + 0.35*afraid - 0.12*(day-1) - 0.6*few_left` | `sim/mind_meeting.gd:266-283`: reluctance barrier compared against a reading's `card_strength` / `defend_strength`. |
| Relay reading | `RELAY_WEIGHT` & `RELAY_CORROBORATE` | `0.3`, `0.05` | `sim/mind_meeting.gd:291-292`: weight of privately heard readings and corroboration bonus per confirmed claim. |
| Consensus | `CONSENSUS_BASE`, `FADE`, `CAP`, `HINT` | `0.12`, `0.6`, `0.3`, `1.15` | `sim/mind_meeting.gd:483-486`: meeting bandwagon pressure from stacked public accusations. |
| Accusation | `public_accusation` pressure | `0.15 * pow(0.5, earlier)` | `sim/mind_meeting.gd:516`: diminishing suspicion bump per repeated public accusation against the same target. |
| Nomination | `nomination_threshold()` | `max(0.45, 0.86 - 0.08*day) - 0.15*(conf - 0.5)*2 - 0.5*paranoia` | `sim/mind_meeting.gd:698-700`: minimum effective suspicion required for an NPC to nominate someone. |
| Self-defence | `DEFENCE_ROPE` & `DEFENCE_LIE_BLOWBACK` | `1.1`, `0.02` | `sim/mind_meeting.gd:832-833`: urgency multiplier on the block and penalty when caught in a weak defence. |
| Self-defence | `apply_defence_move` caps | `-0.35` (`reveal_gift`), `-0.30` (`confess_secret`/`sleepwalk`), `-0.12` (`red_herring`), `±0.06` (`pair_other`), `-0.05` (`lying`), `-0.06` (`misled`), `-0.02` (`plea`) | `sim/mind_meeting.gd:950-1037`: suspicion relief granted to the nominee by each defence move type. |
| Voting | Base threshold (`need`) | `0.5 - 0.12*(conf - 0.5)*2 + (0.1 if day <= 1 else 0) - 0.4*paranoia` | `sim/mind_meeting.gd:1049`: suspicion threshold required to vote `YES` on an execution. |
| Voting | Social & player modifiers | `player_votes_yes: 0.25*trust - 0.05`, `player_defends: -0.25*trust`, `player_accuses: 0.2*trust`, `trust_in_nominee: -0.6*(trust - 0.5)`, `distrusts_nominator: -0.15`, `persuaded_to_spare: -0.5*pref`, `prefers_block: -0.4` | `sim/mind_meeting.gd:1054-1071`: modifiers added to effective suspicion during a vote. |

## 5. One-on-One Dialogue, Pressing & Disclosure (`sim/mind_dialogue.gd`)

| Parameter | Current Value | Location & Description |
| :--- | :--- | :--- |
| Disclosure openness score | `1.0*(1 - privacy) + 1.2*(trust - 0.5) + 0.6*pressure + 0.1*(day - 1) - 0.72 + jitter(±0.2)` | `sim/mind_dialogue.gd:31-38`: determines how much an NPC shares in private (`NONE < 0.15 <= VAGUE < 0.45 <= PARTIAL < 0.75 <= FULL`). |
| Fear expression (`express_fear`) | `0.2 + 0.3*(1 - composure) - 0.5*pressure - paranoia` (`* 0.5` if eased, cap `0.85`) | `sim/mind_dialogue.gd:107-118`: chance an NPC hesitates out of fear of the Demon before revealing their gift. |
| Request thresholds | Protection: `trust >= 0.45`; Confidence: `privacy >= 0.45` and `trust >= 0.40`; Gift help: `trust >= 0.45`; Vote: `susp >= 0.55` and `trust >= 0.35` | `sim/mind_dialogue.gd:149-197`: trust/suspicion gates for NPC side-requests during private talks. |
| Press (`press()`) | `p_nerves = (0.6 if hiding else 0.2) * (1 - composure) * strength`; `pressure += 0.35 * strength` | `sim/mind_dialogue.gd:440-445`: chance pressing makes an NPC crack vs. get defensive, and pressure added. |
| Whereabouts slip chance | `0.25 * (1 - composure) + 0.15 * pressure` | `sim/mind_dialogue.gd:523`: chance a lying secret-walker slips up and gives a vague/hesitant alibi. |
| Daytime witness memory | `2 + round(insight * 4.0)` sightings (`2` to `6`) | `sim/mind_dialogue.gd:561`: how many daytime block sightings an NPC remembers and shares. |
| Gossip share count | `1 + round((gossip + 0.5 * pressure) * 3.0)` (`1` to `5`) | `sim/mind_dialogue.gd:832`: number of heard claims/rumors an NPC passes along when asked for gossip. |

## 6. Evil AI: Bluffs, Scapegoats & Night Kills (`sim/evil.gd`, `sim/content.gd`)

### 6.1 Evil Caution, Heat & Bluff Constants (`sim/evil.gd`, `sim/content.gd`)
| Constant | Current Value | Location & Description |
| :--- | :--- | :--- |
| `SHADOW_OWN_READING_WEIGHT` | `1.2` | `sim/content.gd:21`: bonus weight for evil choosing their own shadow role as their cover claim. |
| `EVIL_HINT_CHANCE` | `0.3` | `sim/evil.gd:9`: chance a fabricated reading subtly hints at the scapegoat rather than framing directly. |
| `MEDIUM_USELESS_CHANCE` | `0.15` | `sim/evil.gd:12`: chance a fake Medium claims the dead victim left no usable reading. |
| `EVIL_CAUTION_DEMON` / `MINION` | `0.8` / `0.7` | `sim/evil.gd:18-19`: baseline caution for Demon and Minion when deciding whether to push a risky lie. |
| `MINION_ID_DRIFT` & `FLOOR` | `0.08`, `0.25` | `sim/evil.gd:20-21`: per-day drop in Minion caution when the Demon stays safe (down to `0.25`). |
| `HEAT_FADE` | `0.75` | `sim/evil.gd:22`: weight on current public suspicion vs. peak historical heat (`0.25`). |

### 6.2 Demon Kill Target & Poisoner Scoring (`sim/evil.gd`)
| Factor | Current Value | Location & Description |
| :--- | :--- | :--- |
| Info-role claimant | `+3.0` (continuous gift) / `+1.0` (spent/one-shot) / `+1.0` extra for Seer | `sim/evil.gd:483-489`: priority on silencing active information roles. |
| Threat to Demon | `+2.0` (public reading implicates Demon), `+0.8 * hostility` (suspects/accuses Demon) | `sim/evil.gd:490-496`: priority on eliminating players closing in on the Demon. |
| Vulnerability & framing | `+0.7` (lives alone), `-4.0` (active scapegoat), `-0.8` (likely warded), `-10.0` (attack failed before) | `sim/evil.gd:497-524`: avoids wasting kills on warded/failed targets or killing the scapegoat. |
| Demon personality moods | `+1.5` (`vengeful`), `+1.5` (`cunning` frame), `+2.0` (`hungry` easy kill), `0.03` unpredictable roll | `sim/evil.gd:467, 502-509`: mood-specific kill preferences. |
| Poisoner target score | `-3.5` (gift already spent), `+2.5` (claimed Warden) | `sim/evil.gd:604-614`: Poisoner strongly prioritizes active Wardens and continuous info roles. |

## 7. Workshop Evaluator, Solver & Presentation (`workshop/*.gd`, `game/workshop_presentation.gd`)

| File | Constant / Parameter | Current Value | Description |
| :--- | :--- | :--- | :--- |
| `workshop/case_eval.gd` | `DEFAULT_ERR`, `OWN_ERR` | `0.01`, `0.002` | Floor error probabilities on third-party vs. first-party Workshop claims. |
| `workshop/case_eval.gd` | `LR_WEAK`, `LR_MODERATE`, `LR_STRONG` | `1.5`, `3.0`, `10.0` | Likelihood ratio cutoffs for grading case strength (`weak`, `moderate`, `strong`, `airtight`). |
| `workshop/case_eval.gd` | Trust weight on prior | `pow(cred / (1 - cred), -2.0 * (trust - 0.5))` | Scales how an NPC juror's trust in a source shifts their belief in that source's claim. |
| `workshop/role_constraints.gd` | `BLUFF_WEIGHT` | `0.92` | Discount applied to worlds where a townsperson's role claim is a lie (`0.08` penalty). |
| `workshop/live_activity.gd` | `DEMON_DETOUR` | `0.05` | Probability the Demon takes a non-shortest route (`+1` block detour) to the victim's home. |
| `workshop/movement_model.gd` | `NIGHT_OUT_RATES` | `demon: 1.0`, `minion: 0.25`, `gift: 1.0`, `secret: 0.55`, `ordinary: 0.05` | Prior probabilities of walking at night by activity profile (`haunt` daytime visit `0.7`). |
| `workshop/public_evidence.gd` | `DEMON_VICTIM_GOOD` | `0.95` | Likelihood multiplier that a night kill victim is Good rather than a Minion (`0.05`). |
| `workshop/speech_evidence.gd` | `REFUSAL_LR` | `1.5` | Likelihood ratio nudge Toward Evil when an NPC refuses to claim a role (`no_comment`). |
| `workshop/consequences.gd` | Conclusion coefficients | `evil/demon/minion: +0.45`, `good: -0.4`, `marked: -0.1`, `suspicious: +0.3` | Base suspicion shift (`delta = coeff * move * venue_mult`) when an NPC accepts a presented case. |
| `workshop/jury.gd` | Stance thresholds (`net`) | `accept >= 0.6`, `partial >= 0.35` | Net persuasion score cutoffs for an NPC juror to accept or partially accept a presented theory. |
| `workshop/support_model.gd` | Source quality formula | `clampf(0.2 + 0.65*trust - 0.35*susp, 0.05, 0.95)` | Credibility an NPC juror assigns to each cited witness in a Workshop case. |
| `workshop/theory.gd` | Theory stickiness | `bias = pow(3.0, confidence)`, `threshold = 1.0 + 4.0 * confidence` | How strongly a high-confidence NPC clings to their existing pet theory before switching. |
| `game/workshop_presentation.gd` | Venue & stance multipliers | Venue: `private: 1.0`, `meeting: 0.6`, `nomination: 0.5`; Trust: `accept: +0.06`, `partial: +0.02` | Scales suspicion and trust impact of presenting a Workshop case in private vs. public. |

## 8. Proposed Centralization Architecture (`sim/tuning.gd`)

To make balancing fast and frictionless without creating circular dependencies, we can centralize these values into **`sim/tuning.gd` (`class_name Tuning`)** organized with clean inner classes (or sub-dictionaries) by domain:

1. **`Tuning.Setup`**: Cast sizes (`SETUPS`), rule toggles (`SHADOW_SELF`, `INFO_BEFORE_KILL`, `DEFENCE_MOVES`, `USE_FLAVOR_SECRETS`), initial relationship/trust distributions, Marked registration odds, and night trace drop rates.
2. **`Tuning.Roles`**: Default shape strengths plus per-role sub-blocks (`SEER`, `WARDEN`, `DOWSER`, `HEARTHWITCH`, `CLERK`, `ARCHIVIST`, `GRAVEDIGGER`, `NIGHTWATCH`, `RUMORMONGER`, `MEDIUM`, `VETERAN`, `MARTYR`, `SEXTON`, `PSYCHOLOGIST`, `BREATHSTEALER`, `REVENANT`) holding `reading_strength`, `card_strength`, `defend_strength`, `info_effects` deltas, and target-picker weights.
3. **`Tuning.Mind`**: Sigmoid temperature, paranoia scaling, confidence multiplier, `HONESTY_K`/`HONESTY_CAP`, near-death sighting scales, demon-victim boost, and overnight reconsideration rates.
4. **`Tuning.Trust`**: All player trust deltas (civil talk, question fatigue, pressing, broken confidence, exposed secrets, promises, nominations, votes, bereaved grief, `SERIOUS_GRIEVANCE`, apology recovery, and passive overnight recovery).
5. **`Tuning.Social`**: Background conversation probabilities, gossip hearsay weights, paranoia drift, and NPC-approaches-player thresholds.
6. **`Tuning.Meeting`**: Public claim decision weights, `reveal_cost` weights, `RELAY_WEIGHT`, consensus bandwagon constants, nomination threshold formula coefficients, self-defence move caps, and voting modifiers.
7. **`Tuning.Dialogue`**: Private openness tier cutoffs and weights, fear expression formula, side-request trust gates, press nerve/pressure multipliers, whereabouts slip rate, and witness/gossip memory counts.
8. **`Tuning.Evil`**: Caution/heat constants, bluff/hint chances, scapegoat weights, Demon kill-scoring weights, and Poisoner target weights.
9. **`Tuning.Workshop`**: Solver error floors (`DEFAULT_ERR`, `OWN_ERR`), likelihood ratio cutoffs, `BLUFF_WEIGHT`, movement priors (`DEMON_DETOUR`, `NIGHT_OUT_RATES`), juror stance thresholds, conclusion coefficients, and presentation venue multipliers.

# Role shortlist from the Clocktower passes

Nov 11, 2026 · Claude-Lantern, from brainstorming with Michael · **ideas only, nothing decided or built**

Michael's own list (Intercessor, Informer, Shrouded, Ruiner, Eraser), the earlier Claude ideas, and a pass through Trouble Brewing, Bad Moon Rising, Sects & Violets and the experimental characters. Clocktower names are used as handles; most would need their own names here.

**How to read the cost column.** It is my estimate and hasn't been checked against the code.
- **Low:** a new kind of reading, card or public event. The solver's worlds don't change.
- **Medium:** new NPC behaviour (how they vote, nominate or bluff), or one new hidden fact per case.
- **High:** changes what a possible world is (alignment or roles that move mid-game).

## Calls to make once

These came up again and again. Each one settles several roles.

1. **May a good NPC ever misstate things?** Suggested answer: only under one flagged secret (the "thinks they're evil" one), so the solver treats it as one more possibility instead of doubting everyone.
2. **Advice roles.** Where Clocktower gives a player a choice, the NPC keeps the gift and takes the player's suggestion, weighted by trust.
3. **Death effects become public events or vote effects.** The dead can't talk and extra deaths unbalance a short game, so "they die" becomes "a quiet night", "silenced", "a void nomination" or "left at their hearth".
4. **One poisoning Demon, not three.** Poison should follow from who the Demon is, so it adds no hidden state and wrong readings become a clue.
5. **Build shared mechanisms once.** Sections B, C and G each unlock several roles.

## A. Stand-alone gifts (low cost)

| Role | Version for this game | Why it earns a place |
|---|---|---|
| **Coroner** (earlier idea) | Learns how each death happened: night walk, hex, Minion kill, own hand | Feeds the demon-type declaration, which costs credibility when wrong. Worth more with every Demon added |
| **Chambermaid** | Picks a person; learns whether they left home that night | Person-based, where today's watches are place-based. "Home on a kill night" points at a Hexer. Clashes directly with a home alibi |
| **Knight** | Starts knowing two people who are not the Demon | The town finds Minions first (top suspect is the Demon only 13–22% of the time by day 3). Anything about Demon-ness specifically helps |
| **Grandmother** | Starts knowing one good person's gift. If that person is hanged, she holds a grudge against the nominator | Gives an NPC firsthand knowledge to reason from. The drawback is visible and avoids a death |
| **Ravenkeeper** | When killed at night, a reading is left at their home for the player to find | Uses the existing "untold reading at the hearth". Gives searching a payoff. One of these is enough (so no Sage) |
| **Bounty Hunter** | Starts knowing one evil person; learns another when that one dies. The hunted person knows | A chain that gives the town direction. No alignment swap |
| **Nightwatchman** | Once, reveals itself for certain to one person, possibly the player | A certain ally whose word only you can vouch for. Needs a new name (there is already a Night Watch) |
| **Oracle** | Learns how many of the dead are evil | Simple. Check against the Gravedigger first, which measured as a net negative for the town |
| **Preacher** | Each night picks a person; a Minion picked loses its ability and knows it | The effect shows up over days (the wrong readings stop, the forced votes stop). Follows from who was visited, so no hidden state |
| **High Priestess** | Each day learns, or tells the player, who is most worth talking to | The game can compute it: who holds the card that combines best with what you have. A hint role or onboarding aid |

Also workable, lower priority: **Steward** (starts knowing one good person), **Cannibal** (gains the gift of whoever was last hanged; softens wrongful hangs, overlaps the Medium), **Savant** (two readings from gifts not on the script, one true and one false; costs more than the rest here).

**Caution: Dreamer.** It is a role-table reading, and five of those were measured barely moving the people they name. Fix that before adding a sixth.

## B. Advice roles (low to medium cost)

One-shot gifts the player can lobby. All need the same small piece: an NPC accepting a suggested target according to its trust in the player.

| Role | Version for this game |
|---|---|
| **Slayer / Exorcist** (merged) | Names someone at a meeting. If they are the Demon, there is no kill that night. The Demon learns who the Slayer is |
| **Seamstress** | Once, checks whether two people share an alignment |
| **Juggler** | On day 1, publicly guesses several people's alignments; learns that night how many were right |
| **Professor** | Once, brings a dead person back for a single meeting |
| **Golem** (as a gift) | One nomination per game that goes straight to the block with no vote. Votes on the Demon fail more often than not even at 75% good support |
| **Virgin** | The first time it is nominated: a good nominator is publicly cleared and the nomination fails. An evil nominator gets an ordinary nomination, which is the tell |

## C. Votes and nominations (medium cost)

Two halves that balance each other: roles that distort the vote record, and gifts that read it.

**Compelled behaviour.** The shared piece is an NPC acting against its own beliefs for a stated reason, and the tell that leaves.

| Role | Kind | Version for this game | Tell |
|---|---|---|---|
| **Intercessor** (Michael) | Minion | Visits a home at night; that person must vote with it next day | A vote that contradicts the voter's own stated suspicion. Also gives Minions a reason to walk at night |
| **Witch** | Minion | Picks someone each night; if they nominate next day, the nomination is void and they are silenced | Public when it triggers. Can hit the player |
| **Harpy** | Minion | Forces one person to accuse another publicly | An accusation with no cards cited behind it |
| **Grudge** (earlier idea) / **Zealot** / **Ogre** | Secrets | Always votes against one person / always votes yes / always votes as one chosen person does | Open or deducible. Pick one or two, not all |
| **"Thinks they're evil"** (Lunatic, simplified by Michael) | Secret | Acts as evil would until convinced they are good; then hands over their true information | "Convince them" is a player action. The one place a good NPC misstates things |

**Reading the record.**

| Role | Version for this game | Note |
|---|---|---|
| **Flowergirl** | Learns whether the Demon voted today | Only pays off cross-checked against the public vote record |
| **Town Crier** | Learns whether a Minion nominated today | Aims at the town's main failure. Evil needs to learn when to hold back |
| **Organ Grinder** (Minion) | Votes are hidden while it lives | Loud and fair. Blinds every role above, so the town has a reason to hunt it |

## D. Bluff and claim puzzles (low to medium cost)

| Role | Kind | Version for this game |
|---|---|---|
| **Evil Twin** | Minion | Claims the same gift as one good NPC; each names the other. No extra win clause. A pure two-way puzzle that takes a third card to break |
| **Widow** | Minion | Sees everything once at the start and poisons one person for the game; one good NPC knows a Widow is present. The cleaner form of Michael's Informer |
| **Informer** (Michael), as a canary trap | Minion | Only learns the plans the player tells it, or tells someone it talks to. Feed different people different plans and see which the Demon avoids |
| **Spy** | Minion | Reads as good. The mirror of Marked. Makes a clear doubtful, and clears are among the strongest cards |
| **Framer** (from the Forger idea) | Minion | Plants someone's belongings. Dropped belongings are strong evidence (+0.20), and the framed person's alibi creates a clash |
| **Assassin** | Minion | One extra kill that fits neither Demon type's pattern. Muddies the declaration; the Coroner can tell it apart |
| **Mutant space** | Secret | A secret that is dangerous to reveal. The player learns it but can't safely present it |

## E. Demons

| Demon | Version for this game | Tell | Cost |
|---|---|---|---|
| **Lord of Typhon** | The whole evil team lives on one street or works at one place; one more Minion | Clustering in the profile cards | Low: it removes possible worlds |
| **Glutton / Po** (earlier idea) | No kill the first night, then two on alternating nights | The rhythm | Low. Ten-person towns only |
| **Shrouded** (Michael) | A night walker that can't be seen and leaves no trace on the night after a good person is hanged | Sightings after clean days, none after a bad hanging | Low to medium. Drop the "three good voters" clause; watch how often it triggers |
| **No Dashii** | Poisons the people who share its workplace or street, all game | The same readers are wrong every time, and they point at a place | Medium. My pick of the three poisoners |
| **Pukka** | Poisons tonight's target, who dies the next night | The walker is seen the night before each death; the victim's last reading is suspect | Medium |
| **Ruiner** (Michael) | Poisons whoever the victim last publicly accused or voted for | Predictable from the public record | Medium |
| **Eraser** (Michael) | The town forgets some of the victim's evidence; the Demonologist remembers but can't cite it | What was erased points at who benefits | Medium |
| **Lleech** | Can't be hanged while its host lives; the host's readings are always wrong | A failed execution, then a hunt for the host | Medium to high. Needs section F |

**Detectors that go with a poisoner:** Mathematician (how many gifts misfired), Acrobat reworked (did this person's gift fail tonight?), and the Snake Charmer without the swap (its gift burns out if it picks the Demon).

## F. A hanging with a consequence (medium cost, shared)

All of these need NPCs to weigh what happens if a hanging goes through. Today a vote only weighs suspicion.

| Role | Kind | Consequence |
|---|---|---|
| **Goblin** | Minion | Claims it when nominated; hanging it that day is very bad for the town. A shield the Demon can bluff |
| **Saint** | Secret, open | Hanging it gives evil two kills that night |
| **Fearmonger** | Minion | Marks someone, and the town is told a mark exists; if its own nomination hangs them, the town pays |
| **Pacifist space** | Gift | A good person's hanging can fail. Strong here, since wrongful hangs are how the town loses. Needs a limit |
| **Devil's Advocate** | Minion | Only alongside the Pacifist, so a survived hanging is ambiguous |
| **Moonchild** | Secret | When hanged, names someone; if they're good, they're silenced next day |
| **Klutz** | Secret | When it dies, the player must publicly vouch for someone; if they're evil, the player loses credibility |

## G. Alignment that changes (high cost, later)

Summoner (no Demon until night 3, then a good person becomes it), Possessor (earlier idea), Fang Gu, the Imp's pass-along, and the Barber. Build the machinery once for all of them. The Barber may be cheaper than it looks: a swapped good NPC would simply say so.

Never on the same script as the Scion, at least at first.

## H. Player abilities

| From | As a Demonologist ability |
|---|---|
| **Alsaahir** | Name the Demon and its Minions to end the case; a wrong call costs heavily. Targets the "identified the Demon but lost" games (over a third of the bot's correct identifications) |
| **Princess** | A quiet night after you nominate and hang someone evil |
| **Puzzlemaster** | Correctly naming who holds the case's secret earns a confirmed reading |

## I. Special cases, not script roles

Rare case modifiers for the roguelike structure:
- **Leviathan:** nobody dies at night, but two wrong hangings lose, and the town has a fixed number of days. The pure quarterback test, and a possible persuasion tutorial.
- **Legion:** most of the town is evil, and the player has to work that out.

## Skipped, and why

- **Game-ending or too deadly:** Atheist, Heretic, Boomdandy, Psychopath, Riot, Al-Hadikhia, Lycanthrope, Ojo (good NPCs claim openly, so it would delete the best gifts).
- **Need a human storyteller or pure social play:** Amnesiac, Fisherman, Artist, Politician, Mezepheles, Vizier, Yaggababble, Magician, Cult Leader.
- **Extra poison or drunkenness the game can't read:** Sailor, Innkeeper, Minstrel, Sweetheart, Xaan.
- **No fun to watch an NPC do:** Gambler, Courtier, Philosopher.
- **Depend on the dead talking:** Farmer, Banshee as written. (A standing accusation after death is worth keeping as an idea.)
- **Covered already or a duplicate:** Balloonist, Noble, Sage, Fool, Tea Lady, Gossip, Tinker, Mayor, Baron, Marionette.
- **Other:** Coward, Turncoat, Whisperer unless its rumour can be traced, Choirboy and King, Huntsman and Damsel, Pixie, Poppy Grower, Village Idiot, Engineer, General, Hatter, Hermit, Plague Doctor, Snitch, Boffin, Wizard, Wraith, Kazali, Lil' Monsta, Zombuul, Shabaloth, Vortox, Pit-Hag, Godfather, Mastermind, Vigormortis until Minion kills exist.

## If I had to pick a first wave

Low cost, each doing a job the measurements say is needed:
- **Gifts:** Coroner, Chambermaid, Knight, Grandmother, the merged Slayer.
- **Minions:** Intercessor, Evil Twin.
- **Demon:** Lord of Typhon.
- **Then section C as a set,** since the vote readers and the vote distorters only make sense together.

Anything that changes the solver's worlds is better left until the connections work has landed, so two large changes to beliefs aren't in flight at once.

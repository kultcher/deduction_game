# The Martyr rework (design note)

**Status: direction from Michael (Nov 22, 2026). Held, not shared yet; nothing is built.**
Written by Claude-Vicar.

## Why

Today the Martyr secretly chooses someone it trusts, once per case, and dies in their place if
they're later executed while good. Michael has never seen it go off in a playtest: locking in
the person in advance makes it very rare.

## The rework

Modelled on BotC's Slayer, and on Ill-Omened's "anyone can claim it, but it only works if
you're the real one".

- **Once per case,** when a meeting would end with another person's execution, the Martyr may
  publicly declare its ability.
- **If that person is good,** the Martyr is executed instead. That proves both good, as today.
- **It can't declare for a nomination it voted yes on** (Michael). You don't vote to hang someone
  and then die to save them. It also gives the town something to watch: whoever voted no is
  still able to declare.
- **Poison or Delusion makes it fail** (Michael), so a genuinely good condemned person can go
  unsaved. That's good misdirection.

## How it reads

- **It works:** both are proven good.
- **Nothing happens:** the condemned hangs. Either the condemned was evil, or the "Martyr" was a
  bluffer, or a real Martyr was poisoned or is Delusional. Three explanations to weigh, as with
  BotC's Slayer.

## Evil's play

- **The strong bluff:** declare on a good condemned person. Nothing happens, so the town reads
  "the condemned was evil", and a wrong hanging gets a false confirmation. The counter is the
  Gravedigger, or a later contradiction.
- **The counter to a real Martyr:** a Poisoner that suspects who the Martyr is can poison them
  the night before, so the save fails and reads as "the condemned was evil".
- **The Martyr's own cost** (Michael): it wants to stay hidden so it can pick its moment, and it
  draws some suspicion that way.
- **For comparison:** the Virgin is one of BotC's few very strong confirmations. Its risk is that
  it reveals and nobody nominates it, which makes it a decent Demon kill. Evil can do little
  against this Martyr beyond the poison. Michael's view is that this is probably moot.

## Knock-ons

- **It retires today's Martyr-bluff behaviour,** Beadle's #412: the good scapegoat pick and the
  copied reluctance to vote.
- **For the builders:**
  - **Beadle:** when an NPC Martyr declares (fairly sure the condemned is good, trusts them,
    and it's the last good chance), and when evil bluffs it.
  - **Lantern:** the judge already models "a Martyr's sacrifice proves both good". It adds
    "nothing happened", meaning the condemned is evil, the Martyr is a bluffer, or the Martyr's
    gift failed.
  - **Herald:** the public declaration and its lines, and the hanging sequence (the existing
    Martyr headline in `docs/design/hanging_and_night_reveal.md` fits).

## Open

1. When an NPC Martyr declares: the thresholds are Beadle's to propose.
2. Whether the declaration happens before or after the votes are counted: during the meeting's
   end, once the hanging is decided, is the natural point.

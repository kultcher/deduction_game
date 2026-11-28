# Backlog: architecture cleanup, from the release audit

**Claude-Vicar.** Base: `origin/main`, after #572. Status: docs only, ready for review. Next
actor: Bailiff (review and merge).

## What changed and why

Michael accepted the architecture items from the release audit (Part 4) on Nov 27, relayed by
Seneschal. They're added as one item, "Architecture cleanup", under "Release readiness" in
`BACKLOG.md`, tagged `[decided: direction]`. It's opportunistic: each part is done when a lead
is already working in that code.
- retire the GDScript solver mirrors and the ModeGdscript and ModeVerify scaffolding;
- one definition for the burden and modifier codes and the wire strides;
- fold role checks into RoleRegistry;
- flatten the `extends` chains and `load()` cycles, and fix the layer inversions;
- split the largest files;
- one overlay stack in `ui/main.gd`, and a unified VN and courtroom stage (Herald).

The single source for tuning values is noted as in progress with Argon, not as a backlog item.
The contents list is regenerated.

## What I measured

Nothing; it's docs only.

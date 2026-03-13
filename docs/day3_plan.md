## Day 3 Plan: Snap Movement and Turning Core

Build the authoritative movement core so the player can only do one-cell steps and exact 90-degree turns on a square grid, with action gating to prevent overlap.

## Day 3 Goal

Implement deterministic command execution for:
- `step_forward`
- `step_back`
- `strafe_left`
- `strafe_right`
- `turn_left`
- `turn_right`

All commands must mutate canonical grid state first, then project to transform with zero drift.

## Scope In

- One-cell translation per move command.
- Cardinal facing updates only (N/E/S/W) per turn command.
- Action gating (`is_busy`) so a command cannot overlap an in-progress action.
- Player transform sync from canonical state after each successful command.
- Test coverage for command outcomes and scripted sequence determinism.

## Scope Out

- No smooth tweening interpolation (Day 4).
- No passability/collision blocking logic (Day 6).
- No unified live input pipeline changes (Day 7).
- No camera sync work beyond existing player transform projection (Day 5).

## Deliverables

1. `MovementController` component
- Executes exactly one command at a time.
- Accepts a command enum and mutates `GridState` deterministically.
- Exposes completion signal for sync hooks.

2. Player integration
- Player delegates command execution to movement controller.
- On action completion, player applies canonical transform from grid state.

3. Automated tests (GUT)
- Per-command movement and turning assertions.
- Scripted sequence assertion for final `cell`, `facing`, and world transform.
- Busy-gate assertion (`execute_command` rejected while busy).

## Implementation Notes

Movement rules from facing:
- Forward: facing vector.
- Back: negative facing vector.
- Strafe left: rotate facing left, then use facing vector.
- Strafe right: rotate facing right, then use facing vector.

Turn rules:
- Left: `rotate_left(facing)`.
- Right: `rotate_right(facing)`.

Execution order:
1. Reject if busy.
2. Set busy.
3. Mutate canonical `GridState`.
4. Emit action-completed signal.
5. Clear busy.

## Acceptance Script (Determinism Check)

Start state:
- `cell = (0, 0)`
- `facing = NORTH`

Command sequence:
1. `STEP_FORWARD`
2. `TURN_RIGHT`
3. `STEP_FORWARD`
4. `TURN_LEFT`
5. `STEP_BACK`

Expected final state:
- `cell = (1, 0)`
- `facing = NORTH`
- world projection equals `Vector3(1, 0, 0)` when `cell_size = 1`

## Exit Criteria

- Scripted sequence ends in exact expected `cell` and `facing`.
- No transform drift between canonical state and projected transform.
- Busy-gate test passes with no unintended state mutation.
- Day 2 projection tests continue to pass unchanged.

## Risks and Guardrails

- Risk: accidental diagonal or multi-tile movement.
Guardrail: assert delta is one of the 4 cardinal unit vectors.

- Risk: re-entrant command execution.
Guardrail: gate early on busy and verify via dedicated test.

- Risk: transform/state mismatch after command.
Guardrail: always re-apply canonical transform from `GridState` post-action.

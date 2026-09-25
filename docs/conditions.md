# Persistent world flags and conditions

`state/world_state.lua` remains the single mutable world-fact store. Boolean flags use stable IDs, unset flags read as `false`, `set_flag` accepts only booleans, and `has_flag` distinguishes an unset flag from an explicitly stored `false`. The existing Save Format v5 `flags` table persists these values; reset constructs fresh authored state with every unset flag false.

`conditions/conditions.lua` is a pure read-only evaluator. Supported schemas are:

```lua
{ type = "flag", id = "greyhaven.some_fact", equals = true }
{ all = { condition_a, condition_b } }
{ any = { condition_a, condition_b } }
{ ["not"] = condition_a }
```

Groups must be non-empty, every flag ID and boolean comparison is validated, and a condition must contain exactly one form. Evaluation receives `{ world_state = state }`, reads only through the WorldState flag API, and never mutates its condition, context, or any gameplay system.

Dialogue is the first consumer. Choices may contain a list of conditions, interpreted as all-required. Unavailable choices are hidden and cannot be selected by a stale choice ID or index. Each `get_current` call reevaluates the current WorldState without editing the immutable DialogueDefinition. The separate action executor may set flags only after an explicit choice is selected; condition evaluation itself remains side-effect free.

The architectural boundary is:

- World State stores mutable facts.
- Condition Evaluator asks questions about those facts.
- Dialogue may use conditions to determine available content.
- Actions may mutate facts, but never from condition evaluation.
- Future Actions may change World State.
- QuestState is currently explicit and independent; future quest integration may query conditions or invoke actions through separate authored policies.
- Future AI may query conditions but remains separate.

Only boolean flag conditions exist. Item, inventory, faction, health, Actor, script, and arbitrary Lua conditions remain deferred.

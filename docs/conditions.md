# Persistent world flags and conditions

`state/world_state.lua` remains the single mutable world-fact store. Boolean flags use stable IDs, unset flags read as `false`, `set_flag` accepts only booleans, and `has_flag` distinguishes an unset flag from an explicitly stored `false`. The existing Save Format v5 `flags` table persists these values; reset constructs fresh authored state with every unset flag false.

`conditions/conditions.lua` is a pure read-only evaluator. Supported schemas are:

```lua
{ type = "flag", id = "greyhaven.some_fact", equals = true }
{ type = "quest_status", id = "rat_problem", equals = "active" }
{ type = "quest_objective", quest_id = "rat_problem", objective_id = "investigate", complete = true }
{ all = { condition_a, condition_b } }
{ any = { condition_a, condition_b } }
{ ["not"] = condition_a }
```

Groups must be non-empty and a condition must contain exactly one form. Quest validation receives the immutable QuestDefinition registry explicitly, rejects unknown quests/objectives, and accepts statuses only through `quests.quest_statuses`. Evaluation receives `{ world_state = state, quests = quest_state, quest_registry = definitions }`, reads flags and QuestState only through public APIs, and never mutates its condition, context, or any gameplay system. Flag-only callers remain unchanged.

Dialogue is the first consumer. Choices may contain a list of conditions, interpreted as all-required. Unavailable choices are hidden and cannot be selected by a stale choice ID or index. Each `get_current` call reevaluates current WorldState and QuestState without editing the immutable DialogueDefinition. Dialogue contains no quest-specific branching code and cannot mutate quests.

The architectural boundary is:

- World State stores mutable facts.
- Condition Evaluator asks questions about those facts.
- Dialogue may use conditions to determine available content.
- Actions may mutate facts, but never from condition evaluation.
- Future Actions may change World State.
- QuestState remains explicit; Conditions read it, while future quest actions/event bindings would mutate it through separate authored policies.
- Future AI may query conditions but remains separate.

Only boolean flags, canonical quest-status equality, and objective-complete equality exist. Numeric progress comparisons, item, inventory, faction, health, Actor, script, and arbitrary Lua conditions remain deferred.

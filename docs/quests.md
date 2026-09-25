# Minimal quest state

QuestDefinitions are immutable authored data in `quests/quest_defs.lua`. The validated registry requires a stable quest ID, non-empty title, optional non-empty description, and at least one uniquely identified objective with non-empty description and positive-integer target. Registry reads return copies, so runtime code cannot edit canonical content.

`quests/quests.lua` privately owns mutable state separately from definitions. Canonical statuses come from `quests/quest_statuses.lua`: `not_started`, `active`, and `completed`. A not-started quest has no stored state. Explicit start creates zeroed counters; explicit positive-integer advances clamp at the authored target; and explicit completion succeeds only after every objective reaches its target. Rejected operations never emit events or reset progress.

The service emits `quest_started`, `quest_objective_progressed`, `quest_objective_completed`, and `quest_completed`. Objective- and quest-completed events occur once because further updates are rejected. State changes have no rewards or side effects: they do not mutate flags, items, combat, factions, Actors, dialogue, or the world.

Save Format v5 stores only active/completed status and objective counters. Definitions remain authored data. Restore validates saved quest and objective identities against the registry, progress bounds, and completion consistency. Reset supplies an empty snapshot, returning every quest to `not_started`.

The prototype uses **Y** to start `rat_problem`, **U** to advance `investigate`, and **I** to explicitly complete it. These controls call the same generic quest API and are not discovery, dialogue actions, or AI. Future quest actions may reuse this API, but rewards, item grants, XP, money, markers, automatic discovery, and arbitrary scripts are absent.

The generic Condition evaluator can query canonical quest status and objective completion through public QuestState APIs. Validation depends explicitly on the QuestDefinition registry; evaluation depends explicitly on QuestState. Missing runtime state naturally reports `not_started`, and its objectives report incomplete. These queries never emit quest events or mutate progression. Dialogue only consumes the generic condition result and contains no quest-specific logic.

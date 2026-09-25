# Validated world actions

`actions/world_actions.lua` is the pure-Lua mutation boundary for authored world actions. It supports `set_flag`, `start_quest`, `advance_quest`, and `complete_quest`. Quest actions validate stable quest/objective identities against the immutable QuestDefinition registry; advancement also requires a positive-integer amount. Execution delegates to public QuestState APIs, so Actions do not duplicate start, clamping, objective-completion, or explicit quest-completion rules.

An entire mixed action list and its explicit `{ world_state, quests, quest_registry }` dependencies are validated before the first mutation. Actions then execute in authored order. A runtime-state failure returns its reason, action index, action identity, and prior successful results; execution stops, later actions do not run, and earlier successful actions remain committed. This intentionally avoids a rollback transaction. Each successful action emits one `world_action_executed` event after its underlying mutation events, so a quest start orders `quest_started` before `world_action_executed`.

Dialogue choices may contain an optional non-empty `actions` list. On selection, Dialogue invokes only the generic executor, applies the next/close transition after success, and remains on the current node after failure. Actions are never run merely by viewing or entering a node.

The test villager now demonstrates the complete authored loop: a `not_started` offer executes `start_quest`, an active report executes `advance_quest`, and an objective-complete response executes `complete_quest`. Conditions expose each next choice immediately. No villager-specific runtime branch exists.

WorldState and QuestState store facts; Conditions read them; Actions explicitly mutate them; Dialogue orchestrates authored Conditions plus Actions. Combat remains unrelated. Save Format v5 persists resulting flags and quest state only—never action history—and reset reconstructs false flags and `not_started` quests. Rewards, items, XP, money, automatic progression, arbitrary callbacks, AI, and conditional scripts remain absent.

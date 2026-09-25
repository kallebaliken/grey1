# Validated world actions

`actions/world_actions.lua` is the pure-Lua mutation boundary for authored world actions. The only supported action is `{ type = "set_flag", id = <stable ID>, value = <boolean> }`. Unknown types, unstable IDs, non-boolean values, and extra fields are rejected. An entire action list and its WorldState context are validated before the first mutation, then actions execute in authored order. Each successful mutation emits one optional `world_action_executed` event with its previous and resulting values.

Dialogue choices may contain an optional non-empty `actions` list. On selection, dialogue verifies the currently available choice, executes its actions, applies the next/close transition, and then emits dialogue lifecycle events. An unexpected action failure leaves the session on its current node and reports `action_failed`. Actions are never run by viewing or entering a node.

The test-villager's ordinary “What is this place?” response sets `greyhaven.met_test_villager`. A conditioned follow-up is consequently visible from the next node. The authored DialogueDefinition remains immutable, while every current-node snapshot reevaluates conditions from WorldState.

WorldState stores facts, Conditions read facts, Actions mutate facts, and Dialogue chooses where authored conditions/actions apply. Future quests may reuse those boundaries; item rewards, quest actions, arbitrary callbacks, AI, and conditional scripts remain deliberately absent.

Only resulting flag state is persistent. Action history and active dialogue sessions are not saved. Save Format v4 already stores WorldState flags, and reset creates fresh state where unset flags—including `greyhaven.met_test_villager`—read as false.

# Event action bindings

Event bindings are immutable authored rules that translate a whitelisted gameplay fact into existing generic Actions. The initial registry accepts only `actor_died`; for that event, `actor_id` means the Actor that died. A rule may match that Actor's stable ID, canonical Actor type, and/or associated CreatureDefinition ID.

Matching rules execute in stable binding-ID order, and each rule's actions execute in authored order through `actions/world_actions.lua`. Definitions and action lists are validated before runtime. A state-dependent Action failure stops that binding's remaining actions and is returned as structured diagnostic data; earlier mutations remain committed and the source event is never rolled back.

Only `actor_died` is subscribable in this phase. Action and quest lifecycle events cannot recursively trigger bindings. Binding definitions and execution history are not saved; only resulting WorldState and QuestState are persisted by Save Format v5.

The initial `rat_problem.rat_died` rule matches `actor_definition = "rat"` and advances `rat_problem/investigate`. Combat emits the death fact and knows nothing about quests; QuestState receives a normal generic Action and knows nothing about combat. If the quest is inactive or complete, the action fails cleanly and the rat remains dead.

The boundary is deliberate: gameplay systems emit facts, Event Bindings match authored rules, Actions mutate persistent state, and Conditions remain read-only. Loot, rewards, respawning, new objective types, arbitrary scripts, and AI are outside this subsystem.

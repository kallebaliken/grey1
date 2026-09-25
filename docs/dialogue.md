# Explicit NPC dialogue

`dialogue/dialogue_defs.lua` contains immutable authored conversation graphs. Each definition has a stable ID, a valid start node, non-empty node text, and unique explicit choices. A choice does exactly one thing: transition to another validated node or close the conversation. The registry copies definitions on input/output and rejects missing nodes, duplicate node/choice IDs, empty text, and ambiguous choice behavior.

`dialogue/dialogue.lua` owns one active player conversation outside Actor state. A session records stable player/NPC Actor IDs, dialogue ID, and current node. Beginning a new valid conversation closes and replaces the old session. Definitions never mutate. Choices may read validated boolean world-flag conditions; failing choices are hidden and cannot be selected. Choices still have no scripts, actions, item transfers, flag writes, health changes, movement, faction changes, or reputation effects.

Creature definitions optionally reference a validated dialogue ID. `test_villager` uses `test_villager`; the rat has no dialogue. The speaker name comes from the creature definition display name. The normal interaction system targets the adjacent facing Actor, and its registered generic Actor handler explicitly begins dialogue. NPCs never initiate sessions.

While a session is active, the Defold adapter consumes movement, attack, interaction, save, and development inputs. Number keys **1–4** select visible choices and **Escape** closes the session. A committed visual movement may finish, and the rest of the world is not paused. The panel is temporary HUD GUI rather than world rendering.

The architecture boundary is:

- Creature Definition identifies who the NPC is.
- Faction describes authored relationships.
- Dialogue Definition describes what may be said.
- Dialogue Session tracks the current explicit conversation.
- Conditions decide which choices are available by reading WorldState.
- Future Actions may perform quests, items, or reputation changes.

Conditions are read-only and faction data does not alter dialogue. Active sessions are temporary runtime state and are never saved; loading starts with no conversation.

Canary NPC interaction is only a conceptual reference. Greyhaven does not port Tibia NPC scripts, keyword handlers, shops, travel, quests, storage values, callbacks, or scheduling.

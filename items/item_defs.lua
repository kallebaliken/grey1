-- Original Greyhaven content. These records describe item types, not owned items.
return {
    healing_herb = {
        id = "healing_herb",
        name = "Healing Herb",
        stackable = true,
        max_stack = 20,
        weight = 0.1,
        tags = { "consumable", "herb" },
        pickupable = true,
        stack_layer = "bottom",
        interaction = "pickup",
        patterns = { { { 0.25, 0.72, 0.28, 1 } } },
    },
    old_iron_key = {
        id = "old_iron_key",
        name = "Old Iron Key",
        stackable = false,
        weight = 0.2,
        tags = { "key" },
        pickupable = true,
        stack_layer = "bottom",
        interaction = "pickup",
        patterns = { { { 0.88, 0.72, 0.20, 1 } } },
    },
}

return {
    test_villager = {
        id = "test_villager",
        actor_type = "npc",
        display_name = "Test Villager",
        render = { color = { 0.78, 0.48, 0.24, 1 }, size = 22 },
    },
    rat = {
        id = "rat",
        actor_type = "monster",
        display_name = "Rat",
        combat = { max_health = 20 },
        attack = { damage = 2, range = 1, cooldown = 1 },
        render = { color = { 0.72, 0.20, 0.24, 1 }, size = 22 },
    },
}

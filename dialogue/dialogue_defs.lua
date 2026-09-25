return {
    test_villager = {
        id = "test_villager",
        start = "greeting",
        nodes = {
            { id = "greeting", text = "Morning, traveler.", choices = {
                { id = "ask_place", text = "What is this place?", next = "about_place", actions = {
                    { type = "set_flag", id = "greyhaven.met_test_villager", value = true },
                } },
                { id = "ask_rat", text = "What is going on with the rats?", next = "rat_problem",
                    conditions = { { type = "flag", id = "greyhaven.test_dialogue_flag", equals = true } } },
                { id = "leave", text = "Goodbye.", close = true },
            } },
            { id = "rat_problem", text = "They have been bold near the old stones lately.", choices = {
                { id = "back", text = "I see.", next = "greeting" },
                { id = "leave", text = "Goodbye.", close = true },
            } },
            { id = "about_place", text = "Greyhaven. Quiet enough, most days.", choices = {
                { id = "back", text = "I see.", next = "greeting" },
                { id = "met_before", text = "I am glad we spoke.", next = "greeting",
                    conditions = { { type = "flag", id = "greyhaven.met_test_villager", equals = true } } },
                { id = "leave", text = "Goodbye.", close = true, actions = {
                    { type = "set_flag", id = "greyhaven.met_test_villager", value = true },
                } },
            } },
        },
    },
}

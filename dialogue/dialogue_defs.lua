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
                { id = "offer_rat_problem", text = "Do you need a hand?", next = "quest_offer",
                    conditions = { { type = "quest_status", id = "rat_problem", equals = "not_started" } } },
                { id = "active_rat_problem", text = "About that rat problem...", next = "quest_active",
                    conditions = { { type = "quest_status", id = "rat_problem", equals = "active" } } },
                { id = "completed_rat_problem", text = "The rat trouble is settled.", next = "quest_completed",
                    conditions = { { type = "quest_status", id = "rat_problem", equals = "completed" } } },
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
            { id = "quest_offer", text = "Take a look near the old stones and tell me what you find.", choices = {
                { id = "accept_rat_problem", text = "I can help.", next = "greeting", actions = {
                    { type = "start_quest", id = "rat_problem" },
                } },
                { id = "back", text = "Not just yet.", next = "greeting" },
                { id = "leave", text = "Goodbye.", close = true },
            } },
            { id = "quest_active", text = "Keep your eyes open near the old stones.", choices = {
                { id = "finish_rat_problem", text = "That should be enough.", next = "greeting", conditions = {
                    { type = "quest_objective", quest_id = "rat_problem",
                        objective_id = "investigate", complete = true },
                }, actions = {
                    { type = "complete_quest", id = "rat_problem" },
                } },
                { id = "back", text = "I will look around.", next = "greeting" },
                { id = "leave", text = "Goodbye.", close = true },
            } },
            { id = "quest_completed", text = "Then Greyhaven owes you a quiet morning.", choices = {
                { id = "back", text = "Glad to help.", next = "greeting" },
                { id = "leave", text = "Goodbye.", close = true },
            } },
        },
    },
}

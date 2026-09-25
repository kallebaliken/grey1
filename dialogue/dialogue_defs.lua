return {
    test_villager = {
        id = "test_villager",
        start = "greeting",
        nodes = {
            { id = "greeting", text = "Morning, traveler.", choices = {
                { id = "ask_place", text = "What is this place?", next = "about_place" },
                { id = "leave", text = "Goodbye.", close = true },
            } },
            { id = "about_place", text = "Greyhaven. Quiet enough, most days.", choices = {
                { id = "back", text = "I see.", next = "greeting" },
                { id = "leave", text = "Goodbye.", close = true },
            } },
        },
    },
}

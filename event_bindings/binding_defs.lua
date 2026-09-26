return {
    ["rat_problem.rat_died"] = {
        id = "rat_problem.rat_died",
        event = "actor_died",
        match = { actor_definition = "rat" },
        actions = {
            { type = "advance_quest", id = "rat_problem", objective_id = "investigate", amount = 1 },
        },
    },
}

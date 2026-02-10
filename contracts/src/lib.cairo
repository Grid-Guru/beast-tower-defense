pub mod models {
    pub mod beast;
    pub mod grid;
    pub mod match_state;
    pub mod admin;
    pub mod simulation;
}

pub mod systems {
    pub mod simulation;
    pub mod match_actions;
    pub mod squad;
    pub mod admin;
}

pub mod utils {
    pub mod rng;
    pub mod math;
    pub mod constants;
}

pub mod events;

#[cfg(test)]
pub mod tests {
    mod test_rng;
    mod test_type_chart;
    mod test_tower_tiers;
    mod test_monster_tiers;
    mod test_simulation;
    mod test_match;
    mod test_squad;
    mod test_admin;
}

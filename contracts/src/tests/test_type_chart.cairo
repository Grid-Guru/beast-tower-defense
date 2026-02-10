// =============================================================================
// Type Chart & Math Tests — All 9 Type Combinations + Math Utilities
// =============================================================================

use beast_td::utils::math;

// =============================================================================
// Type Multiplier Tests (3x3 grid: Hunter/Magic/Brute)
// =============================================================================

#[test]
fn test_type_same_hunter() {
    let (num, den) = math::get_type_multiplier(1, 1);
    assert!(num == 1 && den == 1, "Hunter vs Hunter should be 1.0x");
}

#[test]
fn test_type_same_magic() {
    let (num, den) = math::get_type_multiplier(2, 2);
    assert!(num == 1 && den == 1, "Magic vs Magic should be 1.0x");
}

#[test]
fn test_type_same_brute() {
    let (num, den) = math::get_type_multiplier(3, 3);
    assert!(num == 1 && den == 1, "Brute vs Brute should be 1.0x");
}

#[test]
fn test_type_hunter_beats_magic() {
    let (num, den) = math::get_type_multiplier(1, 2);
    assert!(num == 3 && den == 2, "Hunter > Magic should be 1.5x (3/2)");
}

#[test]
fn test_type_hunter_loses_to_brute() {
    let (num, den) = math::get_type_multiplier(1, 3);
    assert!(num == 1 && den == 2, "Hunter < Brute should be 0.5x (1/2)");
}

#[test]
fn test_type_magic_beats_brute() {
    let (num, den) = math::get_type_multiplier(2, 3);
    assert!(num == 3 && den == 2, "Magic > Brute should be 1.5x (3/2)");
}

#[test]
fn test_type_magic_loses_to_hunter() {
    let (num, den) = math::get_type_multiplier(2, 1);
    assert!(num == 1 && den == 2, "Magic < Hunter should be 0.5x (1/2)");
}

#[test]
fn test_type_brute_beats_hunter() {
    let (num, den) = math::get_type_multiplier(3, 1);
    assert!(num == 3 && den == 2, "Brute > Hunter should be 1.5x (3/2)");
}

#[test]
fn test_type_brute_loses_to_magic() {
    let (num, den) = math::get_type_multiplier(3, 2);
    assert!(num == 1 && den == 2, "Brute < Magic should be 0.5x (1/2)");
}

// =============================================================================
// ceil_div Edge Cases
// =============================================================================

#[test]
fn test_ceil_div_exact() {
    assert!(math::ceil_div(10, 5) == 2, "10/5 = 2 (exact)");
    assert!(math::ceil_div(9, 3) == 3, "9/3 = 3 (exact)");
}

#[test]
fn test_ceil_div_round_up() {
    assert!(math::ceil_div(10, 3) == 4, "ceil(10/3) = 4");
    assert!(math::ceil_div(7, 2) == 4, "ceil(7/2) = 4");
    assert!(math::ceil_div(1, 2) == 1, "ceil(1/2) = 1");
}

#[test]
fn test_ceil_div_zero_numerator() {
    assert!(math::ceil_div(0, 5) == 0, "0/5 = 0");
}

#[test]
fn test_ceil_div_one_denominator() {
    assert!(math::ceil_div(42, 1) == 42, "42/1 = 42");
}

// =============================================================================
// apply_multiplier Tests
// =============================================================================

#[test]
fn test_apply_multiplier_1x() {
    let result = math::apply_multiplier(100, 1, 1);
    assert!(result == 100, "100 * 1/1 = 100");
}

#[test]
fn test_apply_multiplier_1_5x() {
    let result = math::apply_multiplier(100, 3, 2);
    assert!(result == 150, "100 * 3/2 = 150");
}

#[test]
fn test_apply_multiplier_0_5x() {
    let result = math::apply_multiplier(100, 1, 2);
    assert!(result == 50, "100 * 1/2 = 50");
}

#[test]
fn test_apply_multiplier_rounds_up() {
    let result = math::apply_multiplier(7, 3, 2);
    assert!(result == 11, "ceil(7 * 3/2) = ceil(10.5) = 11");
}

#[test]
fn test_apply_multiplier_zero_denominator() {
    let result = math::apply_multiplier(100, 3, 0);
    assert!(result == 100, "Division by zero should return original value");
}

// =============================================================================
// within_manhattan Tests
// =============================================================================

#[test]
fn test_within_manhattan_same_tile() {
    assert!(math::within_manhattan(5, 5, 5, 5, 0) == true, "Same tile is within range 0");
}

#[test]
fn test_within_manhattan_adjacent() {
    assert!(math::within_manhattan(5, 5, 6, 5, 1) == true, "Adjacent horizontal within range 1");
    assert!(math::within_manhattan(5, 5, 5, 6, 1) == true, "Adjacent vertical within range 1");
}

#[test]
fn test_within_manhattan_diagonal() {
    // (5,5) -> (6,6): dx=1, dy=1, Manhattan=2
    assert!(math::within_manhattan(5, 5, 6, 6, 2) == true, "Diagonal within range 2");
    assert!(math::within_manhattan(5, 5, 6, 6, 1) == false, "Diagonal NOT within range 1");
}

#[test]
fn test_within_manhattan_out_of_range() {
    assert!(math::within_manhattan(0, 0, 5, 5, 9) == false, "(0,0) to (5,5) NOT within range 9");
    assert!(math::within_manhattan(0, 0, 5, 5, 10) == true, "(0,0) to (5,5) within range 10");
}

#[test]
fn test_within_manhattan_reversed_coords() {
    // Order shouldn't matter: (10,10) -> (5,5) == (5,5) -> (10,10)
    assert!(
        math::within_manhattan(10, 10, 5, 5, 10) == math::within_manhattan(5, 5, 10, 10, 10),
        "Distance should be symmetric"
    );
}

#[test]
fn test_within_manhattan_large_range() {
    assert!(math::within_manhattan(0, 0, 255, 255, 255) == false, "Max coords NOT within range 255");
}

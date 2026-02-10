// =============================================================================
// Math Utilities
// =============================================================================

/// Ceiling division: ceil(a / b) = (a + b - 1) / b
/// Equivalent to JS Math.ceil(a / b) for positive integers.
pub fn ceil_div(a: u32, b: u32) -> u32 {
    if a == 0 {
        return 0;
    }
    (a + b - 1) / b
}

/// Get type multiplier as (numerator, denominator) pair.
/// Type triangle: Hunter > Magic > Brute > Hunter
/// Advantage: 3/2 (1.5x), Disadvantage: 1/2 (0.5x), Neutral: 1/1 (1.0x)
///
/// beast_type values: 1=Hunter, 2=Magic, 3=Brute
pub fn get_type_multiplier(attacker_type: u8, defender_type: u8) -> (u32, u32) {
    if attacker_type == defender_type {
        return (1, 1); // neutral
    }

    // Hunter(1) > Magic(2): 1.5x
    if attacker_type == 1 && defender_type == 2 {
        return (3, 2);
    }
    // Hunter(1) < Brute(3): 0.5x
    if attacker_type == 1 && defender_type == 3 {
        return (1, 2);
    }
    // Magic(2) > Brute(3): 1.5x
    if attacker_type == 2 && defender_type == 3 {
        return (3, 2);
    }
    // Magic(2) < Hunter(1): 0.5x
    if attacker_type == 2 && defender_type == 1 {
        return (1, 2);
    }
    // Brute(3) > Hunter(1): 1.5x
    if attacker_type == 3 && defender_type == 1 {
        return (3, 2);
    }
    // Brute(3) < Magic(2): 0.5x
    if attacker_type == 3 && defender_type == 2 {
        return (1, 2);
    }

    // fallback (should not happen with valid types)
    (1, 1)
}

/// Apply a fractional multiplier with ceiling: ceil(value * num / den)
pub fn apply_multiplier(value: u32, num: u32, den: u32) -> u32 {
    if den == 0 {
        return value;
    }
    ceil_div(value * num, den)
}

/// Check if two points are within Manhattan distance.
/// Manhattan distance = |x1 - x2| + |y1 - y2|
pub fn within_manhattan(x1: u8, y1: u8, x2: u8, y2: u8, range: u8) -> bool {
    let dx: u16 = if x1 >= x2 {
        (x1 - x2).into()
    } else {
        (x2 - x1).into()
    };
    let dy: u16 = if y1 >= y2 {
        (y1 - y2).into()
    } else {
        (y2 - y1).into()
    };
    (dx + dy) <= range.into()
}

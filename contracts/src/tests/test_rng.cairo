// =============================================================================
// PRNG Tests — Determinism and Range Validation
// =============================================================================

use beast_td::utils::rng;

#[test]
fn test_rng_next_deterministic() {
    let mut state: u32 = 12345;

    // First call should produce deterministic output matching JS Mulberry32
    let r1 = rng::rng_next(ref state);
    assert!(r1 == 4207900869, "First rng_next(12345) should match JS reference");

    // Second call
    let r2 = rng::rng_next(ref state);
    assert!(r2 == 1317490944, "Second rng_next should match JS reference");

    // Third call
    let r3 = rng::rng_next(ref state);
    assert!(r3 == 2079646450, "Third rng_next should match JS reference");
}

#[test]
fn test_rng_next_seed_zero() {
    let mut state: u32 = 0;
    let r1 = rng::rng_next(ref state);

    // Verify state advanced
    assert!(state == 0x6D2B79F5, "State should advance by MULBERRY32_INCREMENT");
    // Verify output is non-zero
    assert!(r1 != 0, "Output from seed 0 should be non-zero");
}

#[test]
fn test_rng_int_range() {
    let mut state: u32 = 12345;

    // Test max=10: should return [0,9]
    let val = rng::rng_int(ref state, 10);
    assert!(val < 10, "rng_int(10) should be < 10");

    // Test max=1: should return 0
    let mut state2: u32 = 99999;
    let val2 = rng::rng_int(ref state2, 1);
    assert!(val2 == 0, "rng_int(1) should be 0");
}

#[test]
fn test_rng_int_zero_max() {
    let mut state: u32 = 12345;
    let val = rng::rng_int(ref state, 0);
    assert!(val == 0, "rng_int(0) should return 0");
}

#[test]
fn test_rng_int_distribution() {
    let mut state: u32 = 54321;

    // Generate 100 values in [0,5) and verify all are valid
    let mut i: u32 = 0;
    while i < 100 {
        let val = rng::rng_int(ref state, 5);
        assert!(val < 5, "All values should be < 5");
        i += 1;
    };
}

#[test]
fn test_rng_chance_always_succeeds() {
    let mut state: u32 = 12345;
    let result = rng::rng_chance(ref state, 100);
    assert!(result == true, "100% chance should always succeed");
}

#[test]
fn test_rng_chance_never_succeeds() {
    let mut state: u32 = 12345;
    let result = rng::rng_chance(ref state, 0);
    assert!(result == false, "0% chance should never succeed");
}

#[test]
fn test_rng_shuffle_empty() {
    let mut state: u32 = 12345;
    let input: Array<u8> = array![];
    let result = rng::rng_shuffle(ref state, input.span());
    assert!(result.len() == 0, "Shuffling empty array should return empty");
}

#[test]
fn test_rng_shuffle_single() {
    let mut state: u32 = 12345;
    let input: Array<u8> = array![42];
    let result = rng::rng_shuffle(ref state, input.span());
    assert!(result.len() == 1, "Shuffling single element should preserve length");
    assert!(*result.at(0) == 42, "Single element should be unchanged");
}

#[test]
fn test_rng_shuffle_preserves_length() {
    let mut state: u32 = 12345;
    let input: Array<u8> = array![1, 2, 3, 4, 5];
    let result = rng::rng_shuffle(ref state, input.span());
    assert!(result.len() == 5, "Shuffle should preserve length");
}

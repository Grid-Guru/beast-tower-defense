// =============================================================================
// Mulberry32 Seeded PRNG — Port from SimulationEngine.js
// =============================================================================
// JS Reference (lines 38-45):
//   state = (state + 0x6D2B79F5) | 0;
//   let t = Math.imul(state ^ (state >>> 15), 1 | state);
//   t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
//   return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
//
// Cairo: returns raw u32 value (no division). Use rng_int/rng_chance for ranges.
// =============================================================================

use core::num::traits::{WrappingAdd, WrappingMul};

const MULBERRY32_INCREMENT: u32 = 0x6D2B79F5;

/// Advance the PRNG state and return the raw u32 output.
/// This produces the same bit pattern as JS Mulberry32 before the /4294967296 division.
pub fn rng_next(ref state: u32) -> u32 {
    // state = (state + 0x6D2B79F5) | 0
    state = state.wrapping_add(MULBERRY32_INCREMENT);

    // let t = Math.imul(state ^ (state >>> 15), 1 | state)
    let s = state;
    let xor1 = s ^ (s / 0x8000_u32); // >>> 15
    let or1 = 1_u32 | s;
    let mut t: u32 = xor1.wrapping_mul(or1);

    // t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t
    let xor2 = t ^ (t / 0x80_u32); // >>> 7
    let or2 = 61_u32 | t;
    let mul2: u32 = xor2.wrapping_mul(or2);
    t = t.wrapping_add(mul2) ^ t;

    // return (t ^ (t >>> 14)) >>> 0
    t ^ (t / 0x4000_u32) // >>> 14
}

/// Get a random integer in [0, max).
/// Equivalent to JS: Math.floor(rng() * max)
/// Since rng() = raw / 2^32, floor(raw/2^32 * max) = floor(raw * max / 2^32)
pub fn rng_int(ref state: u32, max: u32) -> u32 {
    if max == 0 {
        return 0;
    }
    let raw: u32 = rng_next(ref state);
    // Use u64 to avoid overflow: (raw * max) / 2^32
    let product: u64 = raw.into() * max.into();
    (product / 0x100000000_u64).try_into().unwrap()
}

/// Check if a random roll is below a percentage threshold.
/// Equivalent to JS: rng() < (pct / 100)
/// Since rng() = raw / 2^32, this is: raw / 2^32 < pct / 100
/// Rearranged to avoid floating point: raw * 100 < pct * 2^32
pub fn rng_chance(ref state: u32, pct: u8) -> bool {
    let raw: u32 = rng_next(ref state);
    let lhs: u64 = raw.into() * 100;
    let rhs: u64 = pct.into() * 0x100000000;
    lhs < rhs
}

/// Fisher-Yates shuffle of a Span, returning a new Array.
pub fn rng_shuffle(ref state: u32, arr: Span<u8>) -> Array<u8> {
    let len = arr.len();
    if len <= 1 {
        let mut result: Array<u8> = array![];
        let mut i: u32 = 0;
        while i < len {
            result.append(*arr.at(i));
            i += 1;
        };
        return result;
    }

    // Copy to mutable array
    let mut a: Array<u8> = array![];
    let mut i: u32 = 0;
    while i < len {
        a.append(*arr.at(i));
        i += 1;
    };

    // Fisher-Yates: iterate from end to 1
    let mut idx: u32 = len - 1;
    while idx > 0 {
        let j = rng_int(ref state, idx + 1);
        // Swap a[idx] and a[j] by rebuilding
        if idx != j {
            let tmp_i = *a.at(idx);
            let tmp_j = *a.at(j);
            // Rebuild array with swapped values
            let mut new_a: Array<u8> = array![];
            let mut k: u32 = 0;
            while k < len {
                if k == idx {
                    new_a.append(tmp_j);
                } else if k == j {
                    new_a.append(tmp_i);
                } else {
                    new_a.append(*a.at(k));
                }
                k += 1;
            };
            a = new_a;
        }
        idx -= 1;
    };
    a
}

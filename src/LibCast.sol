// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title LibCast
/// @notice Additional type casting logic that the Solidity compiler doesn't
/// give us by default. A type cast (vs. conversion) is considered one where the
/// structure is unchanged by the cast. The cast does NOT (can't) check that the
/// input is a valid output, for example any integer MAY be cast to a function
/// pointer but almost all integers are NOT valid function pointers. It is the
/// calling context that MUST ensure the validity of the data, the cast will
/// merely retype the data in place, generally without additional checks.
/// As most structures in solidity have the same memory structure as a `uint256`
/// or fixed/dynamic array of `uint256` there are many conversions that can be
/// done with near zero or minimal overhead.
///
/// Casting TO a type narrower than a 32 byte word gives that contract a
/// consequence worth stating outright. Solidity's memory convention is that a
/// value narrower than a word is held zero extended, so the compiler is
/// entitled to assume the unused high bits of an `address` in memory are clear.
/// A cast performs no writes, so it cannot establish that invariant: retyping a
/// word whose high bits are set produces a value that is well typed to the
/// compiler while holding a memory word the convention says cannot exist. That
/// is intended - writing would make it a conversion, not a cast - but it is the
/// caller's job to know it. `asAddressesArray` is the only cast here that
/// narrows, and its NatSpec names exactly which consumers can observe the
/// difference. The `bytes32` casts are word for word and have nothing to
/// observe.
library LibCast {
    /// Retype an array of `uint256[]` to `address[]`.
    ///
    /// `address` is 20 bytes, so every input word `>= 2 ** 160` yields an
    /// element that keeps its upper 96 bits. Nothing masks them, by design: a
    /// cast writes nothing, and masking in place would corrupt the caller's
    /// `uint256[]`, which is the same buffer. The caller MUST ensure every word
    /// fits in 160 bits if the result is to be a conventional `address[]`.
    ///
    /// Those bits are contained everywhere the compiler generates the read.
    /// Comparison, `abi.encode`, `abi.encodePacked`, hashing encoded data,
    /// assignment into storage, use as a `mapping` key, element assignment into
    /// a conventional `address[]` and passing the array over an external ABI
    /// boundary all clean to 160 bits, so a dirty element cannot corrupt state,
    /// cannot desync `==` from a hash, and cannot revert at an ABI boundary.
    /// Assembly is where it escapes: an `mload` of an element reads all 256
    /// bits on every pipeline. Reading the elements of an `address[] memory`
    /// with assembly is the normal idiom in these libraries, and such a reader
    /// is entitled to assume the zero extension convention, so it will silently
    /// see a word it cannot represent.
    ///
    /// Whether a plain `addresses[i]` read into a stack slot is cleaned is
    /// pipeline dependent and MUST NOT be relied on in either direction. The
    /// legacy pipeline, which is what this repo compiles with, leaves the slot
    /// dirty; via-IR cleans it on the way out of memory. That can flip under a
    /// compiler or pipeline change with no change to this library, so treat the
    /// cleanliness of such a value as unspecified.
    ///
    /// @param us The array of integers to cast to addresses.
    /// @return addresses The array of addresses cast from each integer.
    function asAddressesArray(uint256[] memory us) internal pure returns (address[] memory addresses) {
        assembly ("memory-safe") {
            addresses := us
        }
    }

    /// Retype an array of `address[]` to `uint256[]`.
    ///
    /// Widening, so nothing truncates, but the output words are whatever the
    /// input buffer already holds and nothing more. A conventional `address[]`
    /// yields words `< 2 ** 160`; an `address[]` that came from
    /// `asAddressesArray` over words `>= 2 ** 160` yields those original 256
    /// bit words back, which is what makes the round trip an identity rather
    /// than a truncation.
    ///
    /// @param addresses The array of addresses to cast to integers.
    /// @return us The array of integers cast from each address.
    function asUint256Array(address[] memory addresses) internal pure returns (uint256[] memory us) {
        assembly ("memory-safe") {
            us := addresses
        }
    }

    /// Retype an array of `uint256[]` to `bytes32[]`.
    /// @param us The array of integers to cast to 32 byte words.
    /// @return b32s The array of 32 byte words.
    function asBytes32Array(uint256[] memory us) internal pure returns (bytes32[] memory b32s) {
        assembly ("memory-safe") {
            b32s := us
        }
    }

    /// Retype an array of `bytes32[]` to `uint256[]`.
    /// @param b32s The array of 32 byte words to cast to integers.
    /// @return us The array of integers.
    function asUint256Array(bytes32[] memory b32s) internal pure returns (uint256[] memory us) {
        assembly ("memory-safe") {
            us := b32s
        }
    }
}

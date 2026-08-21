// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity ^0.8.25;

/// @title LibConvert
/// @notice Type conversions that require additional structural changes to
/// complete safely. These are NOT mere type casts and involve additional
/// reads and writes to complete, such as recalculating the length of an array.
/// The convention "toX" is adopted from Rust, where `to_` marks a conversion
/// that costs more than a cast. It marks the cost only. It says nothing about
/// the fate of the source, because in Rust the marker for consuming the source
/// is `into_` rather than `to_`, and this library has no equivalent marker.
///
/// Whether a conversion consumes its source, and what the `unsafe` prefix
/// refers to, are therefore per-function properties. Both are stated on the
/// function itself and neither can be read off the name. Neither generalises
/// from one function in this library to another, so a caller MUST read the
/// NatSpec of the specific function it is calling.
library LibConvert {
    /// Convert an array of integers to `bytes` data. This requires modifying
    /// the length in situ as the integer array length is measured in 32 byte
    /// increments while the length of `bytes` is the literal number of bytes.
    ///
    /// It is unsafe for the caller to use `us` after it has been converted to
    /// bytes because there is now two pointers to the same mutable data
    /// structure AND the length prefix for the `uint256[]` version is corrupt.
    ///
    /// @param us The integer array to convert to `bytes`.
    /// @return bs The integer array converted to `bytes` data.
    function unsafeToBytes(uint256[] memory us) internal pure returns (bytes memory bs) {
        assembly ("memory-safe") {
            bs := us
            // Length in bytes is 32x the length in uint256
            mstore(bs, mul(0x20, mload(bs)))
        }
    }

    /// Truncate `uint256[]` values down to `uint16[]` then pack this to `bytes`
    /// without padding or length prefix. Unsafe because the starting `uint256`
    /// values are not checked for overflow due to the truncation. The caller
    /// MUST ensure that all values fit in `type(uint16).max` or that silent
    /// overflow is safe.
    ///
    /// The values are the caller's only obligation; the length is this
    /// library's. `us.length` is doubled with a checked multiply, so a length
    /// prefix that cannot be doubled without wrapping reverts, rather than
    /// packing the wrapped count of elements and handing back a well formed
    /// result of the wrong length. Solidity cannot build an array long enough
    /// to reach that, but this library is used from assembly that builds memory
    /// arrays by hand, and a forged or corrupt length prefix is an error rather
    /// than a shorter array.
    ///
    /// The truncation is the only unsafety. This does NOT consume `us`. The
    /// result is a freshly allocated buffer and `us` is only read, so `us` is
    /// still a valid `uint256[]` after the call and the caller may keep using
    /// it. That does NOT carry over to `unsafeToBytes`, which hands back the
    /// source buffer itself with a rewritten length prefix, and so must not be
    /// given a `us` that the caller still needs.
    /// @param us The `uint256[]` to truncate and concatenate to 16 bit `bytes`.
    /// @return The concatenated 2-byte chunks.
    function unsafeTo16BitBytes(uint256[] memory us) internal pure returns (bytes memory) {
        // Deliberately NOT `unchecked`. The allocation size is the only
        // arithmetic in this function, and wrapping it would silently pack a
        // different count of elements than `us` claims, which the docs above
        // rule out.
        // We will keep 2 bytes (16 bits) from each integer.
        bytes memory bs = new bytes(us.length * 2);
        assembly ("memory-safe") {
            let replaceMask := 0xFFFF
            let preserveMask := not(replaceMask)
            for {
                let cursor := add(us, 0x20)
                // Yul `mul` wraps, but `mload(us)` cannot reach a length that
                // makes it wrap. The allocation above already reverted for any
                // length at or above 2**63, and this wraps only at 2**251.
                let end := add(cursor, mul(mload(us), 0x20))
                let bytesCursor := add(bs, 0x02)
            } lt(cursor, end) {
                cursor := add(cursor, 0x20)
                bytesCursor := add(bytesCursor, 0x02)
            } {
                let data := mload(bytesCursor)
                mstore(bytesCursor, or(and(preserveMask, data), and(replaceMask, mload(cursor))))
            }
        }
        return bs;
    }
}

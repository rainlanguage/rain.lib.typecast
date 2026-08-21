// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test, stdError} from "forge-std-1.16.1/src/Test.sol";
import {LibConvert} from "../src/LibConvert.sol";
import {LibConvertSlow} from "./LibConvertSlow.sol";

contract LibConvertTest is Test {
    function testUnsafeToBytesReferenceImplementation(uint256[] memory us) public pure {
        assertEq(
            // Note the order of these calls is important because the unsafe call
            // is unsafe, i.e. the `us` can no longer be used.
            LibConvertSlow.toBytesSlow(us),
            LibConvert.unsafeToBytes(us)
        );
    }

    function testUnsafeTo16BitBytesReferenceImplementation(uint256[] memory us) public pure {
        assertEq(
            // Note the order of these calls is important because the unsafe call
            // is unsafe, i.e. the `us` can no longer be used.
            LibConvertSlow.to16BitBytesSlow(us),
            LibConvert.unsafeTo16BitBytes(us)
        );
    }

    /// The conversion hands back the buffer it was given rather than a copy of
    /// it, and rewrites the shared length prefix from a count of words to a
    /// count of bytes. Both halves of that are what make the source unsafe to
    /// use afterwards, so both are pinned here.
    function testUnsafeToBytesAliasesTheSourceAndRewritesItsLengthPrefix(uint256[] memory us) public pure {
        uint256 sourcePointer;
        assembly ("memory-safe") {
            sourcePointer := us
        }
        uint256 wordLength = us.length;

        bytes memory bs = LibConvert.unsafeToBytes(us);

        uint256 bytesPointer;
        assembly ("memory-safe") {
            bytesPointer := bs
        }

        assertEq(bytesPointer, sourcePointer);
        assertEq(bs.length, wordLength * 32);

        uint256 prefix;
        assembly ("memory-safe") {
            prefix := mload(sourcePointer)
        }
        assertEq(prefix, wordLength * 32);
    }

    /// The 16 bit packing allocates its own result, so unlike `unsafeToBytes` it
    /// reads the source and leaves it intact.
    function testUnsafeTo16BitBytesLeavesTheSourceIntact(uint256[] memory us) public pure {
        uint256[] memory expected = new uint256[](us.length);
        for (uint256 i = 0; i < us.length; i++) {
            expected[i] = us[i];
        }

        bytes memory bs = LibConvert.unsafeTo16BitBytes(us);
        assertEq(bs.length, expected.length * 2);

        assertEq(us.length, expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(us[i], expected[i]);
        }
    }

    /// The NatSpec puts an obligation on the caller about the values and none
    /// about the length, so a length prefix that cannot be doubled without
    /// wrapping has to revert rather than pack the wrapped count of elements and
    /// hand back a well formed result of the wrong length.
    function testUnsafeTo16BitBytesForgedLengthOverflowReverts(uint256[] memory us, uint256 forgedLength) external {
        forgedLength = bound(forgedLength, 2 ** 255, type(uint256).max);
        vm.expectRevert(stdError.arithmeticError);
        this.unsafeTo16BitBytesWithForgedLength(us, forgedLength);
    }

    /// Three real elements behind a length prefix claiming `2 ** 255 + 3`, which
    /// used to return the six bytes of the three real elements as though the
    /// claim had been honoured.
    function testUnsafeTo16BitBytesForgedLengthOverflowRevertsForThreeRealElements() external {
        uint256[] memory us = new uint256[](3);
        us[0] = 0xAAAA;
        us[1] = 0xBBBB;
        us[2] = 0xCCCC;

        vm.expectRevert(stdError.arithmeticError);
        this.unsafeTo16BitBytesWithForgedLength(us, (2 ** 255) + 3);
    }

    /// Forging the length prefix has to happen behind an external call boundary.
    /// `expectRevert` needs a call to watch, and an array claiming more elements
    /// than it has cannot be ABI encoded to get across one, so the forgery is
    /// done on this side of it. The assembly is deliberately not annotated
    /// `memory-safe`: it leaves `us` inconsistent with its own allocation, which
    /// is the whole point of the test.
    function unsafeTo16BitBytesWithForgedLength(uint256[] memory us, uint256 forgedLength)
        external
        pure
        returns (bytes memory)
    {
        assembly {
            mstore(us, forgedLength)
        }
        return LibConvert.unsafeTo16BitBytes(us);
    }

    /// The packing loop writes whole words at two byte offsets, so it has to
    /// stop before it runs off the end of what it allocated. Comparing the
    /// result value alone cannot see a write past that end, because such a write
    /// lands beyond the length the comparison reads. Sentinels are placed
    /// immediately above the allocation instead.
    function testUnsafeTo16BitBytesWritesNothingPastItsAllocation(uint256[] memory us) public pure {
        checkWritesNothingPastAllocation(us);
    }

    /// Lengths whose packed data exactly fills whole words, where a single byte
    /// written past the end of the data lands outside the allocation rather than
    /// in its padding.
    function testUnsafeTo16BitBytesWritesNothingPastItsAllocationAtWordBoundaries() public pure {
        uint256[] memory lengths = new uint256[](4);
        lengths[0] = 0;
        lengths[1] = 16;
        lengths[2] = 32;
        lengths[3] = 48;

        for (uint256 j = 0; j < lengths.length; j++) {
            uint256[] memory us = new uint256[](lengths[j]);
            for (uint256 i = 0; i < us.length; i++) {
                us[i] = type(uint256).max;
            }
            checkWritesNothingPastAllocation(us);
        }
    }

    function checkWritesNothingPastAllocation(uint256[] memory us) internal pure {
        uint256 sentinel = uint256(keccak256("rain.lib.typecast.canary"));
        uint256 expectedLength = us.length * 2;

        // Sentinels sit directly above the allocation the conversion is about to
        // make, which is the free pointer plus a length word plus the data
        // rounded up to whole words.
        uint256 canary;
        assembly {
            canary := add(mload(0x40), add(0x20, and(add(mul(mload(us), 2), 0x1f), not(0x1f))))
            mstore(canary, sentinel)
            mstore(add(canary, 0x20), sentinel)
            mstore(add(canary, 0x40), sentinel)
            mstore(add(canary, 0x60), sentinel)
        }

        bytes memory bs = LibConvert.unsafeTo16BitBytes(us);

        uint256 c0;
        uint256 c1;
        uint256 c2;
        uint256 c3;
        assembly {
            c0 := mload(canary)
            c1 := mload(add(canary, 0x20))
            c2 := mload(add(canary, 0x40))
            c3 := mload(add(canary, 0x60))
        }

        assertEq(bs.length, expectedLength);
        assertEq(c0, sentinel);
        assertEq(c1, sentinel);
        assertEq(c2, sentinel);
        assertEq(c3, sentinel);
    }
}

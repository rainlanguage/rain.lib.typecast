// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCast} from "../src/LibCast.sol";

contract LibCastTest is Test {
    function testAddressesArrayRound0(uint256[] memory us) public pure {
        // The input and the round trip are the same buffer, so comparing them
        // against each other cannot observe a cast that rewrites elements where
        // they lie. The expected words are snapshotted into an independent
        // buffer first so that such a rewrite is observable.
        uint256[] memory expected = new uint256[](us.length);
        for (uint256 i = 0; i < us.length; i++) {
            expected[i] = us[i];
        }

        address[] memory intermediate = LibCast.asAddressesArray(us);

        // The intermediate array is what a consumer of the cast reads, and a
        // cast leaves every bit alone, including the bits that do not form part
        // of a valid `address`.
        assertEq(intermediate.length, expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            uint256 word;
            assembly ("memory-safe") {
                word := mload(add(add(intermediate, 0x20), mul(i, 0x20)))
            }
            assertEq(word, expected[i]);
        }

        assertEq(expected, LibCast.asUint256Array(intermediate));
    }

    function testAddressesArrayRound1(address[] memory addresses) public pure {
        address[] memory expected = new address[](addresses.length);
        for (uint256 i = 0; i < addresses.length; i++) {
            expected[i] = addresses[i];
        }

        uint256[] memory intermediate = LibCast.asUint256Array(addresses);

        assertEq(intermediate.length, expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(intermediate[i], uint256(uint160(expected[i])));
        }

        assertEq(expected, LibCast.asAddressesArray(intermediate));
    }

    function testBytes32ArrayRound0(uint256[] memory us) public pure {
        uint256[] memory expected = new uint256[](us.length);
        for (uint256 i = 0; i < us.length; i++) {
            expected[i] = us[i];
        }

        bytes32[] memory intermediate = LibCast.asBytes32Array(us);

        assertEq(intermediate.length, expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(uint256(intermediate[i]), expected[i]);
        }

        assertEq(expected, LibCast.asUint256Array(intermediate));
    }

    function testBytes32ArrayRound1(bytes32[] memory b32s) public pure {
        bytes32[] memory expected = new bytes32[](b32s.length);
        for (uint256 i = 0; i < b32s.length; i++) {
            expected[i] = b32s[i];
        }

        uint256[] memory intermediate = LibCast.asUint256Array(b32s);

        assertEq(intermediate.length, expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(intermediate[i], uint256(expected[i]));
        }

        bytes32[] memory round_ = LibCast.asBytes32Array(intermediate);

        assertEq(round_.length, expected.length);
        for (uint256 i = 0; i < expected.length; i++) {
            assertEq(expected[i], round_[i]);
        }
    }

    /// A cast retypes the data where it lies, so the returned array is the same
    /// buffer as the input rather than a copy of it. Callers rely on this: the
    /// two names address one mutable structure.
    function testAsAddressesArrayRetypesInPlace(uint256[] memory us) public pure {
        uint256 usPointer;
        assembly ("memory-safe") {
            usPointer := us
        }

        address[] memory addresses = LibCast.asAddressesArray(us);

        uint256 addressesPointer;
        assembly ("memory-safe") {
            addressesPointer := addresses
        }
        assertEq(addressesPointer, usPointer);
    }

    function testAsUint256ArrayFromAddressesRetypesInPlace(address[] memory addresses) public pure {
        uint256 addressesPointer;
        assembly ("memory-safe") {
            addressesPointer := addresses
        }

        uint256[] memory us = LibCast.asUint256Array(addresses);

        uint256 usPointer;
        assembly ("memory-safe") {
            usPointer := us
        }
        assertEq(usPointer, addressesPointer);
    }

    function testAsBytes32ArrayRetypesInPlace(uint256[] memory us) public pure {
        uint256 usPointer;
        assembly ("memory-safe") {
            usPointer := us
        }

        bytes32[] memory b32s = LibCast.asBytes32Array(us);

        uint256 b32sPointer;
        assembly ("memory-safe") {
            b32sPointer := b32s
        }
        assertEq(b32sPointer, usPointer);
    }

    function testAsUint256ArrayFromBytes32RetypesInPlace(bytes32[] memory b32s) public pure {
        uint256 b32sPointer;
        assembly ("memory-safe") {
            b32sPointer := b32s
        }

        uint256[] memory us = LibCast.asUint256Array(b32s);

        uint256 usPointer;
        assembly ("memory-safe") {
            usPointer := us
        }
        assertEq(usPointer, b32sPointer);
    }

    /// Writing through either name is visible through the other, because they
    /// are one buffer.
    function testAsAddressesArrayWritesAreShared(uint256[] memory us, address written) public pure {
        vm.assume(us.length > 0);

        address[] memory addresses = LibCast.asAddressesArray(us);
        addresses[0] = written;

        assertEq(us[0], uint256(uint160(written)));
    }
}

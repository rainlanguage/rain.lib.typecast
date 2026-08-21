// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Test} from "forge-std-1.16.1/src/Test.sol";
import {LibCast} from "../src/LibCast.sol";

contract LibCastTest is Test {
    function testAddressesArrayRound0(uint256[] memory us) public pure {
        assertEq(us, LibCast.asUint256Array(LibCast.asAddressesArray(us)));
    }

    function testAddressesArrayRound1(address[] memory addresses) public pure {
        assertEq(addresses, LibCast.asAddressesArray(LibCast.asUint256Array(addresses)));
    }

    function testBytes32ArrayRound0(uint256[] memory us) public pure {
        assertEq(us, LibCast.asUint256Array(LibCast.asBytes32Array(us)));
    }

    function testBytes32ArrayRound1(bytes32[] memory b32s) public pure {
        bytes32[] memory round_ = LibCast.asBytes32Array(LibCast.asUint256Array(b32s));

        for (uint256 i = 0; i < b32s.length; i++) {
            assertEq(b32s[i], round_[i]);
        }
    }

    /// Storage sinks for the containment test below. Declared beside their only
    /// user rather than at the top of the contract.
    address[] internal sSinkAddresses;
    mapping(address => uint256) internal sSinkSeen;

    /// `address` is narrower than a word and the cast writes nothing, so an
    /// input word `>= 2 ** 160` produces an element that keeps its upper 96
    /// bits. An assembly read of that element sees all 256 bits, which is the
    /// one escape the NatSpec names and the only one that holds on every
    /// compilation pipeline.
    function testAsAddressesArrayKeepsUpperBitsForAssemblyReads(uint256 word) public pure {
        // Set the top bit so every fuzz run exercises the dirty case, rather
        // than discarding most of the runs through an assumption.
        word |= uint256(1) << 255;

        uint256[] memory us = new uint256[](1);
        us[0] = word;

        address[] memory addresses = LibCast.asAddressesArray(us);

        uint256 raw;
        assembly ("memory-safe") {
            raw := mload(add(addresses, 0x20))
        }
        assertEq(raw, word);
    }

    /// The other half of the documented contract: every consumer the compiler
    /// generates cleans the element to 160 bits, so the bits assembly can see
    /// cannot reach state, a hash, or an ABI boundary. This pins the
    /// containment boundary the NatSpec claims, so that a compiler or pipeline
    /// change that moves it fails here instead of leaving the documentation
    /// quietly wrong.
    ///
    /// Deliberately NOT asserted: what `addresses[0]` holds once it is sitting
    /// in a stack slot. That is pipeline dependent - dirty on the legacy
    /// pipeline, cleaned under via-IR - and the NatSpec documents it as
    /// unspecified, so an assertion either way would be false on one of the two
    /// pipelines.
    function testAsAddressesArrayDirtyElementCannotEscapeThroughSolidity(uint256 word) public {
        word |= uint256(1) << 255;

        uint256[] memory us = new uint256[](1);
        us[0] = word;
        address[] memory addresses = LibCast.asAddressesArray(us);
        address clean = address(uint160(word));

        // Premise. Without this the assertions below could all pass vacuously
        // on an implementation that masked.
        uint256 raw;
        assembly ("memory-safe") {
            raw := mload(add(addresses, 0x20))
        }
        assertEq(raw, word);
        assertGt(raw, uint256(type(uint160).max));

        // Comparison.
        assertTrue(addresses[0] == clean);

        // ABI encoding, packed encoding, and hashing over them.
        address[] memory cleanArray = new address[](1);
        cleanArray[0] = clean;
        assertEq(abi.encode(addresses), abi.encode(cleanArray));
        assertEq(abi.encodePacked(addresses), abi.encodePacked(cleanArray));
        assertEq(keccak256(abi.encodePacked(addresses[0])), keccak256(abi.encodePacked(clean)));

        // Assignment into a storage `address[]`, read back from the raw storage
        // word so that the stored bits are checked rather than a masked read of
        // them.
        sSinkAddresses = addresses;
        uint256 slot;
        assembly ("memory-safe") {
            slot := sSinkAddresses.slot
        }
        assertEq(uint256(vm.load(address(this), keccak256(abi.encode(slot)))), uint256(uint160(clean)));

        // Mapping key. A dirty key would hash to a different slot and the clean
        // lookup would miss.
        sSinkSeen[addresses[0]] = 1;
        assertEq(sSinkSeen[clean], 1);

        // Element write into a conventional `address[]`.
        address[] memory written = new address[](1);
        written[0] = addresses[0];
        uint256 writtenRaw;
        assembly ("memory-safe") {
            writtenRaw := mload(add(written, 0x20))
        }
        assertEq(writtenRaw, uint256(uint160(clean)));

        // External ABI boundary. Encodes, decodes, and does not revert.
        assertEq(this.echoFirstAddress(addresses), clean);
    }

    /// External entry point for the ABI boundary leg of the containment test
    /// above. Lives on this contract because the repo is one contract per file.
    function echoFirstAddress(address[] calldata addresses) external pure returns (address) {
        return addresses[0];
    }
}

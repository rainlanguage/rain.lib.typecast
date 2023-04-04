// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/LibCast.sol";

contract LibCastTest is Test {
    function testAddressesArrayRound0(uint256[] memory us_) public {
        assertEq(us_, LibCast.asUint256Array(LibCast.asAddressesArray(us_)));
    }

    function testAddressesArrayRound1(address[] memory addresses_) public {
        assertEq(addresses_, LibCast.asAddressesArray(LibCast.asUint256Array(addresses_)));
    }

    function testBytes32ArrayRound0(uint256[] memory us_) public {
        assertEq(us_, LibCast.asUint256Array(LibCast.asBytes32Array(us_)));
    }

    function testBytes32ArrayRound1(bytes32[] memory b32s_) public {
        bytes32[] memory round_ = LibCast.asBytes32Array(LibCast.asUint256Array(b32s_));

        for (uint256 i_ = 0; i_ < b32s_.length; i_++) {
            assertEq(b32s_[i_], round_[i_]);
        }
    }
}

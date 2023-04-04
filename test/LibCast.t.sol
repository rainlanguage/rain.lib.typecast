// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "forge-std/Test.sol";

contract LibCastTest is Test {
    function testAddressesArrayRound(uint256[] memory us_) public {
        assertEq(
            us_,
            LibCast.asUint256Array(LibCast.asAddressesArray(us_))
        );
    }
}
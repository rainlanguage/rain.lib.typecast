// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "../src/LibConvert.sol";
import "./LibConvertSlow.sol";

contract LibConvertTest is Test {
    function testUnsafeToBytesReferenceImplementation(uint256[] memory us_) public {
        assertEq(
            // Note the order of these calls is important because the unsafe call
            // is unsafe, i.e. the `us_` can no longer be used.
            LibConvertSlow.toBytesSlow(us_),
            LibConvert.unsafeToBytes(us_)
        );
    }

    function testUnsafeTo16BitBytesReferenceImplementation(uint256[] memory us_) public {
        assertEq(
            // Note the order of these calls is important because the unsafe call
            // is unsafe, i.e. the `us_` can no longer be used.
            LibConvertSlow.to16BitBytesSlow(us_),
            LibConvert.unsafeTo16BitBytes(us_)
        );
    }

    function testDebug() public {
        uint256[] memory us_ = new uint256[](1);
        us_[0] = 196608;
        LibConvert.unsafeTo16BitBytes(us_);
    }
}

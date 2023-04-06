// SPDX-License-Identifier: CAL
pragma solidity ^0.8.18;

library LibConvertSlow {
    function toBytesSlow(uint256[] memory us_) internal pure returns (bytes memory) {
        return abi.encodePacked(us_);
    }

    function to16BitBytesSlow(uint256[] memory us_) internal pure returns (bytes memory) {
        bytes memory ret_ = new bytes(0);
        for (uint256 i_ = 0; i_ < us_.length; i_++) {
            ret_ = bytes.concat(ret_, bytes2(uint16(us_[i_])));
        }
        return ret_;
    }
}

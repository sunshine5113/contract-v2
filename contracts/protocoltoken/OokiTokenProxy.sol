// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./Upgradeable_0_8.sol";
import "@openzeppelin-4.3.2/utils/Address.sol";

contract OokiTokenProxy is Upgradeable_0_8 {
    constructor(address _impl) public {
        replaceImplementation(_impl);
    }

    fallback() external {
        address impl = implementation;

        bytes memory data = msg.data;
        assembly {
            let result := delegatecall(gas(), impl, add(data, 0x20), mload(data), 0, 0)
            let size := returndatasize()
            let ptr := mload(0x40)
            returndatacopy(ptr, 0, size)
            switch result
            case 0 { revert(ptr, size) }
            default { return(ptr, size) }
        }
    }

    function replaceImplementation(address impl) public onlyOwner {
        require(Address.isContract(impl), "not a contract");
        implementation = impl;
    }
}

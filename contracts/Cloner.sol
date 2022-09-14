// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Cloner is Ownable {
    using Address for address;
    using Clones for address;

    event NewInstance(address implementation, address instance, string name);

    constructor() Ownable() {}

    function clone(address implementation, bytes memory data, string memory name) external payable onlyOwner {
        _initAndEmit(implementation.clone(), data, name, implementation);
    }

    function cloneDeterministic(
        address implementation,
        bytes32 salt,
        bytes calldata initdata,
        string memory name
    ) external payable onlyOwner {
        _initAndEmit(implementation.cloneDeterministic(salt), initdata, name, implementation);
    }

    function predictDeterministicAddress(address implementation, bytes32 salt)
        public
        view
        returns (address predicted)
    {
        return implementation.predictDeterministicAddress(salt);
    }

    function _initAndEmit(address instance, bytes memory initdata, string memory name, address implementation) private {
        if (initdata.length > 0) {
            instance.functionCallWithValue(initdata, msg.value);
        }
        emit NewInstance(implementation, instance, name);
    }
}

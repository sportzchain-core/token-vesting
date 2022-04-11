// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "./TokenVestingFactoryNaive.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVestingFactory is Ownable {
    address private _erc20_token;

    event deployedVestingContract(address deployed);

    constructor(address token_) {
        _erc20_token = token_;
    }

    function createNewVestingContract() external onlyOwner {
        address cloned_ = address(new TokenVestingFactoryNaive(_erc20_token, msg.sender));
        emit deployedVestingContract(cloned_);
    }
}
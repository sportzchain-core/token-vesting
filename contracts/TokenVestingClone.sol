// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "./TokenVesting.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVestingClone is Ownable {
    address payable immutable vestingImplementation;

    address private _erc20_token;

    event deployedVestingContract(address payable deployed);

    constructor(address token_) {
        _erc20_token = token_;
        vestingImplementation = payable(address(new TokenVesting()));
    }

    function createNewVestingContract() external onlyOwner {
        address payable clone = payable(Clones.clone(vestingImplementation));
        TokenVesting(clone).initialize(_erc20_token, msg.sender);
        emit deployedVestingContract(clone);
    }
}
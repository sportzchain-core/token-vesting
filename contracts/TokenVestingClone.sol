// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "./TokenVesting.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Contract for cloning the vesting contract
 *
 * @dev Contract which gives the ability to clone an vesting contract so that grantor
 *  can issue unique vesting contract for each individuals who needs vesting.
 */
contract TokenVestingClone is Ownable {

    // base vesting contract addess
    address payable immutable vestingImplementation;

    // token contract address
    address private _erc20_token;

    // event to notify the clone creation
    event deployedVestingContract(address payable deployed);

    /**
    * @dev Constructor
    *
    * @param token_ - token address that is used in vesting
    */
    constructor(address token_) {
        _erc20_token = token_;
        vestingImplementation = payable(address(new TokenVesting()));
    }

    /**
    * @dev Method to create a new vesting contract using cloning approach
    */
    function createNewVestingContract() external onlyOwner {
        address payable clone = payable(Clones.clone(vestingImplementation));
        TokenVesting(clone).initialize(_erc20_token, msg.sender);
        emit deployedVestingContract(clone);
    }
}
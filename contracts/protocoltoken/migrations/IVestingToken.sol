/**
 * Copyright 2017-2021, bZxDao. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */
// SPDX-License-Identifier: Apache License, Version 2.0.
pragma solidity 0.6.12;

import "@openzeppelin-3.4.0/token/ERC20/IERC20.sol";

interface IVestingToken is IERC20 {
    function claim() external;

    function vestedBalanceOf(address _owner) external view returns (uint256);

    function claimedBalanceOf(address _owner) external view returns (uint256);
}

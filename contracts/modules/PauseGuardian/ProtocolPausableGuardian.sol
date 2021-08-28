/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */
// SPDX-License-Identifier: APACHE 2.0

pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "../../core/State.sol";
import "../../governance/PausableGuardian.sol";


contract ProtocolPausableGuardian is State, PausableGuardian {

    function initialize(
        address target)
        external
        onlyOwner
    {
        _setTarget(this._isPaused.selector, target);
        _setTarget(this.toggleFunctionPause.selector, target);
        _setTarget(this.toggleFunctionUnPause.selector, target);
        _setTarget(this.changeGuardian.selector, target);
        _setTarget(this.getGuardian.selector, target);
    }
}

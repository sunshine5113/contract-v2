/**
 * Copyright 2017-2021, bZxDao. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;

import "../core/State.sol";
import "../interfaces/ILoanPool.sol";
import "../utils/MathUtil.sol";


contract InterestHandler is State {
    using MathUtil for uint256;

    // returns up to date loan interest or 0 if not applicable
    function _settleInterest(
        address pool,
        bytes32 loanId)
        internal
        returns (uint256 _loanInterestTotal)
    {
        uint256[7] memory interestVals = _settleInterest2(
            pool,
            loanId
        );
        poolInterestTotal[pool] = interestVals[1];
        poolRatePerTokenStored[pool] = interestVals[2];
        poolLastInterestRate[pool] = interestVals[3];

        if (loanId != 0) {
            _loanInterestTotal = interestVals[5];
            loanInterestTotal[loanId] = _loanInterestTotal;
            loanRatePerTokenPaid[loanId] = interestVals[6];
        }

        poolLastUpdateTime[pool] = block.timestamp;
    }

    function _getPoolPrincipal(
        address pool)
        internal
        view
        returns (uint256)
    {
        uint256[7] memory interestVals = _settleInterest2(
            pool,
            0
        );

        uint256 lendingFee = interestVals[1] // _poolInterestTotal
            .mul(lendingFeePercent)
            .divCeil(WEI_PERCENT_PRECISION);

        return interestVals[0]      // _poolPrincipalTotal
            .add(interestVals[1])   // _poolInterestTotal
            .sub(lendingFee);
    }

    function _getLoanPrincipal(
        address pool,
        bytes32 loanId)
        internal
        view
        returns (uint256)
    {
        uint256[7] memory interestVals = _settleInterest2(
            pool,
            loanId
        );

        return interestVals[4]      // _loanPrincipalTotal
            .add(interestVals[5]);  // _loanInterestTotal
    }

    function _settleInterest2(
        address pool,
        bytes32 loanId)
        internal
        view
        returns (uint256[7] memory interestVals)
    {
        /*
            uint256[7] ->
            0: _poolPrincipalTotal,
            1: _poolInterestTotal,
            2: _poolRatePerTokenStored,
            3: _poolNextInterestRate,
            4: _loanPrincipalTotal,
            5: _loanInterestTotal,
            6: _loanRatePerTokenPaid
        */

        interestVals[0] = poolPrincipalTotal[pool];
        interestVals[1] = poolInterestTotal[pool];

        uint256 _poolVariableRatePerTokenNewAmount;
        (_poolVariableRatePerTokenNewAmount, interestVals[3]) = _getRatePerTokenNewAmount(pool, interestVals[0].add(interestVals[1]));

        interestVals[1] = interestVals[0]
            .mul(_poolVariableRatePerTokenNewAmount)
            .div(WEI_PERCENT_PRECISION * WEI_PERCENT_PRECISION)
            .add(interestVals[1]);

        interestVals[2] = poolRatePerTokenStored[pool]
            .add(_poolVariableRatePerTokenNewAmount);

         if (loanId != 0 && (interestVals[4] = loans[loanId].principal) != 0) {
            interestVals[5] = interestVals[4]
                .mul(interestVals[2].sub(loanRatePerTokenPaid[loanId])) // _loanRatePerTokenUnpaid
                .div(WEI_PERCENT_PRECISION * WEI_PERCENT_PRECISION)
                .add(loanInterestTotal[loanId]);

            interestVals[6] = interestVals[2];
        }
    }

    function _getRatePerTokenNewAmount(
        address pool,
        uint256 poolTotal)
        internal
        view
        returns (uint256 ratePerTokenNewAmount, uint256 nextInterestRate)
    {
        nextInterestRate = ILoanPool(pool)._nextBorrowInterestRate(poolTotal, 0, poolLastInterestRate[pool]);
        if (nextInterestRate != 0) {
            ratePerTokenNewAmount = block.timestamp
                .sub(poolLastUpdateTime[pool])
                .mul(nextInterestRate) // rate per year
                .mul(WEI_PERCENT_PRECISION)
                .div(31536000); // seconds in a year
        }
    }
}

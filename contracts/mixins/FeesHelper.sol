/**
 * Copyright 2017-2021, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;

import "../core/State.sol";
import "@openzeppelin-2.5.0/token/ERC20/SafeERC20.sol";
import "../../interfaces/IPriceFeeds.sol";
import "../events/FeesEvents.sol";
import "../utils/MathUtil.sol";

contract FeesHelper is State, FeesEvents {
    using SafeERC20 for IERC20;
    using MathUtil for uint256;

    // calculate trading fee
    function _getTradingFee(
        uint256 feeTokenAmount)
        internal
        view
        returns (uint256)
    {
        return feeTokenAmount
            .mul(tradingFeePercent)
            .divCeil(WEI_PERCENT_PRECISION);
    }

    // calculate loan origination fee
    function _getBorrowingFee(
        uint256 feeTokenAmount)
        internal
        view
        returns (uint256)
    {
        return feeTokenAmount
            .mul(borrowingFeePercent)
            .divCeil(WEI_PERCENT_PRECISION);
    }

    // settle trading fee
    function _payTradingFee(
        address user,
        bytes32 loanId,
        address feeToken,
        uint256 tradingFee)
        internal
    {
        if (tradingFee != 0) {
            tradingFeeTokensHeld[feeToken] = tradingFeeTokensHeld[feeToken]
                .add(tradingFee);

            emit PayTradingFee(
                user,
                feeToken,
                loanId,
                tradingFee
            );

            _payFeeReward(
                user,
                loanId,
                feeToken,
                tradingFee,
                FeeType.Trading
            );
        }
    }

    // settle loan origination fee
    function _payBorrowingFee(
        address user,
        bytes32 loanId,
        address feeToken,
        uint256 borrowingFee)
        internal
    {
        if (borrowingFee != 0) {
            borrowingFeeTokensHeld[feeToken] = borrowingFeeTokensHeld[feeToken]
                .add(borrowingFee);

            emit PayBorrowingFee(
                user,
                feeToken,
                loanId,
                borrowingFee
            );

            _payFeeReward(
                user,
                loanId,
                feeToken,
                borrowingFee,
                FeeType.Borrowing
            );
        }
    }

    // settle lender (interest) fee
    function _payLendingFee(
        address user,
        address feeToken,
        uint256 lendingFee)
        internal
    {
        if (lendingFee != 0) {
            lendingFeeTokensHeld[feeToken] = lendingFeeTokensHeld[feeToken]
                .add(lendingFee);

            emit PayLendingFee(
                user,
                feeToken,
                lendingFee
            );

             //// NOTE: Lenders do not receive a fee reward ////
        }
    }

    // settles and pays borrowers based on the fees generated by their interest payments
    function _settleFeeRewardForInterestExpense(
        LoanInterest storage loanInterestLocal,
        bytes32 loanId,
        address feeToken,
        address user,
        uint256 interestTime)
        internal
    {
        uint256 updatedTimestamp = loanInterestLocal.updatedTimestamp;

        uint256 interestExpenseFee;
        if (updatedTimestamp != 0) {
            // this represents the fee generated by a borrower's interest payment
            interestExpenseFee = interestTime
                .sub(updatedTimestamp)
                .mul(loanInterestLocal.owedPerDay)
                .mul(lendingFeePercent)
                .div(1 days * WEI_PERCENT_PRECISION);
        }

        loanInterestLocal.updatedTimestamp = interestTime;

        if (interestExpenseFee != 0) {
            emit SettleFeeRewardForInterestExpense(
                user,
                feeToken,
                loanId,
                interestExpenseFee
            );

            _payFeeReward(
                user,
                loanId,
                feeToken,
                interestExpenseFee,
                FeeType.SettleInterest
            );
        }
    }

    // pay protocolToken reward to user
    function _payFeeReward(
        address user,
        bytes32 loanId,
        address feeToken,
        uint256 feeAmount,
        FeeType feeType)
        internal
    {
        if (vbzrxTokenAddress == address(0)) {
            // deploy network doesn't support vBZRX
            return;
        }

        // The protocol is designed to allow positions and loans to be closed, if for whatever reason
        // the price lookup is failing, returning 0, or is otherwise paused. Therefore, we allow this
        // call to fail silently, rather than revert, to allow the transaction to continue without a
        // BZRX token reward.
        uint256 rewardAmount;
        address _priceFeeds = priceFeeds;
        (bool success, bytes memory data) = _priceFeeds.staticcall(
            abi.encodeWithSelector(
                IPriceFeeds(_priceFeeds).queryReturn.selector,
                feeToken,
                bzrxTokenAddress, // price rewards using BZRX price rather than vesting token price
                feeAmount / 2  // 50% of fee value
            )
        );
        assembly {
            if eq(success, 1) {
                rewardAmount := mload(add(data, 32))
            }
        }

        if (rewardAmount != 0) {
            uint256 tokenBalance = protocolTokenHeld;
            if (rewardAmount > tokenBalance) {
                rewardAmount = tokenBalance;
            }
            if (rewardAmount != 0) {
                protocolTokenHeld = tokenBalance
                    .sub(rewardAmount);

                bytes32 slot = keccak256(abi.encodePacked(user, UserRewardsID));
                assembly {
                    sstore(slot, add(sload(slot), rewardAmount))
                }

                emit EarnReward(
                    user,
                    loanId,
                    feeType,
                    vbzrxTokenAddress, // rewardToken
                    rewardAmount
                );
            }
        }
    }
}

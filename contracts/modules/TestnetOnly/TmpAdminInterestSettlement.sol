/**
 * Copyright 2017-2020, bZeroX, LLC <https://bzx.network/>. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "../../core/State.sol";
import "../../openzeppelin/SafeERC20.sol";
import "../../feeds/IPriceFeeds.sol";


contract TmpAdminInterestSettlement is State {
    using SafeERC20 for IERC20;

    function initialize(
        address target)
        external
        onlyOwner
    {
        _setTarget(this.tmpSettleFeeRewards.selector, target);
    }

    struct RewardsData {
        address receiver;
        uint256 amount;
    }

    function tmpSettleFeeRewards(
        bytes32[] calldata loanIds,
        uint256 startDate)
        external
        onlyOwner
        returns (RewardsData[] memory rewardsData)
    {
        rewardsData = new RewardsData[](loanIds.length);
        uint256 itemCount;

        uint256 _lendingFeePercent = lendingFeePercent;
        IPriceFeeds _priceFeeds = IPriceFeeds(priceFeeds);

        for (uint256 i = 0; i < loanIds.length; i++) {
            Loan memory loanLocal = loans[loanIds[i]];
            if (!loanLocal.active) {
                continue;
            }
            LoanParams memory loanParamsLocal = loanParams[loanLocal.loanParamsId];

            uint256 interestTime = block.timestamp;
            if (interestTime > loanLocal.endTimestamp) {
                interestTime = loanLocal.endTimestamp;
            }

            LoanInterest memory loanInterestLocal = loanInterest[loanIds[i]];
            uint256 updatedTimestamp = loanInterestLocal.updatedTimestamp;

            uint256 interestExpenseFee;
            if (updatedTimestamp != 0) {
                if (updatedTimestamp < startDate) {
                    updatedTimestamp = startDate;
                }

                if (updatedTimestamp >= interestTime) {
                    continue;
                }

                // this represents the fee generated by a borrower's interest payment
                interestExpenseFee = interestTime
                    .sub(updatedTimestamp)
                    .mul(loanInterestLocal.owedPerDay)
                    .mul(_lendingFeePercent)
                    .div(1 days * WEI_PERCENT_PRECISION);
 
                if (interestExpenseFee != 0) {
                    uint256 rewardAmount = _priceFeeds.queryReturn(
                        loanParamsLocal.loanToken,
                        bzrxTokenAddress, // price rewards using BZRX price rather than vesting token price
                        interestExpenseFee / 2  // 50% of fee value
                    );

                    rewardsData[itemCount].receiver = loanLocal.borrower;
                    rewardsData[itemCount].amount = rewardAmount;
                }
            }

            itemCount++;
        }

        if (itemCount < rewardsData.length) {
            assembly {
                mstore(rewardsData, itemCount)
            }
        }
    }
}

/**
 * Copyright 2017-2020, bZeroX, LLC <https://bzx.network/>. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "./StakingState.sol";
import "./StakingConstants.sol";
import "../interfaces/IVestingToken.sol";
import "../interfaces/ILoanPool.sol";
import "../feeds/IPriceFeeds.sol";
import "../connectors/gastoken/GasTokenUser.sol";


contract StakingV1 is StakingState, StakingConstants, GasTokenUser {

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "unauthorized");
        _;
    }

    modifier checkPause() {
        require(!isPaused, "paused");
        _;
    }

    function stake(
        address[] calldata tokens,
        uint256[] calldata values)
        external
        checkPause
        updateRewards(msg.sender)
    {
        require(tokens.length == values.length, "count mismatch");

        address currentDelegate = delegate[msg.sender];
        if (currentDelegate == address(0)) {
            currentDelegate = msg.sender;
            delegate[msg.sender] = currentDelegate;
            _delegatedSet.addAddress(msg.sender);
        }

        address token;
        uint256 stakeAmount;

        for (uint256 i = 0; i < tokens.length; i++) {
            token = tokens[i];
            require(token == BZRX || token == vBZRX || token == iBZRX || token == LPToken, "invalid token");

            stakeAmount = values[i];
            if (stakeAmount == 0) {
                continue;
            }

            _balancesPerToken[token][msg.sender] = _balancesPerToken[token][msg.sender].add(stakeAmount);
            _totalSupplyPerToken[token] = _totalSupplyPerToken[token].add(stakeAmount);

            delegatedPerToken[currentDelegate][token] = delegatedPerToken[currentDelegate][token]
                .add(stakeAmount);

            IERC20(token).safeTransferFrom(msg.sender, address(this), stakeAmount);

            emit Stake(
                msg.sender,
                token,
                currentDelegate,
                stakeAmount
            );
        }
    }

    function unstake(
        address[] memory tokens,
        uint256[] memory values)
        public
        checkPause
        updateRewards(msg.sender)
    {
        require(tokens.length == values.length, "count mismatch");

        address currentDelegate = delegate[msg.sender];

        address token;
        uint256 unstakeAmount;
        uint256 stakedAmount;
        for (uint256 i = 0; i < tokens.length; i++) {
            token = tokens[i];
            require(token == BZRX || token == vBZRX || token == iBZRX || token == LPToken, "invalid token");

            unstakeAmount = values[i];
            stakedAmount = _balancesPerToken[token][msg.sender];
            if (unstakeAmount == 0 || stakedAmount == 0) {
                continue;
            }
            if (unstakeAmount > stakedAmount) {
                unstakeAmount = stakedAmount;
            }

            _balancesPerToken[token][msg.sender] = stakedAmount - unstakeAmount; // will not overflow
            _totalSupplyPerToken[token] = _totalSupplyPerToken[token] - unstakeAmount; // will not overflow

            delegatedPerToken[currentDelegate][token] = delegatedPerToken[currentDelegate][token]
                .sub(unstakeAmount);

            if (token == BZRX && IERC20(BZRX).balanceOf(address(this)) < unstakeAmount) {
                // settle vested BZRX only if needed
                IVestingToken(vBZRX).claim();
            }

            IERC20(token).safeTransfer(msg.sender, unstakeAmount);

            emit Unstake(
                msg.sender,
                token,
                currentDelegate,
                unstakeAmount
            );
        }
    }

    /*function changeDelegate(
        address delegateToSet)
        external
        checkPause
    {
        if (delegateToSet == ZERO_ADDRESS) {
            delegateToSet = msg.sender;
        }

        address currentDelegate = delegate[msg.sender];
        if (delegateToSet != currentDelegate) {
            if (currentDelegate != ZERO_ADDRESS) {
                uint256 balance = _balancesPerToken[BZRX][msg.sender];
                if (balance != 0) {
                    delegatedPerToken[currentDelegate][BZRX] = delegatedPerToken[currentDelegate][BZRX]
                        .sub(balance);
                    delegatedPerToken[delegateToSet][BZRX] = delegatedPerToken[delegateToSet][BZRX]
                        .add(balance);
                }

                balance = _balancesPerToken[vBZRX][msg.sender];
                if (balance != 0) {
                    delegatedPerToken[currentDelegate][vBZRX] = delegatedPerToken[currentDelegate][vBZRX]
                        .sub(balance);
                    delegatedPerToken[delegateToSet][vBZRX] = delegatedPerToken[delegateToSet][vBZRX]
                        .add(balance);
                }

                balance = _balancesPerToken[iBZRX][msg.sender];
                if (balance != 0) {
                    delegatedPerToken[currentDelegate][iBZRX] = delegatedPerToken[currentDelegate][iBZRX]
                        .sub(balance);
                    delegatedPerToken[delegateToSet][iBZRX] = delegatedPerToken[delegateToSet][iBZRX]
                        .add(balance);
                }

                balance = _balancesPerToken[LPToken][msg.sender];
                if (balance != 0) {
                    delegatedPerToken[currentDelegate][LPToken] = delegatedPerToken[currentDelegate][LPToken]
                        .sub(balance);
                    delegatedPerToken[delegateToSet][LPToken] = delegatedPerToken[delegateToSet][LPToken]
                        .add(balance);
                }
            }

            delegate[msg.sender] = delegateToSet;
            _delegatedSet.addAddress(delegateToSet);

            emit ChangeDelegate(
                msg.sender,
                currentDelegate,
                delegateToSet
            );

            currentDelegate = delegateToSet;
        }
    }*/

    function claim()
        external
        checkPause
        returns (uint256 bzrxRewardsEarned, uint256 stableCoinRewardsEarned)
    {
        return _claim(false);
    }

    function claimAndRestake()
        external
        checkPause
        returns (uint256 bzrxRewardsEarned, uint256 stableCoinRewardsEarned)
    {
        return _claim(true);
    }

    /*function claimWithUpdate()
        external
        // sweepFeesByAsset() does checkPause
        returns (uint256 bzrxRewardsEarned, uint256 stableCoinRewardsEarned)
    {
        sweepFees();
        return _claim(false);
    }*/

    /*function claimAndRestakeWithUpdate()
        external
        // sweepFeesByAsset() does checkPause
        returns (uint256 bzrxRewardsEarned, uint256 stableCoinRewardsEarned)
    {
        sweepFees();
        return _claim(true);
    }*/

    function _claim(
        bool restake)
        internal
        updateRewards(msg.sender)
        returns (uint256 bzrxRewardsEarned, uint256 stableCoinRewardsEarned)
    {
        (bzrxRewardsEarned, stableCoinRewardsEarned,,) = _earned(
            msg.sender,
            bzrxPerTokenStored,
            stableCoinPerTokenStored,
            0 // vesting BZRX already handled in updateRewards
        );

        if (bzrxRewardsEarned != 0) {
            bzrxRewards[msg.sender] = 0;
            if (restake) {
                _restakeBZRX(
                    msg.sender,
                    bzrxRewardsEarned
                );
            } else {
                if (IERC20(BZRX).balanceOf(address(this)) < bzrxRewardsEarned) {
                    // settle vested BZRX only if needed
                    IVestingToken(vBZRX).claim();
                }

                IERC20(BZRX).transfer(msg.sender, bzrxRewardsEarned);
            }
        }
        if (stableCoinRewardsEarned != 0) {
            stableCoinRewards[msg.sender] = 0;
            curve3Crv.transfer(msg.sender, stableCoinRewardsEarned);
        }

        emit Claim(
            msg.sender,
            bzrxRewardsEarned,
            stableCoinRewardsEarned
        );
    }

    function _restakeBZRX(
        address account,
        uint256 amount)
        internal
    {
        address currentDelegate = delegate[account];
        _balancesPerToken[BZRX][account] = _balancesPerToken[BZRX][account]
            .add(amount);

        _totalSupplyPerToken[BZRX] = _totalSupplyPerToken[BZRX]
            .add(amount);

        delegatedPerToken[currentDelegate][BZRX] = delegatedPerToken[currentDelegate][BZRX]
            .add(amount);

        emit Stake(
            account,
            BZRX,
            currentDelegate,
            amount
        );
    }

    function exit()
        public
        // unstake() does a checkPause
    {
        address[] memory tokens = new address[](4);
        uint256[] memory values = new uint256[](4);
        tokens[0] = iBZRX;
        tokens[1] = LPToken;
        tokens[2] = vBZRX;
        tokens[3] = BZRX;
        values[0] = uint256(-1);
        values[1] = uint256(-1);
        values[2] = uint256(-1);
        values[3] = uint256(-1);
        
        unstake(tokens, values);
        _claim(false);
    }

    /*function exitWithUpdate()
        external
        // sweepFeesByAsset() does checkPause
    {
        sweepFees();
        exit();
    }*/

    /*function getDelegateVotes(
        uint256 start,
        uint256 count)
        external
        view
        returns (DelegatedTokens[] memory delegateArr)
    {
        uint256 end = start.add(count).min256(_delegatedSet.length());
        if (start >= end) {
            return delegateArr;
        }
        count = end-start;

        uint256 idx = count;
        address user;
        delegateArr = new DelegatedTokens[](idx);
        for (uint256 i = --end; i >= start; i--) {
            user = _delegatedSet.getAddress(i);
            delegateArr[count-(idx--)] = DelegatedTokens({
                user: user,
                BZRX: delegatedPerToken[user][BZRX],
                vBZRX: delegatedPerToken[user][vBZRX],
                iBZRX: delegatedPerToken[user][iBZRX],
                LPToken: delegatedPerToken[user][LPToken],
                totalVotes: delegateBalanceOf(user)
            });

            if (i == 0) {
                break;
            }
        }

        if (idx != 0) {
            count -= idx;
            assembly {
                mstore(delegateArr, count)
            }
        }
    }*/

    modifier updateRewards(address account) {
        uint256 _bzrxPerTokenStored = bzrxPerTokenStored;
        uint256 _stableCoinPerTokenStored = stableCoinPerTokenStored;

        uint256 vBZRXBalance = _balancesPerToken[vBZRX][account];
        (bzrxRewards[account], stableCoinRewards[account], bzrxVesting[account], stableCoinVesting[account]) = _earned(
            account,
            _bzrxPerTokenStored,
            _stableCoinPerTokenStored,
            vBZRXBalance
        );
        bzrxRewardsPerTokenPaid[account] = _bzrxPerTokenStored;
        stableCoinRewardsPerTokenPaid[account] = _stableCoinPerTokenStored;
        _vestingLastSync[account] = block.timestamp;

        _;
    }

    function earned(
        address account)
        public
        view
        returns (uint256 bzrxRewardsEarned, uint256 stableCoinRewardsEarned, uint256 bzrxRewardsVesting, uint256 stableCoinRewardsVesting)
    {
        (bzrxRewardsEarned, stableCoinRewardsEarned, bzrxRewardsVesting, stableCoinRewardsVesting) = _earned(
            account,
            bzrxPerTokenStored,
            stableCoinPerTokenStored,
            _balancesPerToken[vBZRX][account]
        );
    }

    /*function earnedWithUpdate(
        address account)
        external
        // sweepFeesByAsset() does checkPause
        returns (uint256, uint256, uint256, uint256) // bzrxRewardsEarned, stableCoinRewardsEarned, bzrxRewardsVesting, stableCoinRewardsVesting
    {
        sweepFees();
        return earned(account);
    }*/

    function _earned(
        address account,
        uint256 _bzrxPerToken,
        uint256 _stableCoinPerToken,
        uint256 _vBZRXBalance)
        internal
        view
        returns (uint256 bzrxRewardsEarned, uint256 stableCoinRewardsEarned, uint256 bzrxRewardsVesting, uint256 stableCoinRewardsVesting)
    {
        (uint256 vestedBalance, uint256 vestingBalance) = balanceOfStored(account);

        uint256 bzrxPerTokenUnpaid = _bzrxPerToken.sub(bzrxRewardsPerTokenPaid[account]);
        uint256 stableCoinPerTokenUnpaid = _stableCoinPerToken.sub(stableCoinRewardsPerTokenPaid[account]);

        bzrxRewardsEarned = vestedBalance
            .mul(bzrxPerTokenUnpaid)
            .div(1e36)
            .add(bzrxRewards[account]);

        stableCoinRewardsEarned = vestedBalance
            .mul(stableCoinPerTokenUnpaid)
            .div(1e36)
            .add(stableCoinRewards[account]);

        bzrxRewardsVesting = vestingBalance
            .mul(bzrxPerTokenUnpaid)
            .div(1e36)
            .add(bzrxVesting[account]);

        stableCoinRewardsVesting = vestingBalance
            .mul(stableCoinPerTokenUnpaid)
            .div(1e36)
            .add(stableCoinVesting[account]);


        // add vested fees to rewards balances
        uint256 rewardsVested;
        uint256 _lastVestingSync = _vestingLastSync[account];

        if (_lastVestingSync != block.timestamp) {
            if (bzrxRewardsVesting != 0) {
                rewardsVested = _vestedBalance(
                    bzrxRewardsVesting,
                    _lastVestingSync,
                    block.timestamp
                );
                bzrxRewardsEarned += rewardsVested;
            }

            if (stableCoinRewardsVesting != 0) {
                rewardsVested = _vestedBalance(
                    stableCoinRewardsVesting,
                    _lastVestingSync,
                    block.timestamp
                );
                stableCoinRewardsEarned += rewardsVested;
            }

            if (_vBZRXBalance != 0) {
                // add vested BZRX to rewards balance
                rewardsVested = _vestedBalance(
                    _vBZRXBalance,
                    _lastVestingSync,
                    block.timestamp
                );
                bzrxRewardsEarned += rewardsVested;
            }
        }
    }

    // note: anyone can contribute rewards to the contract
    function addDirectRewards(
        address[] calldata accounts,
        uint256[] calldata bzrxAmounts,
        uint256[] calldata stableCoinAmounts)
        external
        checkPause
        returns (uint256 bzrxTotal, uint256 stableCoinTotal)
    {
        require(accounts.length == bzrxAmounts.length && accounts.length == stableCoinAmounts.length, "count mismatch");

        for (uint256 i = 0; i < accounts.length; i++) {
            bzrxRewards[accounts[i]] = bzrxRewards[accounts[i]].add(bzrxAmounts[i]);
            bzrxTotal = bzrxTotal.add(bzrxAmounts[i]);
            stableCoinRewards[accounts[i]] = stableCoinRewards[accounts[i]].add(stableCoinAmounts[i]);
            stableCoinTotal = stableCoinTotal.add(stableCoinAmounts[i]);
        }
        if (bzrxTotal != 0) {
            IERC20(BZRX).transferFrom(msg.sender, address(this), bzrxTotal);
        }
        if (stableCoinTotal != 0) {
            curve3Crv.transferFrom(msg.sender, address(this), stableCoinTotal);
        }
    }

    // note: anyone can contribute rewards to the contract
    function addRewards(
        uint256 newBZRX,
        uint256 newStableCoin)
        external
        checkPause
    {
        if (newBZRX != 0 || newStableCoin != 0) {
            _addRewards(newBZRX, newStableCoin);
            if (newBZRX != 0) {
                IERC20(BZRX).transferFrom(msg.sender, address(this), newBZRX);
            }
            if (newStableCoin != 0) {
                curve3Crv.transferFrom(msg.sender, address(this), newStableCoin);
            }
        }
    }

    function _addRewards(
        uint256 newBZRX,
        uint256 newStableCoin)
        internal
    {
        (vBZRXWeightStored, iBZRXWeightStored, LPTokenWeightStored) = getVariableWeights();

        uint256 totalTokens = totalSupplyStored();
        require(totalTokens != 0, "nothing staked");

        bzrxPerTokenStored = newBZRX
            .mul(1e36)
            .div(totalTokens)
            .add(bzrxPerTokenStored);

        stableCoinPerTokenStored = newStableCoin
            .mul(1e36)
            .div(totalTokens)
            .add(stableCoinPerTokenStored);

        lastRewardsAddTime = block.timestamp;

        emit AddRewards(
            msg.sender,
            newBZRX,
            newStableCoin
        );
    }

    function getVariableWeights()
        public
        view
        returns (uint256 vBZRXWeight, uint256 iBZRXWeight, uint256 LPTokenWeight)
    {
        uint256 totalVested = _vestedBalance(
            _startingVBZRXBalance,
            0,
            block.timestamp
        );

        vBZRXWeight = SafeMath.mul(_startingVBZRXBalance - totalVested, 1e18) // overflow not possible
            .div(_startingVBZRXBalance);

        iBZRXWeight = ILoanPool(iBZRX).tokenPrice();

        uint256 lpTokenSupply = _totalSupplyPerToken[LPToken];
        if (lpTokenSupply != 0) {
            // staked LP tokens are assumed to represent the total unstaked supply (circulated supply - staked BZRX)
            uint256 normalizedLPTokenSupply = initialCirculatingSupply +
                totalVested -
                _totalSupplyPerToken[BZRX];

            LPTokenWeight = normalizedLPTokenSupply
                .mul(1e18)
                .div(lpTokenSupply);
        }
    }

    function balanceOfByAsset(
        address token,
        address account)
        public
        view
        returns (uint256 balance)
    {
        balance = _balancesPerToken[token][account];
    }

    function balanceOfByAssets(
        address account)
        external
        view
        returns (
            uint256 bzrxBalance,
            uint256 iBZRXBalance,
            uint256 vBZRXBalance,
            uint256 LPTokenBalance
        )
    {
        return (
            balanceOfByAsset(BZRX, account),
            balanceOfByAsset(iBZRX, account),
            balanceOfByAsset(vBZRX, account),
            balanceOfByAsset(LPToken, account)
        );
    }

    function balanceOfStored(
        address account)
        public
        view
        returns (uint256 vestedBalance, uint256 vestingBalance)
    {
        vestingBalance = _balancesPerToken[vBZRX][account]
                .mul(vBZRXWeightStored)
                .div(1e18);

        vestedBalance = _balancesPerToken[BZRX][account];

        vestedBalance = _balancesPerToken[iBZRX][account]
            .mul(iBZRXWeightStored)
            .div(1e18)
            .add(vestedBalance);

        vestedBalance = _balancesPerToken[LPToken][account]
            .mul(LPTokenWeightStored)
            .div(1e18)
            .add(vestedBalance);
    }

    function delegateBalanceOf(
        address account)
        public
        view
        returns (uint256 totalVotes)
    {
        uint256 vBZRXBalance = _balancesPerToken[vBZRX][account];
        if (vBZRXBalance != 0) {
            // staked vBZRX counts has 1/2 a vote, that's prorated based on total vested
            totalVotes = vBZRXBalance
                .mul(_startingVBZRXBalance -
                    _vestedBalance( // overflow not possible
                        _startingVBZRXBalance,
                        0,
                        block.timestamp
                    )
                ).div(_startingVBZRXBalance) / 2;

            // user is attributed a staked balance of vested BZRX, from their last update to the present
            totalVotes = _vestedBalance(
                vBZRXBalance,
                _vestingLastSync[account],
                block.timestamp
            ).add(totalVotes);
        }

        totalVotes = _balancesPerToken[BZRX][account]
            .add(bzrxRewards[account]) // unclaimed BZRX rewards count as votes
            .add(totalVotes);

        totalVotes = _balancesPerToken[iBZRX][account]
            .mul(ILoanPool(iBZRX).tokenPrice())
            .div(1e18)
            .add(totalVotes);

        // LPToken votes are measured based on amount of underlying BZRX staked
        totalVotes = IERC20(BZRX).balanceOf(LPToken)
            .mul(_balancesPerToken[LPToken][account])
            .div(IERC20(LPToken).totalSupply())
            .add(totalVotes);
    }

    function totalSupplyByAsset(
        address token)
        external
        view
        returns (uint256)
    {
        return _totalSupplyPerToken[token];
    }

    function totalSupplyStored()
        public
        view
        returns (uint256 supply)
    {
        supply = _totalSupplyPerToken[vBZRX]
            .mul(vBZRXWeightStored)
            .div(1e18);

        supply = _totalSupplyPerToken[BZRX]
            .add(supply);

        supply = _totalSupplyPerToken[iBZRX]
            .mul(iBZRXWeightStored)
            .div(1e18)
            .add(supply);

        supply = _totalSupplyPerToken[LPToken]
            .mul(LPTokenWeightStored)
            .div(1e18)
            .add(supply);
    }

    function _vestedBalance(
        uint256 tokenBalance,
        uint256 lastUpdate,
        uint256 vestingTimeNow)
        internal
        view
        returns (uint256 vested)
    {
        vestingTimeNow = vestingTimeNow.min256(block.timestamp);
        if (vestingTimeNow > lastUpdate) {
            if (vestingTimeNow <= vestingCliffTimestamp ||
                lastUpdate >= vestingEndTimestamp) {
                // time cannot be before vesting starts
                // OR all vested token has already been claimed
                return 0;
            }
            if (lastUpdate < vestingCliffTimestamp) {
                // vesting starts at the cliff timestamp
                lastUpdate = vestingCliffTimestamp;
            }
            if (vestingTimeNow > vestingEndTimestamp) {
                // vesting ends at the end timestamp
                vestingTimeNow = vestingEndTimestamp;
            }

            uint256 timeSinceClaim = vestingTimeNow.sub(lastUpdate);
            vested = tokenBalance.mul(timeSinceClaim) / vestingDurationAfterCliff; // will never divide by 0
        }
    }


    // Fee Conversion Logic //

    function sweepFees()
        public
        // sweepFeesByAsset() does checkPause
        returns (uint256 bzrxRewards, uint256 crv3Rewards)
    {
        return sweepFeesByAsset(currentFeeTokens);
    }

    function sweepFeesWithGasToken(
        address gasTokenUser)
        public
        // sweepFeesByAsset() does checkPause
        usesGasToken(gasTokenUser)
        returns (uint256 bzrxRewards, uint256 crv3Rewards)
    {
        return sweepFeesByAsset(currentFeeTokens);
    }

    function sweepFeesByAsset(
        address[] memory assets)
        public
        checkPause
        onlyEOA
        returns (uint256 bzrxRewards, uint256 crv3Rewards)
    {
        uint256[] memory amounts = _withdrawFees(assets);
        _convertFees(assets, amounts);
        (bzrxRewards, crv3Rewards) = _distributeFees();
    }

    function sweepFeesByAssetWithGasToken(
        address[] memory assets,
        address gasTokenUser)
        public
        // sweepFeesByAsset() does checkPause
        usesGasToken(gasTokenUser)
        returns (uint256 bzrxRewards, uint256 crv3Rewards)
    {
        return sweepFeesByAsset(assets);
    }

    function _withdrawFees(
        address[] memory assets)
        internal
        returns (uint256[] memory)
    {
        uint256[] memory amounts = bZx.withdrawFees(assets, address(this), IBZxPartial.FeeClaimType.All);

        for (uint256 i = 0; i < assets.length; i++) {
            stakingRewards[assets[i]] = stakingRewards[assets[i]]
                .add(amounts[i]);
        }

        emit WithdrawFees(
            msg.sender
        );

        return amounts;
    }

    function _convertFees(
        address[] memory assets,
        uint256[] memory amounts)
        internal
        returns (uint256 bzrxOutput, uint256 crv3Output)
    {
        require(assets.length == amounts.length, "count mismatch");
 
        IPriceFeeds priceFeeds = IPriceFeeds(bZx.priceFeeds());
        (uint256 bzrxRate,) = priceFeeds.queryRate(
            BZRX,
            WETH
        );
        uint256 maxDisagreement = maxUniswapDisagreement;

        address asset;
        uint256 daiAmount;
        uint256 usdcAmount;
        uint256 usdtAmount;
        for (uint256 i = 0; i < assets.length; i++) {
            asset = assets[i];
            if (asset == BZRX) {
                continue;
            } else if (asset == DAI) {
                daiAmount = daiAmount.add(amounts[i]);
                continue;
            } else if (asset == USDC) {
                usdcAmount = usdcAmount.add(amounts[i]);
                continue;
            } else if (asset == USDT) {
                usdtAmount = usdtAmount.add(amounts[i]);
                continue;
            }

            if (amounts[i] != 0) {
                bzrxOutput += _convertFeeWithUniswap(asset, amounts[i], priceFeeds, bzrxRate, maxDisagreement);
            }
        }
        if (bzrxOutput != 0) {
            stakingRewards[BZRX] += bzrxOutput;
        }

        if (daiAmount != 0 || usdcAmount != 0 || usdtAmount != 0) {
            crv3Output = _convertFeesWithCurve(
                daiAmount,
                usdcAmount,
                usdtAmount
            );
            stakingRewards[address(curve3Crv)] += crv3Output;
        }

        emit ConvertFees(
            msg.sender,
            bzrxOutput,
            crv3Output
        );
    }

    function _distributeFees()
        internal
        returns (uint256 bzrxRewards, uint256 crv3Rewards)
    {
        bzrxRewards = stakingRewards[BZRX];
        crv3Rewards = stakingRewards[address(curve3Crv)];
        if (bzrxRewards != 0 || crv3Rewards != 0) {
            address _fundsWallet = fundsWallet;
            uint256 rewardAmount;
            uint256 callerReward;
            if (bzrxRewards != 0) {
                stakingRewards[BZRX] = 0;

                rewardAmount = bzrxRewards
                    .mul(rewardPercent)
                    .div(1e20);
                IERC20(BZRX).transfer(
                    _fundsWallet,
                    bzrxRewards - rewardAmount
                );
                bzrxRewards = rewardAmount;

                callerReward = bzrxRewards / callerRewardDivisor;
                IERC20(BZRX).transfer(
                    msg.sender,
                    callerReward
                );
                bzrxRewards = bzrxRewards
                    .sub(callerReward);
            }
            if (crv3Rewards != 0) {
                stakingRewards[address(curve3Crv)] = 0;

                rewardAmount = crv3Rewards
                    .mul(rewardPercent)
                    .div(1e20);
                curve3Crv.transfer(
                    _fundsWallet,
                    crv3Rewards - rewardAmount
                );
                crv3Rewards = rewardAmount;

                callerReward = crv3Rewards / callerRewardDivisor;
                curve3Crv.transfer(
                    msg.sender,
                    callerReward
                );
                crv3Rewards = crv3Rewards
                    .sub(callerReward);
            }

            _addRewards(bzrxRewards, crv3Rewards);
        }

        emit DistributeFees(
            msg.sender,
            bzrxRewards,
            crv3Rewards
        );
    }

    function _convertFeeWithUniswap(
        address asset,
        uint256 amount,
        IPriceFeeds priceFeeds,
        uint256 bzrxRate,
        uint256 maxDisagreement)
        internal
        returns (uint256 returnAmount)
    {
        uint256 stakingReward = stakingRewards[asset];
        if (stakingReward != 0) {
            if (amount > stakingReward) {
                amount = stakingReward;
            }
            stakingRewards[asset] = stakingReward
                .sub(amount);

            uint256[] memory amounts = uniswapRouter.swapExactTokensForTokens(
                amount,
                1, // amountOutMin
                swapPaths[asset],
                address(this),
                block.timestamp
            );

            returnAmount = amounts[amounts.length - 1];

            // will revert if disagreement found
            _checkUniDisagreement(
                asset,
                amount,
                returnAmount,
                priceFeeds,
                bzrxRate,
                maxDisagreement
            );
        }
    }

    function _convertFeesWithCurve(
        uint256 daiAmount,
        uint256 usdcAmount,
        uint256 usdtAmount)
        internal
        returns (uint256 returnAmount)
    {
        uint256[3] memory curveAmounts;
        uint256 curveTotal;
        uint256 stakingReward;

        if (daiAmount != 0) {
            stakingReward = stakingRewards[DAI];
            if (stakingReward != 0) {
                if (daiAmount > stakingReward) {
                    daiAmount = stakingReward;
                }
                stakingRewards[DAI] = stakingReward
                    .sub(daiAmount);
                curveAmounts[0] = daiAmount;
                curveTotal = daiAmount;
            }
        }
        if (usdcAmount != 0) {
            stakingReward = stakingRewards[USDC];
            if (stakingReward != 0) {
                if (usdcAmount > stakingReward) {
                    usdcAmount = stakingReward;
                }
                stakingRewards[USDC] = stakingReward
                    .sub(usdcAmount);
                curveAmounts[1] = usdcAmount;
                curveTotal = curveTotal.add(usdcAmount);
            }
        }
        if (usdtAmount != 0) {
            stakingReward = stakingRewards[USDT];
            if (stakingReward != 0) {
                if (usdtAmount > stakingReward) {
                    usdtAmount = stakingReward;
                }
                stakingRewards[USDT] = stakingReward
                    .sub(usdtAmount);
                curveAmounts[2] = usdtAmount;
                curveTotal = curveTotal.add(usdtAmount);
            }
        }

        uint256 beforeBalance = curve3Crv.balanceOf(address(this));
        curve3pool.add_liquidity(curveAmounts, 0);

        returnAmount = curve3Crv.balanceOf(address(this)) - beforeBalance;

        // will revert if disagreement found
        _checkCurveDisagreement(
            curveTotal,
            returnAmount,
            maxCurveDisagreement
        );
    }    

    function _checkUniDisagreement(
        address asset,
        uint256 assetAmount,
        uint256 bzrxAmount,
        IPriceFeeds priceFeeds,
        uint256 bzrxRate,
        uint256 maxDisagreement)
        internal
        view
    {
        (uint256 rate, uint256 precision) = priceFeeds.queryRate(
            asset,
            WETH
        );

        rate = rate
            .mul(1e36)
            .div(precision)
            .div(bzrxRate);

        uint256 sourceToDestSwapRate = bzrxAmount
            .mul(1e18)
            .div(assetAmount);

        uint256 spreadValue = sourceToDestSwapRate > rate ?
            sourceToDestSwapRate - rate :
            rate - sourceToDestSwapRate;

        if (spreadValue != 0) {
            spreadValue = spreadValue
                .mul(1e20)
                .div(sourceToDestSwapRate);

            require(
                spreadValue <= maxDisagreement,
                "price disagreement"
            );
        }
    }

    function _checkCurveDisagreement(
        uint256 sendAmount, // deposit tokens
        uint256 actualReturn, // returned lp token
        uint256 maxDisagreement)
        internal
        view
    {
        uint256 expectedReturn = sendAmount
            .mul(1e18)
            .div(curve3pool.get_virtual_price());

        uint256 spreadValue = actualReturn > expectedReturn ?
            actualReturn - expectedReturn :
            expectedReturn - actualReturn;

        if (spreadValue != 0) {
            spreadValue = spreadValue
                .mul(1e20)
                .div(actualReturn);

            require(
                spreadValue <= maxDisagreement,
                "price disagreement"
            );
        }
    }

    // OnlyOwner functions

    function pause()
        external
        onlyOwner
    {
        isPaused = true;
    }

    function unPause()
        external
        onlyOwner
    {
        isPaused = false;
    }

    function setFundsWallet(
        address _fundsWallet)
        external
        onlyOwner
    {
        fundsWallet = _fundsWallet;
    }

    function setFeeTokens(
        address[] calldata tokens)
        external
        onlyOwner
    {
        currentFeeTokens = tokens;
    }

    // path should start with the asset to swap and end with BZRX
    // only one path allowed per asset
    // ex: asset -> WETH -> BZRX
    function setPaths(
        address[][] calldata paths)
        external
        onlyOwner
    {
        address[] memory path;
        for (uint256 i = 0; i < paths.length; i++) {
            path = paths[i];
            require(path.length >= 2 &&
                path[0] != path[path.length - 1] &&
                path[path.length - 1] == BZRX,
                "invalid path"
            );
            
            // check that the path exists
            uint256[] memory amountsOut = uniswapRouter.getAmountsOut(1e10, path);
            require(amountsOut[amountsOut.length - 1] != 0, "path does not exist");
            
            swapPaths[path[0]] = path;
            setUniswapApproval(IERC20(path[0]));
        }
    }

    function setUniswapApproval(
        IERC20 asset)
        public
        onlyOwner
    {
        asset.safeApprove(address(uniswapRouter), 0);
        asset.safeApprove(address(uniswapRouter), uint256(-1));
    }

    function setCurveApproval()
        external
        onlyOwner
    {
        IERC20(DAI).safeApprove(address(curve3pool), 0);
        IERC20(DAI).safeApprove(address(curve3pool), uint256(-1));
        IERC20(USDC).safeApprove(address(curve3pool), 0);
        IERC20(USDC).safeApprove(address(curve3pool), uint256(-1));
        IERC20(USDT).safeApprove(address(curve3pool), 0);
        IERC20(USDT).safeApprove(address(curve3pool), uint256(-1));
    }

    function setRewardPercent(
        uint256 _rewardPercent)
        external
        onlyOwner
    {
        require(_rewardPercent <= 1e20, "value too high");
        rewardPercent = _rewardPercent;
    }

    function setMaxUniswapDisagreement(
        uint256 _maxUniswapDisagreement)
        external
        onlyOwner
    {
        require(_maxUniswapDisagreement != 0, "invalid param");
        maxUniswapDisagreement = _maxUniswapDisagreement;
    }

    function setMaxCurveDisagreement(
        uint256 _maxCurveDisagreement)
        external
        onlyOwner
    {
        require(_maxCurveDisagreement != 0, "invalid param");
        maxCurveDisagreement = _maxCurveDisagreement;
    }

    function setCallerRewardDivisor(
        uint256 _callerRewardDivisor)
        external
        onlyOwner
    {
        require(_callerRewardDivisor != 0, "invalid param");
        callerRewardDivisor = _callerRewardDivisor;
    }
}

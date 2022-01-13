/**
 * Copyright 2017-2021, bZxDao. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "../StakingStateV2.sol";
import "./StakingPausableGuardian.sol";
import "../../farm/interfaces/IMasterChefSushi.sol";
import "../delegation/VoteDelegator.sol";
import "../../interfaces/IVestingToken.sol";
import "./Common.sol";

contract StakeUnstake is Common {
    function initialize(address target) external onlyOwner {
        _setTarget(this.pendingCrvRewards.selector, target);
        _setTarget(this.stake.selector, target);
        _setTarget(this.unstake.selector, target);
        _setTarget(this.claim.selector, target);
        _setTarget(this.claimAltRewards.selector, target);
        _setTarget(this.claimBzrx.selector, target);
        _setTarget(this.claim3Crv.selector, target);
        _setTarget(this.claimSushi.selector, target);
        _setTarget(this.claimCrv.selector, target);
        _setTarget(this.earned.selector, target);
        _setTarget(this.addAltRewards.selector, target);
        _setTarget(this.balanceOfByAsset.selector, target);
        _setTarget(this.balanceOfByAssets.selector, target);
        _setTarget(this.balanceOfStored.selector, target);
        _setTarget(this.vestedBalanceForAmount.selector, target);
        _setTarget(this.exit.selector, target);
    }

    function _pendingSushiRewards(address _user) internal view returns (uint256) {
        uint256 pendingSushi = IMasterChefSushi(SUSHI_MASTERCHEF).pendingSushi(OOKI_ETH_SUSHI_MASTERCHEF_PID, address(this));

        uint256 totalSupply = _totalSupplyPerToken[OOKI_ETH_LP];
        return _pendingAltRewards(SUSHI, _user, balanceOfByAsset(OOKI_ETH_LP, _user), totalSupply != 0 ? pendingSushi.mul(1e12).div(totalSupply) : 0);
    }

    function pendingCrvRewards(address account) external returns (uint256) {
        (uint256 bzrxRewardsEarned, uint256 stableCoinRewardsEarned, uint256 bzrxRewardsVesting, uint256 stableCoinRewardsVesting) = _earned(
            account,
            bzrxPerTokenStored,
            stableCoinPerTokenStored
        );

        (, stableCoinRewardsEarned) = _syncVesting(account, bzrxRewardsEarned, stableCoinRewardsEarned, bzrxRewardsVesting, stableCoinRewardsVesting);
        return _pendingCrvRewards(account, stableCoinRewardsEarned);
    }

    function _pendingCrvRewards(address _user, uint256 stableCoinRewardsEarned) internal returns (uint256) {
        uint256 totalSupply = curve3PoolGauge.balanceOf(address(this));
        uint256 pendingCrv = curve3PoolGauge.claimable_tokens(address(this));
        return _pendingAltRewards(CRV, _user, stableCoinRewardsEarned, (totalSupply != 0) ? pendingCrv.mul(1e12).div(totalSupply) : 0);
    }

    function _pendingAltRewards(
        address token,
        address _user,
        uint256 userSupply,
        uint256 extraRewardsPerShare
    ) internal view returns (uint256) {
        uint256 _altRewardsPerShare = altRewardsPerShare[token].add(extraRewardsPerShare);
        if (_altRewardsPerShare == 0) return 0;

        IStakingV2.AltRewardsUserInfo memory altRewardsUserInfo = userAltRewardsPerShare[_user][token];
        return altRewardsUserInfo.pendingRewards.add((_altRewardsPerShare.sub(altRewardsUserInfo.rewardsPerShare)).mul(userSupply).div(1e12));
    }

    function _depositToSushiMasterchef(uint256 amount) internal {
        uint256 sushiBalanceBefore = IERC20(SUSHI).balanceOf(address(this));
        IMasterChefSushi(SUSHI_MASTERCHEF).deposit(OOKI_ETH_SUSHI_MASTERCHEF_PID, amount);
        uint256 sushiRewards = IERC20(SUSHI).balanceOf(address(this)) - sushiBalanceBefore;
        if (sushiRewards != 0) {
            _addAltRewards(SUSHI, sushiRewards);
        }
    }

    function _withdrawFromSushiMasterchef(uint256 amount) internal {
        uint256 sushiBalanceBefore = IERC20(SUSHI).balanceOf(address(this));
        IMasterChefSushi(SUSHI_MASTERCHEF).withdraw(OOKI_ETH_SUSHI_MASTERCHEF_PID, amount);
        uint256 sushiRewards = IERC20(SUSHI).balanceOf(address(this)) - sushiBalanceBefore;
        if (sushiRewards != 0) {
            _addAltRewards(SUSHI, sushiRewards);
        }
    }

    function _depositTo3Pool(uint256 amount) internal {
        if (amount == 0) curve3PoolGauge.deposit(curve3Crv.balanceOf(address(this)));

        // Trigger claim rewards from curve pool
        uint256 crvBalanceBefore = IERC20(CRV).balanceOf(address(this));
        curveMinter.mint(address(curve3PoolGauge));
        uint256 crvBalanceAfter = IERC20(CRV).balanceOf(address(this)) - crvBalanceBefore;
        if (crvBalanceAfter != 0) {
            _addAltRewards(CRV, crvBalanceAfter);
        }
    }

    function _withdrawFrom3Pool(uint256 amount) internal {
        if (amount != 0) curve3PoolGauge.withdraw(amount);

        //Trigger claim rewards from curve pool
        uint256 crvBalanceBefore = IERC20(CRV).balanceOf(address(this));
        curveMinter.mint(address(curve3PoolGauge));
        uint256 crvBalanceAfter = IERC20(CRV).balanceOf(address(this)) - crvBalanceBefore;
        if (crvBalanceAfter != 0) {
            _addAltRewards(CRV, crvBalanceAfter);
        }
    }

    

    function stake(address[] memory tokens, uint256[] memory values) public pausable updateRewards(msg.sender) {
        require(tokens.length == values.length, "count mismatch");
        VoteDelegator _voteDelegator = VoteDelegator(voteDelegator);
        address currentDelegate = _voteDelegator.delegates(msg.sender);

        ProposalState memory _proposalState = _getProposalState();
        uint256 votingBalanceBefore = _votingFromStakedBalanceOf(msg.sender, _proposalState, true);
        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            require(token == OOKI || token == vBZRX || token == iOOKI || token == OOKI_ETH_LP, "invalid token");

            uint256 stakeAmount = values[i];
            if (stakeAmount == 0) {
                continue;
            }
            uint256 pendingBefore = (token == OOKI_ETH_LP) ? _pendingSushiRewards(msg.sender) : 0;
            _balancesPerToken[token][msg.sender] = _balancesPerToken[token][msg.sender].add(stakeAmount);
            _totalSupplyPerToken[token] = _totalSupplyPerToken[token].add(stakeAmount);

            IERC20(token).safeTransferFrom(msg.sender, address(this), stakeAmount);
            // Deposit to sushi masterchef
            if (token == OOKI_ETH_LP) {
                _depositToSushiMasterchef(IERC20(OOKI_ETH_LP).balanceOf(address(this)));

                userAltRewardsPerShare[msg.sender][SUSHI] = IStakingV2.AltRewardsUserInfo({rewardsPerShare: altRewardsPerShare[SUSHI], pendingRewards: pendingBefore});
            }

            emit Stake(msg.sender, token, currentDelegate, stakeAmount);
        }

        _voteDelegator.moveDelegatesByVotingBalance(votingBalanceBefore, _votingFromStakedBalanceOf(msg.sender, _proposalState, true), msg.sender);
    }

    function unstake(address[] memory tokens, uint256[] memory values) public pausable updateRewards(msg.sender) {
        require(tokens.length == values.length, "count mismatch");

        VoteDelegator _voteDelegator = VoteDelegator(voteDelegator);
        address currentDelegate = _voteDelegator.delegates(msg.sender);

        ProposalState memory _proposalState = _getProposalState();
        uint256 votingBalanceBefore = _votingFromStakedBalanceOf(msg.sender, _proposalState, true);

        for (uint256 i = 0; i < tokens.length; i++) {
            address token = tokens[i];
            require(token == OOKI || token == vBZRX || token == iOOKI || token == OOKI_ETH_LP, "invalid token");

            uint256 unstakeAmount = values[i];
            uint256 stakedAmount = _balancesPerToken[token][msg.sender];
            if (unstakeAmount == 0 || stakedAmount == 0) {
                continue;
            }
            if (unstakeAmount > stakedAmount) {
                unstakeAmount = stakedAmount;
            }

            uint256 pendingBefore = (token == OOKI_ETH_LP) ? _pendingSushiRewards(msg.sender) : 0;

            _balancesPerToken[token][msg.sender] = stakedAmount - unstakeAmount; // will not overflow
            _totalSupplyPerToken[token] = _totalSupplyPerToken[token] - unstakeAmount; // will not overflow

            if (token == OOKI && IERC20(OOKI).balanceOf(address(this)) < unstakeAmount) {
                // settle vested BZRX only if needed
                IVestingToken(vBZRX).claim();
                CONVERTER.convert(address(this), IERC20(BZRX).balanceOf(address(this)));
            }

            // Withdraw to sushi masterchef
            if (token == OOKI_ETH_LP) {
                _withdrawFromSushiMasterchef(unstakeAmount);

                userAltRewardsPerShare[msg.sender][SUSHI] = IStakingV2.AltRewardsUserInfo({rewardsPerShare: altRewardsPerShare[SUSHI], pendingRewards: pendingBefore});
            }
            IERC20(token).safeTransfer(msg.sender, unstakeAmount);

            emit Unstake(msg.sender, token, currentDelegate, unstakeAmount);
        }
        _voteDelegator.moveDelegatesByVotingBalance(votingBalanceBefore, _votingFromStakedBalanceOf(msg.sender, _proposalState, true), msg.sender);
    }

    function claim(bool restake) external pausable updateRewards(msg.sender) returns (uint256 bzrxRewardsEarned, uint256 stableCoinRewardsEarned) {
        return _claim(restake);
    }

    function claimAltRewards() external pausable returns (uint256 sushiRewardsEarned, uint256 crvRewardsEarned) {
        sushiRewardsEarned = _claimSushi();
        crvRewardsEarned = _claimCrv();

        if (sushiRewardsEarned != 0) {
            emit ClaimAltRewards(msg.sender, SUSHI, sushiRewardsEarned);
        }
        if (crvRewardsEarned != 0) {
            emit ClaimAltRewards(msg.sender, CRV, crvRewardsEarned);
        }
    }

    function claimBzrx() external pausable updateRewards(msg.sender) returns (uint256 bzrxRewardsEarned) {
        bzrxRewardsEarned = _claimBzrx(false);

        emit Claim(msg.sender, bzrxRewardsEarned, 0);
    }

    function claim3Crv() external pausable updateRewards(msg.sender) returns (uint256 stableCoinRewardsEarned) {
        stableCoinRewardsEarned = _claim3Crv();

        emit Claim(msg.sender, 0, stableCoinRewardsEarned);
    }

    function claimSushi() external pausable returns (uint256 sushiRewardsEarned) {
        sushiRewardsEarned = _claimSushi();
        if (sushiRewardsEarned != 0) {
            emit ClaimAltRewards(msg.sender, SUSHI, sushiRewardsEarned);
        }
    }

    function claimCrv() external pausable returns (uint256 crvRewardsEarned) {
        crvRewardsEarned = _claimCrv();
        if (crvRewardsEarned != 0) {
            emit ClaimAltRewards(msg.sender, CRV, crvRewardsEarned);
        }
    }

    function _claim(bool restake) internal returns (uint256 bzrxRewardsEarned, uint256 stableCoinRewardsEarned) {
        bzrxRewardsEarned = _claimBzrx(restake);
        stableCoinRewardsEarned = _claim3Crv();

        emit Claim(msg.sender, bzrxRewardsEarned, stableCoinRewardsEarned);
    }

    function _claimBzrx(bool restake) internal returns (uint256 bzrxRewardsEarned) {
        ProposalState memory _proposalState = _getProposalState();
        uint256 votingBalanceBefore = _votingFromStakedBalanceOf(msg.sender, _proposalState, true);

        bzrxRewardsEarned = bzrxRewards[msg.sender];
        if (bzrxRewardsEarned != 0) {
            bzrxRewards[msg.sender] = 0;
            if (restake) {
                _restakeBZRX(msg.sender, bzrxRewardsEarned);
            } else {
                if (IERC20(OOKI).balanceOf(address(this)) < bzrxRewardsEarned) {
                    // settle vested BZRX only if needed
                    IVestingToken(vBZRX).claim();
                    CONVERTER.convert(address(this), IERC20(BZRX).balanceOf(address(this)));
                }

                IERC20(OOKI).transfer(msg.sender, bzrxRewardsEarned);
            }
        }
        VoteDelegator(voteDelegator).moveDelegatesByVotingBalance(votingBalanceBefore, _votingFromStakedBalanceOf(msg.sender, _proposalState, true), msg.sender);
    }

    function _claim3Crv() internal returns (uint256 stableCoinRewardsEarned) {
        stableCoinRewardsEarned = stableCoinRewards[msg.sender];
        if (stableCoinRewardsEarned != 0) {
            uint256 pendingCrv = _pendingCrvRewards(msg.sender, stableCoinRewardsEarned);
            uint256 curve3CrvBalance = curve3Crv.balanceOf(address(this));
            _withdrawFrom3Pool(stableCoinRewardsEarned);

            userAltRewardsPerShare[msg.sender][CRV] = IStakingV2.AltRewardsUserInfo({rewardsPerShare: altRewardsPerShare[CRV], pendingRewards: pendingCrv});

            stableCoinRewards[msg.sender] = 0;
            curve3Crv.transfer(msg.sender, stableCoinRewardsEarned);
        }
    }

    function _claimSushi() internal returns (uint256) {
        address _user = msg.sender;
        uint256 lptUserSupply = balanceOfByAsset(OOKI_ETH_LP, _user);

        //This will trigger claim rewards from sushi masterchef
        _depositToSushiMasterchef(IERC20(OOKI_ETH_LP).balanceOf(address(this)));

        uint256 pendingSushi = _pendingAltRewards(SUSHI, _user, lptUserSupply, 0);

        userAltRewardsPerShare[_user][SUSHI] = IStakingV2.AltRewardsUserInfo({rewardsPerShare: altRewardsPerShare[SUSHI], pendingRewards: 0});
        if (pendingSushi != 0) {
            IERC20(SUSHI).safeTransfer(_user, pendingSushi);
        }

        return pendingSushi;
    }

    function _claimCrv() internal returns (uint256) {
        address _user = msg.sender;

        _depositTo3Pool(0);
        (, uint256 stableCoinRewardsEarned, , ) = _earned(_user, bzrxPerTokenStored, stableCoinPerTokenStored);
        uint256 pendingCrv = _pendingCrvRewards(_user, stableCoinRewardsEarned);

        userAltRewardsPerShare[_user][CRV] = IStakingV2.AltRewardsUserInfo({rewardsPerShare: altRewardsPerShare[CRV], pendingRewards: 0});
        if (pendingCrv != 0) {
            IERC20(CRV).safeTransfer(_user, pendingCrv);
        }

        return pendingCrv;
    }

    function _restakeBZRX(address account, uint256 amount) internal {
        _balancesPerToken[OOKI][account] = _balancesPerToken[OOKI][account].add(amount);

        _totalSupplyPerToken[OOKI] = _totalSupplyPerToken[OOKI].add(amount);

        emit Stake(
            account,
            OOKI,
            account, //currentDelegate,
            amount
        );
    }

    modifier updateRewards(address account) {
        uint256 _bzrxPerTokenStored = bzrxPerTokenStored;
        uint256 _stableCoinPerTokenStored = stableCoinPerTokenStored;

        (uint256 bzrxRewardsEarned, uint256 stableCoinRewardsEarned, uint256 bzrxRewardsVesting, uint256 stableCoinRewardsVesting) = _earned(
            account,
            _bzrxPerTokenStored,
            _stableCoinPerTokenStored
        );
        bzrxRewardsPerTokenPaid[account] = _bzrxPerTokenStored;
        stableCoinRewardsPerTokenPaid[account] = _stableCoinPerTokenStored;

        // vesting amounts get updated before sync
        bzrxVesting[account] = bzrxRewardsVesting;
        stableCoinVesting[account] = stableCoinRewardsVesting;

        (bzrxRewards[account], stableCoinRewards[account]) = _syncVesting(account, bzrxRewardsEarned, stableCoinRewardsEarned, bzrxRewardsVesting, stableCoinRewardsVesting);

        vestingLastSync[account] = block.timestamp;

        _;
    }

    function earned(address account)
        external
         
        returns (
            uint256 bzrxRewardsEarned,
            uint256 stableCoinRewardsEarned,
            uint256 bzrxRewardsVesting,
            uint256 stableCoinRewardsVesting,
            uint256 sushiRewardsEarned
        )
    {
        (bzrxRewardsEarned, stableCoinRewardsEarned, bzrxRewardsVesting, stableCoinRewardsVesting) = _earned(account, bzrxPerTokenStored, stableCoinPerTokenStored);

        (bzrxRewardsEarned, stableCoinRewardsEarned) = _syncVesting(account, bzrxRewardsEarned, stableCoinRewardsEarned, bzrxRewardsVesting, stableCoinRewardsVesting);

        // discount vesting amounts for vesting time
        uint256 multiplier = vestedBalanceForAmount(1e36, 0, block.timestamp);
        bzrxRewardsVesting = bzrxRewardsVesting.sub(bzrxRewardsVesting.mul(multiplier).div(1e36));
        stableCoinRewardsVesting = stableCoinRewardsVesting.sub(stableCoinRewardsVesting.mul(multiplier).div(1e36));

        uint256 pendingSushi = IMasterChefSushi(SUSHI_MASTERCHEF).pendingSushi(OOKI_ETH_SUSHI_MASTERCHEF_PID, address(this));

        sushiRewardsEarned = _pendingAltRewards(
            SUSHI,
            account,
            balanceOfByAsset(OOKI_ETH_LP, account),
            (_totalSupplyPerToken[OOKI_ETH_LP] != 0) ? pendingSushi.mul(1e12).div(_totalSupplyPerToken[OOKI_ETH_LP]) : 0
        );
    }

    function _earned(
        address account,
        uint256 _bzrxPerToken,
        uint256 _stableCoinPerToken
    )
        internal
        
        returns (
            uint256 bzrxRewardsEarned,
            uint256 stableCoinRewardsEarned,
            uint256 bzrxRewardsVesting,
            uint256 stableCoinRewardsVesting
        )
    {
        uint256 bzrxPerTokenUnpaid = _bzrxPerToken.sub(bzrxRewardsPerTokenPaid[account]);
        uint256 stableCoinPerTokenUnpaid = _stableCoinPerToken.sub(stableCoinRewardsPerTokenPaid[account]);

        bzrxRewardsEarned = bzrxRewards[account];
        stableCoinRewardsEarned = stableCoinRewards[account];
        bzrxRewardsVesting = bzrxVesting[account];
        stableCoinRewardsVesting = stableCoinVesting[account];

        if (bzrxPerTokenUnpaid != 0 || stableCoinPerTokenUnpaid != 0) {
            uint256 value;
            uint256 multiplier;
            uint256 lastSync;

            (uint256 vestedBalance, uint256 vestingBalance) = balanceOfStored(account);
            value = vestedBalance.mul(bzrxPerTokenUnpaid);
            value /= 1e36;
            bzrxRewardsEarned = value.add(bzrxRewardsEarned);
            value = vestedBalance.mul(stableCoinPerTokenUnpaid);
            value /= 1e36;
            stableCoinRewardsEarned = value.add(stableCoinRewardsEarned);

            if (vestingBalance != 0 && bzrxPerTokenUnpaid != 0) {
                // add new vesting amount for BZRX
                value = vestingBalance.mul(bzrxPerTokenUnpaid);
                value /= 1e36;
                bzrxRewardsVesting = bzrxRewardsVesting.add(value);
                // true up earned amount to vBZRX vesting schedule
                lastSync = vestingLastSync[account];
                multiplier = vestedBalanceForAmount(1e36, 0, lastSync);
                value = value.mul(multiplier);
                value /= 1e36;
                bzrxRewardsEarned = bzrxRewardsEarned.add(value);
            }
            if (vestingBalance != 0 && stableCoinPerTokenUnpaid != 0) {
                
                // add new vesting amount for 3crv
                value = vestingBalance.mul(stableCoinPerTokenUnpaid);
                value /= 1e36;
                stableCoinRewardsVesting = stableCoinRewardsVesting.add(value);

                // true up earned amount to vBZRX vesting schedule
                if (lastSync == 0) {
                    lastSync = vestingLastSync[account];
                    multiplier = vestedBalanceForAmount(1e36, 0, lastSync);
                }
                value = value.mul(multiplier);
                value /= 1e36;
                stableCoinRewardsEarned = stableCoinRewardsEarned.add(value);
            }
        }
    }

    function _syncVesting(
        address account,
        uint256 bzrxRewardsEarned,
        uint256 stableCoinRewardsEarned,
        uint256 bzrxRewardsVesting,
        uint256 stableCoinRewardsVesting
    ) internal view returns (uint256, uint256) {
        uint256 lastVestingSync = vestingLastSync[account];

        if (lastVestingSync != block.timestamp) {
            uint256 rewardsVested;
            uint256 multiplier = vestedBalanceForAmount(1e36, lastVestingSync, block.timestamp);

            if (bzrxRewardsVesting != 0) {
                rewardsVested = bzrxRewardsVesting.mul(multiplier).div(1e36);
                bzrxRewardsEarned += rewardsVested;
            }

            if (stableCoinRewardsVesting != 0) {
                rewardsVested = stableCoinRewardsVesting.mul(multiplier).div(1e36);
                stableCoinRewardsEarned += rewardsVested;
            }

            // OOKI is 10x BZRX
            uint256 vBZRXBalance = _balancesPerToken[vBZRX][account];
            if (vBZRXBalance != 0) {
                // add vested OOKI to rewards balance
                rewardsVested = vBZRXBalance.mul(multiplier)
                    .div(1e35);  // OOKI is 10x BZRX
                bzrxRewardsEarned += rewardsVested;
            }
        }

        return (bzrxRewardsEarned, stableCoinRewardsEarned);
    }

    function addAltRewards(address token, uint256 amount) public {
        if (amount != 0) {
            _addAltRewards(token, amount);
            IERC20(token).transferFrom(msg.sender, address(this), amount);
        }
    }

    function _addAltRewards(address token, uint256 amount) internal {
        address poolAddress = token == SUSHI ? OOKI_ETH_LP : token;

        uint256 totalSupply = (token == CRV) ? curve3PoolGauge.balanceOf(address(this)) : _totalSupplyPerToken[poolAddress];
        require(totalSupply != 0, "no deposits");

        altRewardsPerShare[token] = altRewardsPerShare[token].add(amount.mul(1e12).div(totalSupply));

        emit AddAltRewards(msg.sender, token, amount);
    }

    function balanceOfByAsset(address token, address account) public view returns (uint256 balance) {
        balance = _balancesPerToken[token][account];
    }

    function balanceOfByAssets(address account)
        external
        view
        returns (
            uint256 bzrxBalance,
            uint256 iBZRXBalance,
            uint256 vBZRXBalance,
            uint256 LPTokenBalance
        )
    {
        return (balanceOfByAsset(OOKI, account), balanceOfByAsset(iOOKI, account), balanceOfByAsset(vBZRX, account), balanceOfByAsset(OOKI_ETH_LP, account));
    }

    function balanceOfStored(address account) public view returns (uint256 vestedBalance, uint256 vestingBalance) {
        uint256 balance = _balancesPerToken[vBZRX][account];
        if (balance != 0) {
            vestingBalance = balance.mul(vBZRXWeightStored)
                .div(1e17); // OOKI is 10x BZRX
        }

        vestedBalance = _balancesPerToken[OOKI][account];

        balance = _balancesPerToken[iOOKI][account];
        if (balance != 0) {
            vestedBalance = balance.mul(iBZRXWeightStored).div(1e50).add(vestedBalance);
        }

        balance = _balancesPerToken[OOKI_ETH_LP][account];
        if (balance != 0) {
            vestedBalance = balance.mul(LPTokenWeightStored).div(1e18).add(vestedBalance);
        }
    }


    function exit()
        public
        // unstake() does check pausable
    {
        address[] memory tokens = new address[](4);
        uint256[] memory values = new uint256[](4);
        tokens[0] = iOOKI;
        tokens[1] = OOKI_ETH_LP;
        tokens[2] = vBZRX;
        tokens[3] = OOKI;
        values[0] = uint256(-1);
        values[1] = uint256(-1);
        values[2] = uint256(-1);
        values[3] = uint256(-1);
        
        unstake(tokens, values); // calls updateRewards
        _claim(false);
    }

    
}

/**
 * Copyright 2017-2020, bZeroX, LLC <https://bzx.network/>. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;
pragma experimental ABIEncoderV2;

import "./StakingState.sol";
import "./StakingConstants.sol";
import "../farm/interfaces/IMasterChefSushi.sol";
import "../governance/PausableGuardian.sol";

contract StakingAdminSettings is StakingState, StakingConstants, PausableGuardian {
    // Withdraw all from sushi masterchef
    function exitSushi() external onlyOwner {
        IMasterChefSushi chef = IMasterChefSushi(SUSHI_MASTERCHEF);
        uint256 balance = chef.userInfo(BZRX_ETH_SUSHI_MASTERCHEF_PID, address(this)).amount;
        chef.withdraw(BZRX_ETH_SUSHI_MASTERCHEF_PID, balance);
    }

    // OnlyOwner functions

    function togglePause(bool _isPaused) external onlyOwner {
        isPaused = _isPaused;
    }

    function setFundsWallet(address _fundsWallet) external onlyOwner {
        fundsWallet = _fundsWallet;
    }

    function setGovernor(address _governor) external onlyOwner {
        governor = _governor;
    }

    function setFeeTokens(address[] calldata tokens) external onlyOwner {
        currentFeeTokens = tokens;
    }

    function setRewardPercent(uint256 _rewardPercent) external onlyOwner {
        require(_rewardPercent <= 1e20, "value too high");
        rewardPercent = _rewardPercent;
    }

    function setMaxUniswapDisagreement(uint256 _maxUniswapDisagreement) external onlyOwner {
        require(_maxUniswapDisagreement != 0, "invalid param");
        maxUniswapDisagreement = _maxUniswapDisagreement;
    }

    function setMaxCurveDisagreement(uint256 _maxCurveDisagreement) external onlyOwner {
        require(_maxCurveDisagreement != 0, "invalid param");
        maxCurveDisagreement = _maxCurveDisagreement;
    }

    function setCallerRewardDivisor(uint256 _callerRewardDivisor) external onlyOwner {
        require(_callerRewardDivisor != 0, "invalid param");
        callerRewardDivisor = _callerRewardDivisor;
    }

    function setInitialAltRewardsPerShare() external onlyOwner {
        uint256 index = altRewardsRounds[SUSHI].length;
        if (index == 0) {
            return;
        }

        altRewardsPerShare[SUSHI] = altRewardsRounds[SUSHI][index - 1];
    }

    function setApprovals(
        address _token,
        address _spender,
        uint256 _value
    ) external onlyOwner {
        IERC20(_token).approve(_spender, _value);
    }

    // Migrate lp token to another lp contract. 
    function migrateSLP() public onlyOwner {
        require(address(converter) != address(0), "no converter");

        IMasterChefSushi chef = IMasterChefSushi(SUSHI_MASTERCHEF);
        uint256 balance = chef.userInfo(BZRX_ETH_SUSHI_MASTERCHEF_PID, address(this)).amount;
        chef.withdraw(BZRX_ETH_SUSHI_MASTERCHEF_PID, balance);

        // migrating SLP
        IERC20(LPTokenBeforeMigration).approve(SUSHI_ROUTER, balance);
        (uint256 WETHBalance, uint256 BZRXBalance) = IUniswapV2Router(SUSHI_ROUTER).removeLiquidity(WETH, BZRX, balance, 1, 1, address(this), block.timestamp);

        uint256 totalBZRXBalance = IERC20(BZRX).balanceOf(address(this));
        IERC20(BZRX).approve(address(converter), 2**256 -1); // this max approval will be used to convert vested bzrx to ooki
        // this will convert and current BZRX on a contract as well
        IBZRXv2Converter(converter).convert(address(this), totalBZRXBalance);

        IERC20(WETH).approve(SUSHI_ROUTER, WETHBalance);
        IERC20(OOKI).approve(SUSHI_ROUTER, BZRXBalance);

        IUniswapV2Router(SUSHI_ROUTER).addLiquidity(WETH, OOKI, WETHBalance, BZRXBalance, 1, 1, address(this), block.timestamp);


        
        // migrating BZRX balances to OOKI
        _totalSupplyPerToken[OOKI] = _totalSupplyPerToken[BZRX];
        _totalSupplyPerToken[BZRX] = 0;

        _totalSupplyPerToken[LPToken] = _totalSupplyPerToken[LPTokenBeforeMigration];
        _totalSupplyPerToken[LPTokenBeforeMigration] = 0;

        altRewardsPerShare[OOKI] = altRewardsPerShare[BZRX];
        altRewardsPerShare[BZRX] = 0;

        bzrxRewardsPerTokenPaid[OOKI] = bzrxRewardsPerTokenPaid[BZRX];
        bzrxRewardsPerTokenPaid[BZRX] = 0;

        bzrxRewards[OOKI] = bzrxRewards[BZRX];
        bzrxRewards[BZRX] = 0;
    }

    function setConverter(IBZRXv2Converter _converter) public onlyOwner {
        converter = _converter;
    }
}

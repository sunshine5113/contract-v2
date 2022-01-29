/**
 * Copyright 2017-2021, bZxDao. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin-4.3.2/token/ERC20/IERC20.sol";
import "../proxies/0_8/Upgradeable_0_8.sol";
import "./interfaces/IUniswapV2Router.sol";
import "../../interfaces/IBZx.sol";
import "@celer/contracts/interfaces/IBridge.sol";

contract FeeExtractAndDistribute_Arbitrum is Upgradeable_0_8 {
    IBZx public constant bZx = IBZx(0x37407F3178ffE07a6cF5C847F8f680FEcf319FAB);

    address public constant ETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    uint64 public constant DEST_CHAINID = 137; //send to polygon

    IUniswapV2Router public constant swapsRouterV2 =
        IUniswapV2Router(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    address internal constant ZERO_ADDRESS = address(0);

    bool public isPaused;

    mapping(address => uint256) public exportedFees;

    address[] public currentFeeTokens;

    address payable public treasuryWallet;

    address public bridge; //bridging contract

    event ExtractAndDistribute(uint256 amountTreasury, uint256 amountStakers);

    event AssetSwap(
        address indexed sender,
        address indexed srcAsset,
        address indexed dstAsset,
        uint256 srcAmount,
        uint256 dstAmount
    );

    modifier onlyEOA() {
        require(msg.sender == tx.origin, "unauthorized");
        _;
    }

    modifier checkPause() {
        require(!isPaused || msg.sender == owner(), "paused");
        _;
    }

    function sweepFees() public // sweepFeesByAsset() does checkPause
    {
        sweepFeesByAsset(currentFeeTokens);
    }

    function sweepFeesByAsset(address[] memory assets)
        public
        checkPause
        onlyEOA
    {
        _extractAndDistribute(assets);
    }

    function _extractAndDistribute(address[] memory assets) internal {
        uint256[] memory amounts = bZx.withdrawFees(
            assets,
            address(this),
            IBZx.FeeClaimType.All
        );

        for (uint256 i = 0; i < assets.length; i++) {
            exportedFees[assets[i]] += amounts[i];
        }

        uint256 usdcOutput = exportedFees[USDC];
        exportedFees[USDC] = 0;

        address asset;
        uint256 amount;
        for (uint256 i = 0; i < assets.length; i++) {
            asset = assets[i];
            if (asset == USDC) continue; //USDC already accounted for
            amount = exportedFees[asset];
            exportedFees[asset] = 0;

            if (amount != 0) {
                usdcOutput += asset == ETH
                    ? _swapWithPair([asset, USDC], amount)
                    : _swapWithPair([asset, ETH, USDC], amount); //builds route for all tokens to route through ETH
            }
        }

        if (usdcOutput != 0) {
            _bridgeFeesAndDistribute(); //bridges fees to Ethereum to be distributed to stakers
            emit ExtractAndDistribute(usdcOutput, 0); //for tracking distribution amounts
        }
    }

    function _swapWithPair(address[2] memory route, uint256 inAmount)
        internal
        returns (uint256 returnAmount)
    {
        address[] memory path = new address[](2);
        path[0] = route[0];
        path[1] = route[1];
        uint256[] memory amounts = swapsRouterV2.swapExactTokensForTokens(
            inAmount,
            1, // amountOutMin
            path,
            address(this),
            block.timestamp
        );

        returnAmount = amounts[1];
    }

    function _swapWithPair(address[3] memory route, uint256 inAmount)
        internal
        returns (uint256 returnAmount)
    {
        address[] memory path = new address[](3);
        path[0] = route[0];
        path[1] = route[1];
        path[2] = route[2];
        uint256[] memory amounts = swapsRouterV2.swapExactTokensForTokens(
            inAmount,
            1, // amountOutMin
            path,
            address(this),
            block.timestamp
        );

        returnAmount = amounts[2];
    }

    function _bridgeFeesAndDistribute() internal {
        IBridge(bridge).send(
            treasuryWallet,
            USDC,
            IERC20(USDC).balanceOf(address(this)),
            DEST_CHAINID,
            uint64(block.timestamp),
            10000
        );
    }

    // OnlyOwner functions

    function togglePause(bool _isPaused) public onlyOwner {
        isPaused = _isPaused;
    }

    function setTreasuryWallet(address payable _wallet) public onlyOwner {
        treasuryWallet = _wallet;
    }

    function setFeeTokens(address[] calldata tokens) public onlyOwner {
        currentFeeTokens = tokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).approve(address(swapsRouterV2), 0);
            IERC20(tokens[i]).approve(
                address(swapsRouterV2),
                type(uint256).max
            );
        }
    }

    function setBridgeApproval(address token) public onlyOwner {
        IERC20(token).approve(bridge, 0);
        IERC20(token).approve(bridge, type(uint256).max);
    }

    function setBridge(address _wallet) public onlyOwner {
        bridge = _wallet;
    }
}

/**
 * Copyright 2017-2020, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity 0.5.17;

import "../PriceFeeds.sol";
import "../../swaps/ISwapsImpl.sol";

/*
Kovan tokens:
    0xd0A1E359811322d97991E03f863a0C30C2cF029C -> WETH
    0xC4375B7De8af5a38a93548eb8453a498222C4fF2 -> SAI
    0x4F96Fe3b7A6Cf9725f59d353F723c1bDb64CA6Aa -> DAI
*/

contract PriceFeedsTestnets is PriceFeeds {

    mapping (address => mapping (address => uint256)) public rates;

    address public constant kyberContract = 0x692f391bCc85cefCe8C237C01e1f636BbD70EA4D; // kovan
    //address public constant kyberContract = 0x818E6FECD516Ecc3849DAf6845e3EC868087B755; // ropsten

    function _queryRate(
        address sourceToken,
        address destToken)
        internal
        view
        returns (uint256 rate, uint256 precision)
    {
        if (sourceToken != destToken) {
            rate = rates[sourceToken][destToken];

            if (rate == 0) {
                uint256 sourceRate;
                if (sourceToken != address(wethToken)) {
                    IPriceFeedsExt _sourceFeed = pricesFeeds[sourceToken];
                    require(address(_sourceFeed) != address(0), "unsupported src feed");
                    sourceRate = uint256(_sourceFeed.latestAnswer());
                    require(sourceRate != 0 && (sourceRate >> 128) == 0, "price error");
                } else {
                    sourceRate = 10**18;
                }

                uint256 destRate;
                if (destToken != address(wethToken)) {
                    IPriceFeedsExt _destFeed = pricesFeeds[destToken];
                    require(address(_destFeed) != address(0), "unsupported dst feed");
                    destRate = uint256(_destFeed.latestAnswer());
                    require(destRate != 0 && (destRate >> 128) == 0, "price error");
                } else {
                    destRate = 10**18;
                }

                rate = sourceRate
                    .mul(10**18)
                    .div(destRate);
            }

            precision = _getDecimalPrecision(sourceToken, destToken);
        } else {
            rate = 10**18;
            precision = 10**18;
        }
    }

    function setRateToCustom(
        address sourceToken,
        address destToken,
        uint256 rate)
        public
        onlyOwner
    {
        if (sourceToken != destToken) {
            rates[sourceToken][destToken] = rate;
            rates[destToken][sourceToken] = SafeMath.div(10**36, rate);
        }
    }

    function setRateToKyber(
        address sourceToken,
        address destToken)
        public
        onlyOwner
    {
        if (sourceToken != destToken) {
            uint256 rate;

            // source to dest
            (bool result, bytes memory data) = kyberContract.staticcall(
                abi.encodeWithSignature(
                    "getExpectedRate(address,address,uint256)",
                    sourceToken,
                    destToken,
                    10**16
                )
            );
            assembly {
                switch result
                case 0 {
                    rate := 0
                }
                default {
                    rate := mload(add(data, 32))
                }
            }
            rates[sourceToken][destToken] = rate;

            // dest to source
            (result, data) = kyberContract.staticcall(
                abi.encodeWithSignature(
                    "getExpectedRate(address,address,uint256)",
                    destToken,
                    sourceToken,
                    10**16
                )
            );
            assembly {
                switch result
                case 0 {
                    rate := 0
                }
                default {
                    rate := mload(add(data, 32))
                }
            }
            rates[destToken][sourceToken] = rate;
        }
    }

    function setRateToChainlink(
        address sourceToken,
        address destToken)
        public
        onlyOwner
    {
        rates[sourceToken][destToken] = 0;
        rates[destToken][sourceToken] = 0;
    }
}

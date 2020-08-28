/**
 * Copyright 2017-2020, bZeroX, LLC. All Rights Reserved.
 * Licensed under the Apache License, Version 2.0.
 */

pragma solidity >=0.5.0 <0.6.0;
pragma experimental ABIEncoderV2;

import "../contracts/core/State.sol";
import "../contracts/events/ProtocolSettingsEvents.sol";
import "../contracts/events/LoanSettingsEvents.sol";
import "../contracts/events/LoanOpeningsEvents.sol";
import "../contracts/events/LoanMaintenanceEvents.sol";
import "../contracts/events/LoanClosingsEvents.sol";
import "../contracts/events/FeesEvents.sol";
import "../contracts/events/SwapsEvents.sol";

/// @title A proxy interface for The Protocol
/// @author bZeroX
/// @notice You can use this contract for only the most basic simulation
/// @dev This interface is to be used for the protocol interactions.
contract IBZx is
    State,
    ProtocolSettingsEvents,
    LoanSettingsEvents,
    LoanOpeningsEvents,
    LoanMaintenanceEvents,
    LoanClosingsEvents,
    SwapsEvents {


    ////// Protocol //////

    /// @dev adds or replaces existing proxy module
    /// @param target target proxy module address
    /// @return boolean success
    function replaceContract(
        address target)
        external;

    /// @dev updates all proxy modules addreses and functions signatures. sigsArr and targetsArr should be of equal length
    /// @param sigsArr array of function signatures
    /// @param targetsArr array of target proxy module addresses
    /// @return boolean success
    function setTargets(
        string[] calldata sigsArr,
        address[] calldata targetsArr)
        external;

    /// @dev returns protocol module address given a function signature
    /// @return module address
    function getTarget(
        string calldata sig)
        external
        view
        returns (address);


    ////// Protocol Settings //////

    /// @dev sets price feed contract address. The contract on the addres should implement
    /// @param newContract module address for the IPriceFeeds implementation
    function setPriceFeedContract(
        address newContract)
        external;

    /// @dev sets swaps contract address. The contract on the addres should implement ISwapsImpl
    /// @param newContract module address for the ISwapsImpl implementation
    function setSwapsImplContract(
        address newContract)
        external;

    /// @dev sets loan pool with assets. Accepts two arrays of equal length
    /// @param pools array of address of pools
    /// @param assets array of addresses of assets
    function setLoanPool(
        address[] calldata pools,
        address[] calldata assets)
        external;

    /// @dev updates list of supported tokens, it can be use also to disable or enable particualr token
    /// @param addrs array of address of pools
    /// @param toggles array of addresses of assets
    function setSupportedTokens(
        address[] calldata addrs,
        bool[] calldata toggles)
        external;

    /// @dev sets lending fee with WEI_PERCENT_PRECISION
    /// @param newValue lending fee percent
    function setLendingFeePercent(
        uint256 newValue)
        external;

    /// @dev sets trading fee with WEI_PERCENT_PRECISION
    /// @param newValue trading fee percent
    function setTradingFeePercent(
        uint256 newValue)
        external;

    /// @dev sets borrowing fee with WEI_PERCENT_PRECISION
    /// @param newValue borrowing fee percent
    function setBorrowingFeePercent(
        uint256 newValue)
        external;

    /// @dev sets affiliate fee with WEI_PERCENT_PRECISION
    /// @param newValue affiliate fee percent
    function setAffiliateFeePercent(
        uint256 newValue)
        external;

    /// @dev sets liquidation inncetive percent. This is the profit percent that liquidator gets in the process of liquidating.
    /// @param newValue liquidation inncetive amount
    function setLiquidationIncentivePercent(
        uint256 newValue)
        external;

    /// @dev sets max swap rate slippage percent.
    /// @param newValue max swap rate slippage percent.
    function setMaxDisagreement(
        uint256 newValue)
        external;

    /// ?
    function setSourceBufferPercent(
        uint256 newAmount)
        external;

    /// @dev sets maximum supported swap size in ETH
    /// @param newAmount max swap size in ETH.
    function setMaxSwapSize(
        uint256 newAmount)
        external;

    /// @dev sets fee controller address
    /// @param newController address of the new fees controller
    function setFeesController(
        address newController)
        external;

    /// @dev withdraws lending fees to receiver. Only can be called by feesController address
    /// @param tokens array of token addresses.
    /// @param receiver fees receiver address
    /// @return amounts withdrawn
    function withdrawLendingFees(
        address[] calldata tokens,
        address receiver)
        external
        returns (uint256[] memory amounts);

    /// @dev withdraws trading fees to receiver. Only can be called by feesController address
    /// @param tokens array of token addresses.
    /// @param receiver fees receiver address
    /// @return amounts withdrawn
    function withdrawTradingFees(
        address[] calldata tokens,
        address receiver)
        external
        returns (uint256[] memory amounts);


    /// @dev withdraws borrowing fees to receiver. Only can be called by feesController address
    /// @param tokens array of token addresses.
    /// @param receiver fees receiver address
    /// @return amounts withdrawn
    function withdrawBorrowingFees(
        address[] calldata tokens,
        address receiver)
        external
        returns (uint256[] memory amounts);

    /// @dev withdraw protocol token (BZRX) from vesting contract vBZRX
    /// @param receiver address of BZRX tokens claimed
    /// @param amount of BZRX token to be claimed. max is claimed if amount is greater than balance.
    function withdrawProtocolToken(
        address receiver,
        uint256 amount)
        external
        returns (address, bool);

    /// @dev depozit protocol token (BZRX)
    /// @param amount address of BZRX tokens to deposit
    function depositProtocolToken(
        uint256 amount)
        external;

    /// @dev get list of loan pools in the system. Ordering is not guaranteed
    /// @param start start index
    /// @param count number of pools to return
    /// @return array of loan pools
    function getLoanPoolsList(
        uint256 start,
        uint256 count)
        external
        returns(bytes32[] memory);

    /// @dev checks whether addreess is a loan pool address
    /// @return boolean 
    function isLoanPool(
        address loanPool)
        external
        view
        returns (bool);


    ////// Loan Settings //////

    /// @dev creates new loan param settings
    /// @param loanParamsList array of LoanParams
    /// @return array of loan ids created
    function setupLoanParams(
        LoanParams[] calldata loanParamsList)
        external
        returns (bytes32[] memory loanParamsIdList);

    /// @dev Deactivates LoanParams for future loans. Active loans using it are unaffected.
    /// @param loanParamsIdList array of loan ids
    function disableLoanParams(
        bytes32[] calldata loanParamsIdList)
        external;

    /// @dev gets array of LoanParams by given ids
    /// @param loanParamsIdList array of loan ids
    /// @return array of LoanParams
    function getLoanParams(
        bytes32[] calldata loanParamsIdList)
        external
        view
        returns (LoanParams[] memory loanParamsList);

    /// @dev Enumerates LoanParams in the system by owner
    /// @param owner of the loan params
    /// @param start of the index.
    /// @param count total number of the items returned
    /// @return array of LoanParams
    function getLoanParamsList(
        address owner,
        uint256 start,
        uint256 count)
        external
        view
        returns (bytes32[] memory loanParamsList);

    /// @dev returns total loan principal for token address
    /// @param lender address
    /// @param loanToken address
    function getTotalPrincipal(
        address lender,
        address loanToken)
        external
        view
        returns (uint256);


    ////// Loan Openings //////

    function borrowOrTradeFromPool(
        bytes32 loanParamsId,
        bytes32 loanId, // if 0, start a new loan
        bool isTorqueLoan,
        uint256 initialMargin,
        address[4] calldata sentAddresses,
            // lender: must match loan if loanId provided
            // borrower: must match loan if loanId provided
            // receiver: receiver of funds (address(0) assumes borrower address)
            // manager: delegated manager of loan unless address(0)
        uint256[5] calldata sentValues,
            // newRate: new loan interest rate
            // newPrincipal: new loan size (borrowAmount + any borrowed interest)
            // torqueInterest: new amount of interest to escrow for Torque loan (determines initial loan length)
            // loanTokenReceived: total loanToken deposit (amount not sent to borrower in the case of Torque loans)
            // collateralTokenReceived: total collateralToken deposit
        bytes calldata loanDataBytes)
        external
        payable
        returns (uint256);

    function setDelegatedManager(
        bytes32 loanId,
        address delegated,
        bool toggle)
        external;

    function getEstimatedMarginExposure(
        address loanToken,
        address collateralToken,
        uint256 loanTokenSent,
        uint256 collateralTokenSent,
        uint256 interestRate,
        uint256 newPrincipal)
        external
        view
        returns (uint256);

    function getRequiredCollateral(
        address loanToken,
        address collateralToken,
        uint256 newPrincipal,
        uint256 marginAmount,
        bool isTorqueLoan)
        external
        view
        returns (uint256 collateralAmountRequired);

    function getBorrowAmount(
        address loanToken,
        address collateralToken,
        uint256 collateralTokenAmount,
        uint256 marginAmount,
        bool isTorqueLoan)
        external
        view
        returns (uint256 borrowAmount);


    ////// Loan Closings //////

    function liquidate(
        bytes32 loanId,
        address receiver,
        uint256 closeAmount) // denominated in loanToken
        external
        payable
        returns (
            uint256 loanCloseAmount,
            uint256 seizedAmount,
            address seizedToken
        );

    function rollover(
        bytes32 loanId,
        bytes calldata loanDataBytes)
        external;

    function closeWithDeposit(
        bytes32 loanId,
        address receiver,
        uint256 depositAmount) // denominated in loanToken
        external
        payable
        returns (
            uint256 loanCloseAmount,
            uint256 withdrawAmount,
            address withdrawToken
        );

    function closeWithSwap(
        bytes32 loanId,
        address receiver,
        uint256 swapAmount, // denominated in collateralToken
        bool returnTokenIsCollateral, // true: withdraws collateralToken, false: withdraws loanToken
        bytes calldata loanDataBytes)
        external
        returns (
            uint256 loanCloseAmount,
            uint256 withdrawAmount,
            address withdrawToken
        );

    ////// Loan Closings With Gas Token //////

    function liquidateWithGasToken(
        bytes32 loanId,
        address receiver,
        address gasTokenUser,
        uint256 closeAmount) // denominated in loanToken
        external
        payable
        returns (
            uint256 loanCloseAmount,
            uint256 seizedAmount,
            address seizedToken
        );

    function rolloverWithGasToken(
        bytes32 loanId,
        address gasTokenUser,
        bytes calldata /*loanDataBytes*/) // for future use
        external;

    function closeWithDepositWithGasToken(
        bytes32 loanId,
        address receiver,
        address gasTokenUser,
        uint256 depositAmount) // denominated in loanToken
        public
        payable
        returns (
            uint256 loanCloseAmount,
            uint256 withdrawAmount,
            address withdrawToken
        );

    function closeWithSwapWithGasToken(
        bytes32 loanId,
        address receiver,
        address gasTokenUser,
        uint256 swapAmount, // denominated in collateralToken
        bool returnTokenIsCollateral, // true: withdraws collateralToken, false: withdraws loanToken
        bytes memory /*loanDataBytes*/) // for future use
        public
        returns (
            uint256 loanCloseAmount,
            uint256 withdrawAmount,
            address withdrawToken
        );

    ////// Loan Maintenance //////

    function depositCollateral(
        bytes32 loanId,
        uint256 depositAmount) // must match msg.value if ether is sent
        external
        payable;

    function withdrawCollateral(
        bytes32 loanId,
        address receiver,
        uint256 withdrawAmount)
        external
        returns (uint256 actualWithdrawAmount);

    function withdrawAccruedInterest(
        address loanToken)
        external;

    function extendLoanDuration(
        bytes32 loanId,
        uint256 depositAmount,
        bool useCollateral,
        bytes calldata /*loanDataBytes*/) // for future use
        external
        payable
        returns (uint256 secondsExtended);

    function reduceLoanDuration(
        bytes32 loanId,
        address receiver,
        uint256 withdrawAmount)
        external
        returns (uint256 secondsReduced);

    /// @dev Gets current lender interest data totals for all loans with a specific oracle and interest token
    /// @param lender The lender address
    /// @param loanToken The loan token address
    /// @return interestPaid The total amount of interest that has been paid to a lender so far
    /// @return interestPaidDate The date of the last interest pay out, or 0 if no interest has been withdrawn yet
    /// @return interestOwedPerDay The amount of interest the lender is earning per day
    /// @return interestUnPaid The total amount of interest the lender is owned and not yet withdrawn
    /// @return interestFeePercent The fee retained by the protocol before interest is paid to the lender
    /// @return principalTotal The total amount of outstading principal the lender has loaned
    function getLenderInterestData(
        address lender,
        address loanToken)
        external
        view
        returns (
            uint256 interestPaid,
            uint256 interestPaidDate,
            uint256 interestOwedPerDay,
            uint256 interestUnPaid,
            uint256 interestFeePercent,
            uint256 principalTotal);


    /// @dev Gets current interest data for a loan
    /// @param loanId A unique id representing the loan
    /// @return loanToken The loan token that interest is paid in
    /// @return interestOwedPerDay The amount of interest the borrower is paying per day
    /// @return interestDepositTotal The total amount of interest the borrower has deposited
    /// @return interestDepositRemaining The amount of deposited interest that is not yet owed to a lender
    function getLoanInterestData(
        bytes32 loanId)
        external
        view
        returns (
            address loanToken,
            uint256 interestOwedPerDay,
            uint256 interestDepositTotal,
            uint256 interestDepositRemaining);

    // Only returns data for loans that are active
    // All(0): all loans
    // Margin(1): margin trade loans
    // NonMargin(2): non-margin trade loans
    // only active loans are returned
    function getUserLoans(
        address user,
        uint256 start,
        uint256 count,
        LoanType loanType,
        bool isLender,
        bool unsafeOnly)
        external
        view
        returns (LoanReturnData[] memory loansData);

    function getLoan(
        bytes32 loanId)
        external
        view
        returns (LoanReturnData memory loanData);

    function getActiveLoans(
        uint256 start,
        uint256 count,
        bool unsafeOnly)
        external
        view
        returns (LoanReturnData[] memory loansData);


    ////// Swap External //////

    function swapExternal(
        address sourceToken,
        address destToken,
        address receiver,
        address returnToSender,
        uint256 sourceTokenAmount,
        uint256 requiredDestTokenAmount,
        bytes calldata swapData)
        external
        payable
        returns (uint256 destTokenAmountReceived, uint256 sourceTokenAmountUsed);

    function swapExternalWithGasToken(
        address sourceToken,
        address destToken,
        address receiver,
        address returnToSender,
        address gasTokenUser,
        uint256 sourceTokenAmount,
        uint256 requiredDestTokenAmount,
        bytes calldata swapData)
        external
        payable
        returns (uint256 destTokenAmountReceived, uint256 sourceTokenAmountUsed);

    function getSwapExpectedReturn(
        address sourceToken,
        address destToken,
        uint256 sourceTokenAmount)
        external
        view
        returns (uint256);
}

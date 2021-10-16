pragma solidity 0.5.17;

import "../../utils/MathUtil.sol";
import "../../core/State.sol";
import "@openzeppelin-2.5.0/token/ERC20/SafeERC20.sol";
import "@openzeppelin-2.5.0/token/ERC20/IERC20.sol";

contract FlashBorrowFeesHelper is State{
	using MathUtil for uint256;
	function _payFlashBorrowFees(
		address user,
		uint256 borrowAmount,
		uint256 feeAmountInWEI)
		public
	{
		address feeToken = loanPoolToUnderlying[msg.sender];
		require(feeToken != address(0), "Calling Contract must be Loan Pool");
		uint256 feeTokenAmount = borrowAmount.mul(feeAmountInWEI).div(WEI_PERCENT_PRECISION);
		SafeERC20.safeTransferFrom(IERC20(feeToken), msg.sender, address(this), feeTokenAmount);
		if(feeTokenAmount != 0){
			borrowingFeeTokensHeld[feeToken] = borrowingFeeTokensHeld[feeToken].add(feeTokenAmount);
		}
	}

}
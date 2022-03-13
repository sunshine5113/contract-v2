pragma solidity ^0.8.0;
import "@openzeppelin-4.3.2/access/Ownable.sol";
import "@openzeppelin-4.3.2/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin-4.3.2/token/ERC20/extensions/IERC20Metadata.sol";

contract Deposits is Ownable {
    struct DepositInfo {
        address depositToken;
        uint256 depositAmount;
    }
    mapping(bytes32 => DepositInfo) internal _depositInfo;
    address public orderBook = address(0);

    function deposit(
        bytes32 orderID,
        uint256 tokenAmount,
        address trader,
        address token
    ) external {
        require(msg.sender == orderBook, "unauthorized");
        _depositInfo[orderID].depositToken = token;
        _depositInfo[orderID].depositAmount = tokenAmount;
        SafeERC20.safeTransferFrom(
            IERC20(token),
            trader,
            address(this),
            tokenAmount
        );
    }

    function setOrderBook(address n) external onlyOwner {
        orderBook = n;
    }

    function withdraw(bytes32 orderID) external {
        require(msg.sender == orderBook, "unauthorized");
        SafeERC20.safeTransfer(
            IERC20(_depositInfo[orderID].depositToken),
            msg.sender,
            _depositInfo[orderID].depositAmount
        );
        _depositInfo[orderID].depositAmount = 0;
    }

    function withdrawToTrader(address trader, bytes32 orderID) external {
        require(msg.sender == orderBook, "unauthorized");
        SafeERC20.safeTransfer(
            IERC20(_depositInfo[orderID].depositToken),
            trader,
            _depositInfo[orderID].depositAmount
        );
        _depositInfo[orderID].depositAmount = 0;
    }

    function partialWithdraw(
        address trader,
        bytes32 orderID,
        uint256 amount
    ) external {
        require(msg.sender == orderBook, "unauthorized");
        SafeERC20.safeTransfer(
            IERC20(_depositInfo[orderID].depositToken),
            trader,
            amount
        );
        _depositInfo[orderID].depositAmount -= amount;
    }

    function getDeposit(bytes32 orderID)
        external
        view
        returns (uint256)
    {
        return _depositInfo[orderID].depositAmount;
    }

    function getTokenUsed(bytes32 orderID)
        external
        view
        returns (address)
    {
        return _depositInfo[orderID].depositToken;
    }
}

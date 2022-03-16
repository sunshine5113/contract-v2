pragma solidity ^0.8.0;
import "../IOrderBook.sol";
import "@openzeppelin-4.3.2/token/ERC20/extensions/IERC20Metadata.sol";
import "../../governance/PausableGuardian_0_8.sol";

contract OrderKeeper is PausableGuardian_0_8 {
    IOrderBook public factory;

    constructor(IOrderBook factoryAddress) {
        factory = factoryAddress;
    }

    function checkUpKeep(bytes calldata checkData)
        external
        returns (bool upkeepNeeded, bytes memory performData)
    {
        (uint256 start, uint256 end) = abi.decode(checkData, (uint256, uint256));
        uint256 orderIDLength = factory.getTotalOrderIDs();
        if(end < orderIDLength) {
            if (start > orderIDLength) {
                end = orderIDLength;
            } else {
                return (upkeepNeeded, performData);
            }
        }
        IOrderBook.Order[] memory listOfMainOrders = factory
            .getOrdersLimited(start, end);
        for (uint256 x = 0; x < listOfMainOrders.length;) {
            try factory.prelimCheck(listOfMainOrders[x].orderID) returns (bool isExecutable) {
                if(isExecutable) {
                    upkeepNeeded = true;
                    performData = abi.encode(listOfMainOrders[x].orderID);
                    return (upkeepNeeded, performData);
                }
            } catch Error (string memory) {

            }
            unchecked { ++x; }
        }
        return (upkeepNeeded, performData);
    }

    function performUpKeep(bytes calldata performData) external pausable {
        bytes32 orderId = abi.decode(performData, (bytes32));
        //emit OrderExecuted(trader,orderId);
        factory.executeOrder(orderId);
    }
}

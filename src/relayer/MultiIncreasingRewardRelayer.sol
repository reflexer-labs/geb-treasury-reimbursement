pragma solidity 0.6.7;

import "../reimbursement/multi/MultiIncreasingTreasuryReimbursement.sol";

contract MultiIncreasingRewardRelayer is MultiIncreasingTreasuryReimbursement {
    // --- Variables ---
    // Address that can request funds
    address public refundRequestor;
    // Timestamp of the last reimbursement
    uint256 public lastReimburseTime;       // [timestamp]
    // Enforced gap between reimbursements
    uint256 public reimburseDelay;          // [seconds]

    constructor(
      bytes32 coinName_,
      address refundRequestor_,
      address treasury_,
      uint256 baseUpdateCallerReward_,
      uint256 maxUpdateCallerReward_,
      uint256 perSecondCallerRewardIncrease_,
      uint256 reimburseDelay_
    ) public MultiIncreasingTreasuryReimbursement(coinName_, treasury_, baseUpdateCallerReward_, maxUpdateCallerReward_, perSecondCallerRewardIncrease_) {
        require(refundRequestor_ != address(0), "MultiIncreasingRewardRelayer/null-refund-requestor");
        require(reimburseDelay_ > 0, "MultiIncreasingRewardRelayer/null-reimburse-delay");

        refundRequestor = refundRequestor_;
        reimburseDelay  = reimburseDelay_;

        emit ModifyParameters("refundRequestor", refundRequestor);
        emit ModifyParameters("reimburseDelay", reimburseDelay);
    }

    // --- Administration ---
    /*
    * @notice Change the addresses of contracts that this wrapper is connected to
    * @param parameter The contract whose address is changed
    * @param addr The new contract address
    */
    function modifyParameters(bytes32 parameter, address addr) external isAuthorized {
        require(addr != address(0), "MultiIncreasingRewardRelayer/null-addr");
        if (parameter == "treasury") {
          require(StabilityFeeTreasuryLike(addr).systemCoin(coinName) != address(0), "MultiIncreasingRewardRelayer/treasury-coin-not-set");
          treasury = StabilityFeeTreasuryLike(addr);
        } else if (parameter == "refundRequestor") {
          refundRequestor = addr;
        }
        else revert("MultiIncreasingRewardRelayer/modify-unrecognized-param");
        emit ModifyParameters(
          parameter,
          addr
        );
    }
    /*
    * @notify Modify a uint256 parameter
    * @param parameter The parameter name
    * @param val The new parameter value
    */
    function modifyParameters(bytes32 parameter, uint256 val) external isAuthorized {
        if (parameter == "baseUpdateCallerReward") {
          require(val <= maxUpdateCallerReward, "MultiIncreasingRewardRelayer/invalid-base-caller-reward");
          baseUpdateCallerReward = val;
        }
        else if (parameter == "maxUpdateCallerReward") {
          require(val >= baseUpdateCallerReward, "MultiIncreasingRewardRelayer/invalid-max-caller-reward");
          maxUpdateCallerReward = val;
        }
        else if (parameter == "perSecondCallerRewardIncrease") {
          require(val >= RAY, "MultiIncreasingRewardRelayer/invalid-caller-reward-increase");
          perSecondCallerRewardIncrease = val;
        }
        else if (parameter == "maxRewardIncreaseDelay") {
          require(val > 0, "MultiIncreasingRewardRelayer/invalid-max-increase-delay");
          maxRewardIncreaseDelay = val;
        }
        else if (parameter == "reimburseDelay") {
          require(val > 0, "MultiIncreasingRewardRelayer/invalid-reimburse-delay");
          reimburseDelay = val;
        }
        else revert("MultiIncreasingRewardRelayer/modify-unrecognized-param");
        emit ModifyParameters(
          parameter,
          val
        );
    }

    // --- Core Logic ---
    /*
    * @notice Send a stability fee reward to an address proposed by the refundRequestor
    * @param feeReceiver Address that will receive the SF reward
    */
    function reimburseCaller(address feeReceiver) external {
        // Perform checks
        require(refundRequestor == msg.sender, "MultiIncreasingRewardRelayer/invalid-caller");
        require(feeReceiver != address(0), "MultiIncreasingRewardRelayer/null-fee-receiver");
        require(feeReceiver != refundRequestor, "MultiIncreasingRewardRelayer/requestor-cannot-receive-fees");
        // Check delay between calls
        require(either(subtract(now, lastReimburseTime) >= reimburseDelay, lastReimburseTime == 0), "MultiIncreasingRewardRelayer/wait-more");
        // Get the caller's reward
        uint256 callerReward = getCallerReward(lastReimburseTime, reimburseDelay);
        // Store the timestamp of the reimbursement
        lastReimburseTime = now;
        // Pay the fee receiver
        rewardCaller(feeReceiver, callerReward);
    }
}

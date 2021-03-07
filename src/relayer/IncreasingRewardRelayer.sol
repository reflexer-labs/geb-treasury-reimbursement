pragma solidity 0.6.7;

import "../reimbursement/IncreasingTreasuryReimbursement.sol";

contract IncreasingRewardRelayer is IncreasingTreasuryReimbursement {
    // --- Variables ---
    // Address that can request funds
    address public refundRequestor;
    // When the rate has last been relayed
    uint256 public lastReimburseTime;       // [timestamp]
    // Enforced gap between reimbursements
    uint256 public reimburseDelay;          // [seconds]

    constructor(
      address refundRequestor_,
      address treasury_,
      uint256 baseUpdateCallerReward_,
      uint256 maxUpdateCallerReward_,
      uint256 perSecondCallerRewardIncrease_,
      uint256 reimburseDelay_
    ) public IncreasingTreasuryReimbursement(treasury_, baseUpdateCallerReward_, maxUpdateCallerReward_, perSecondCallerRewardIncrease_) {
        require(refundRequestor_ != address(0), "IncreasingRewardRelayer/null-refund-requestor");
        require(reimburseDelay_ > 0, "IncreasingRewardRelayer/null-reimburse-delay");

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
        require(addr != address(0), "IncreasingRewardRelayer/null-addr");
        if (parameter == "treasury") {
          require(StabilityFeeTreasuryLike(addr).systemCoin() != address(0), "IncreasingRewardRelayer/treasury-coin-not-set");
          treasury = StabilityFeeTreasuryLike(addr);
        } else if (parameter == "refundRequestor") {
          refundRequestor = addr;
        }
        else revert("IncreasingRewardRelayer/modify-unrecognized-param");
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
          require(val <= maxUpdateCallerReward, "IncreasingRewardRelayer/invalid-base-caller-reward");
          baseUpdateCallerReward = val;
        }
        else if (parameter == "maxUpdateCallerReward") {
          require(val >= baseUpdateCallerReward, "IncreasingRewardRelayer/invalid-max-caller-reward");
          maxUpdateCallerReward = val;
        }
        else if (parameter == "perSecondCallerRewardIncrease") {
          require(val >= RAY, "IncreasingRewardRelayer/invalid-caller-reward-increase");
          perSecondCallerRewardIncrease = val;
        }
        else if (parameter == "maxRewardIncreaseDelay") {
          require(val > 0, "IncreasingRewardRelayer/invalid-max-increase-delay");
          maxRewardIncreaseDelay = val;
        }
        else if (parameter == "reimburseDelay") {
          reimburseDelay = val;
        }
        else revert("IncreasingRewardRelayer/modify-unrecognized-param");
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
        require(refundRequestor == msg.sender, "IncreasingRewardRelayer/invalid-caller");
        require(feeReceiver != address(0), "IncreasingRewardRelayer/null-fee-receiver");
        require(feeReceiver != refundRequestor, "IncreasingRewardRelayer/requestor-cannot-receive-fees");
        // Check delay between calls
        require(either(subtract(now, lastReimburseTime) >= reimburseDelay, lastReimburseTime == 0), "IncreasingRewardRelayer/wait-more");
        // Get the caller's reward
        uint256 callerReward = getCallerReward(lastReimburseTime, reimburseDelay);
        // Store the timestamp of the reimbursement
        lastReimburseTime = now;
        // Pay the fee receiver
        rewardCaller(feeReceiver, callerReward);
    }
}

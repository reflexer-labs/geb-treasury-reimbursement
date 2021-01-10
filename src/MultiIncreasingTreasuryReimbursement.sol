pragma solidity 0.6.7;

import "./math/GebMath.sol";

abstract contract StabilityFeeTreasuryLike {
    function getAllowance(address) virtual external view returns (uint, uint);
    function systemCoin() virtual external view returns (address);
    function pullFunds(address, address, uint) virtual external;
}

contract MultiIncreasingTreasuryReimbursement is GebMath {
    // --- Auth ---
    mapping (address => uint) public authorizedAccounts;
    function addAuthorization(address account) virtual external isAuthorized {
        authorizedAccounts[account] = 1;
        emit AddAuthorization(account);
    }
    function removeAuthorization(address account) virtual external isAuthorized {
        authorizedAccounts[account] = 0;
        emit RemoveAuthorization(account);
    }
    modifier isAuthorized {
        require(authorizedAccounts[msg.sender] == 1, "MultiIncreasingTreasuryReimbursement/account-not-authorized");
        _;
    }

    // --- Structs ---
    struct Reimbursement {
        // Starting reward for the fee receiver/keeper
        uint256 baseUpdateCallerReward;          // [wad]
        // Max possible reward for the fee receiver/keeper
        uint256 maxUpdateCallerReward;           // [wad]
        // Max delay taken into consideration when calculating the adjusted reward
        uint256 maxRewardIncreaseDelay;          // [seconds]
        // Rate applied to baseUpdateCallerReward every extra second passed beyond a certain point (e.g next time when a specific function needs to be called)
        uint256 perSecondCallerRewardIncrease;   // [ray]
    }

    // --- Vars ---
    mapping(bytes4 => Reimbursement) public reimbursements;

    // SF treasury
    StabilityFeeTreasuryLike  public treasury;

    // --- Events ---
    event AddAuthorization(address account);
    event RemoveAuthorization(address account);
    event ModifyParameters(
      bytes4 targetFunction,
      bytes32 parameter,
      address addr
    );
    event ModifyParameters(
      bytes32 parameter,
      address addr
    );
    event InitFunctionReimbursement(
      bytes4 targetFunction,
      uint256 baseUpdateCallerReward,
      uint256 maxUpdateCallerReward,
      uint256 perSecondCallerRewardIncrease,
      uint256 maxRewardIncreaseDelay
    );
    event FailRewardCaller(bytes revertReason, address feeReceiver, uint256 amount);

    constructor(
      address treasury_
    ) public {
        if (address(treasury_) != address(0)) {
          require(StabilityFeeTreasuryLike(treasury_).systemCoin() != address(0), "MultiIncreasingTreasuryReimbursement/treasury-coin-not-set");
        }

        authorizedAccounts[msg.sender] = 1;
        treasury                       = StabilityFeeTreasuryLike(treasury_);

        emit AddAuthorization(msg.sender);
        emit ModifyParameters("treasury", treasury_);
    }

    // --- Administration ---
    function initializeFunctionReimbursement(
        bytes4 targetFunction,
        uint256 baseUpdateCallerReward_,
        uint256 maxUpdateCallerReward_,
        uint256 perSecondCallerRewardIncrease_,
        uint256 maxRewardIncreaseDelay_
    ) external isAuthorized {
        require(reimbursements[targetFunction].perSecondCallerRewardIncrease == 0, "MultiIncreasingTreasuryReimbursement/already-init");
        require(maxUpdateCallerReward_ >= baseUpdateCallerReward_, "MultiIncreasingTreasuryReimbursement/invalid-max-caller-reward");
        require(perSecondCallerRewardIncrease_ >= RAY, "MultiIncreasingTreasuryReimbursement/invalid-per-second-reward-increase");
        require(maxRewardIncreaseDelay_ > 0, "MultiIncreasingTreasuryReimbursement/null-max-increase-delay");

        reimbursements[targetFunction] = Reimbursement(
            baseUpdateCallerReward_,
            maxUpdateCallerReward_,
            maxRewardIncreaseDelay_,
            perSecondCallerRewardIncrease_
        );

        emit InitFunctionReimbursement(
          targetFunction,
          baseUpdateCallerReward_,
          maxUpdateCallerReward_,
          perSecondCallerRewardIncrease_,
          maxRewardIncreaseDelay_
        );
    }

    // --- Treasury ---
    /**
    * @notice This returns the stability fee treasury allowance for this contract by taking the minimum between the per block and the total allowances
    **/
    function treasuryAllowance() public view returns (uint256) {
        (uint total, uint perBlock) = treasury.getAllowance(address(this));
        return minimum(total, perBlock);
    }
    /*
    * @notice Get the SF reward that can be sent to a function caller right now
    */
    function getCallerReward(bytes4 targetFunction, uint256 timeOfLastUpdate, uint256 defaultDelayBetweenCalls) public view returns (uint256) {
        require(reimbursements[targetFunction].perSecondCallerRewardIncrease >= RAY, "MultiIncreasingTreasuryReimbursement/func-not-init");
        Reimbursement memory reimbursement = reimbursements[targetFunction];

        if (timeOfLastUpdate >= now) return 0;
        uint256 timeElapsed = (timeOfLastUpdate == 0) ? defaultDelayBetweenCalls : subtract(now, timeOfLastUpdate);
        if (timeElapsed < defaultDelayBetweenCalls) {
            return 0;
        }
        uint256 adjustedTime      = subtract(timeElapsed, defaultDelayBetweenCalls);
        uint256 maxPossibleReward = minimum(reimbursement.maxUpdateCallerReward, treasuryAllowance() / RAY);
        if (adjustedTime > reimbursement.maxRewardIncreaseDelay) {
            return maxPossibleReward;
        }
        uint256 calculatedReward = reimbursement.baseUpdateCallerReward;
        if (adjustedTime > 0) {
            calculatedReward = rmultiply(rpower(reimbursement.perSecondCallerRewardIncrease, adjustedTime, RAY), calculatedReward);
        }
        if (calculatedReward > maxPossibleReward) {
            calculatedReward = maxPossibleReward;
        }
        return calculatedReward;
    }
    /**
    * @notice Send a stability fee reward to an address
    * @param proposedFeeReceiver The SF receiver
    * @param reward The system coin amount to send
    **/
    function rewardCaller(address proposedFeeReceiver, uint256 reward) internal {
        if (address(treasury) == proposedFeeReceiver) return;
        if (address(treasury) == address(0) || reward == 0) return;
        address finalFeeReceiver = (proposedFeeReceiver == address(0)) ? msg.sender : proposedFeeReceiver;
        try treasury.pullFunds(finalFeeReceiver, treasury.systemCoin(), reward) {}
        catch(bytes memory revertReason) {
            emit FailRewardCaller(revertReason, finalFeeReceiver, reward);
        }
    }
}

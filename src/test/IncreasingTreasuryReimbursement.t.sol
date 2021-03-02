pragma solidity >=0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "./geb/MockTreasury.sol";

import "../IncreasingTreasuryReimbursement.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract Pinger is IncreasingTreasuryReimbursement {

    constructor(address treasury_, uint256 baseUpdateCallerReward_, uint maxUpdateCallerReward_, uint perSecondCallerRewardIncrease_) public 
    IncreasingTreasuryReimbursement(treasury_, baseUpdateCallerReward_, maxUpdateCallerReward_, perSecondCallerRewardIncrease_)
    {}

    function ping(address receiver, uint value) public {
        rewardCaller(receiver, value);
    }

    function modifyParameters(bytes32 param, uint value) public {
        if (param == "maxRewardIncreaseDelay")
            maxRewardIncreaseDelay = value;
        else revert("");
    }

}

contract MandatoryFixedTreasuryReimbursementTest is DSTest {
    Hevm hevm;

    Pinger pinger;
    MockTreasury treasury;
    DSToken coin;

    address alice = address(0x4567);
    address me;

    uint256 startTime                     = 1577836800;
    uint256 baseCallerReward              = 15 ether;
    uint256 maxCallerReward               = 45 ether;
    uint256 initTokenAmount               = 100000000 ether;
    uint256 perSecondCallerRewardIncrease = 1000192559420674483977255848; // 100% over one hour


    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(startTime);

        // Create token
        coin = new DSToken("RAI", "RAI");
        coin.mint(initTokenAmount);

        // Create treasury
        treasury = new MockTreasury(address(coin));
        coin.transfer(address(treasury), initTokenAmount);

        pinger = new Pinger(address(treasury), baseCallerReward, maxCallerReward, perSecondCallerRewardIncrease);

        // Setup treasury allowance
        treasury.setTotalAllowance(address(pinger), uint(-1));
        treasury.setPerBlockAllowance(address(pinger), uint(-1));

        me = address(this);
    }

    // --- Tests ---
    function test_correct_setup() public {
        assertEq(address(pinger.treasury()), address(treasury));
        assertEq(pinger.baseUpdateCallerReward(), baseCallerReward);
        assertEq(pinger.maxUpdateCallerReward(), maxCallerReward);
        assertEq(pinger.perSecondCallerRewardIncrease(), perSecondCallerRewardIncrease);
        assertEq(pinger.maxRewardIncreaseDelay(), uint(-1));
    }

    function test_get_caller_reward() public {
        assertEq(pinger.getCallerReward(now - 1, 1), baseCallerReward);
    }

    function test_get_caller_reward_already_updated() public {
        assertEq(pinger.getCallerReward(now, 1), 0);
    }

    function test_get_caller_reward_with_increase() public {
        assertEq(pinger.getCallerReward(now - 1 hours - 1, 1), 29999999999999999999);
    }

    function test_get_caller_reward_with_2h_increase() public {
        assertEq(pinger.getCallerReward(now - 2 hours - 1, 1), maxCallerReward);
    }

    function test_get_caller_reward_with_4h_increase() public { // will pay maxReward
        assertEq(pinger.getCallerReward(now - 2 hours - 1, 1), maxCallerReward);
    }

    function test_get_caller_reward_null_rewards() public {
        pinger = new Pinger(address(treasury), 0, 0, perSecondCallerRewardIncrease);

        // Setup treasury allowance
        treasury.setTotalAllowance(address(pinger), uint(-1));
        treasury.setPerBlockAllowance(address(pinger), uint(-1));

        assertEq(pinger.getCallerReward(now - 1, 1), 0);
    }

    function test_get_caller_reward_base_reward_zero() public {
        pinger = new Pinger(address(treasury), 0, maxCallerReward, perSecondCallerRewardIncrease);

        // Setup treasury allowance
        treasury.setTotalAllowance(address(pinger), uint(-1));
        treasury.setPerBlockAllowance(address(pinger), uint(-1));

        assertEq(pinger.getCallerReward(now - 1, 1), 0);
    }

    function test_get_caller_reward_after_max_increase_delay() public {
        pinger.modifyParameters(bytes32("maxRewardIncreaseDelay"), 1 hours);

        assertEq(pinger.getCallerReward(now - 1 hours - 2, 1), maxCallerReward);
    } 

    function test_reward_caller() public {
        pinger.ping(alice, 1 ether);
        assertEq(coin.balanceOf(alice), 1 ether);
    }

    function test_reward_caller_no_input() public {
        pinger.ping(address(0x0), 1 ether);
        assertEq(coin.balanceOf(me), 1 ether);
    }

    function test_reward_caller_lower_allowance() public { 
        treasury.setPerBlockAllowance(address(pinger), baseCallerReward * 10**27 / 2);
        pinger.ping(alice, baseCallerReward);
        assertEq(coin.balanceOf(alice), 0);

        treasury.setTotalAllowance(address(pinger), baseCallerReward * 10**27 / 3);
        pinger.ping(address(0x0), baseCallerReward);
        assertEq(coin.balanceOf(me), 0);
    }
}
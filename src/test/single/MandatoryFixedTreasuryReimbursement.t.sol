pragma solidity >=0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "../geb/MockTreasury.sol";

import "../../reimbursement/single/MandatoryFixedTreasuryReimbursement.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract Pinger is MandatoryFixedTreasuryReimbursement {

    constructor(address treasury_, uint256 fixedReward_) public
    MandatoryFixedTreasuryReimbursement(treasury_, fixedReward_)
    {}

    function ping(address receiver) public {
        rewardCaller(receiver);
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
    uint256 initTokenAmount               = 100000000 ether;
    uint256 fixedReward                   = 5 ether;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(startTime);

        // Create token
        coin = new DSToken("RAI", "RAI");
        coin.mint(initTokenAmount);

        // Create treasury
        treasury = new MockTreasury(address(coin));
        coin.transfer(address(treasury), initTokenAmount);

        pinger = new Pinger(address(treasury), fixedReward);

        // Setup treasury allowance
        treasury.setTotalAllowance(address(pinger), uint(-1));
        treasury.setPerBlockAllowance(address(pinger), uint(-1));

        me = address(this);
    }

    // --- Tests ---
    function test_correct_setup() public {
        assertEq(address(pinger.treasury()), address(treasury));
        assertEq(pinger.fixedReward(), fixedReward);
    }

    function test_get_caller_reward() public {
        assertEq(pinger.getCallerReward(), fixedReward);
    }

    function test_get_caller_lower_allowance() public {
        treasury.setPerBlockAllowance(address(pinger), fixedReward * 10**27 / 2);
        assertEq(pinger.getCallerReward(), fixedReward / 2);

        treasury.setTotalAllowance(address(pinger), fixedReward * 10**27 / 3);
        assertEq(pinger.getCallerReward(), fixedReward / 3);
    }

    function test_reward_caller() public {
        pinger.ping(alice);
        assertEq(coin.balanceOf(alice), fixedReward);
    }

    function test_reward_caller_no_input() public {
        pinger.ping(address(0x0));
        assertEq(coin.balanceOf(me), fixedReward);
    }

    function test_reward_caller_lower_allowance() public {
        treasury.setPerBlockAllowance(address(pinger), fixedReward * 10**27 / 2);
        pinger.ping(alice);
        assertEq(coin.balanceOf(alice), fixedReward / 2);

        treasury.setTotalAllowance(address(pinger), fixedReward * 10**27 / 3);
        pinger.ping(address(0x0));
        assertEq(coin.balanceOf(me), fixedReward / 3);
    }
}

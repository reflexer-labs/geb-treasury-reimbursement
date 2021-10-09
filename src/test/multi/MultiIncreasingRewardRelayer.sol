pragma solidity 0.6.7;

import "ds-test/test.sol";
import "ds-token/token.sol";

import "../geb/MockTreasury.sol";

import "../../relayer/MultiIncreasingRewardRelayer.sol";

abstract contract Hevm {
    function warp(uint256) virtual public;
}

contract User {
    function doReimburseCaller(MultiIncreasingRewardRelayer relayer, address feeReceiver) external {
        relayer.reimburseCaller(feeReceiver);
    }
}

contract MultiIncreasingRewardRelayerTest is DSTest {
    Hevm hevm;

    MultiMockTreasury treasury;
    DSToken coin;
    MultiIncreasingRewardRelayer relayer;

    User alice;
    address me;

    uint256 startTime                     = 1577836800;
    uint256 baseCallerReward              = 5 ether;
    uint256 maxCallerReward               = 10 ether;
    uint256 reimburseDelay                = 1 hours;
    uint256 initTokenAmount               = 100000000 ether;
    uint256 perSecondCallerRewardIncrease = 1000192559420674483977255848; // 100% over one hour

    bytes32 coinName                      = "BAI";

    uint256 RAY                           = 10 ** 27;

    function setUp() public {
        hevm = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
        hevm.warp(startTime);

        // Create token
        coin = new DSToken("RAI", "RAI");
        coin.mint(initTokenAmount);

        // Create treasury
        treasury = new MultiMockTreasury(address(coin));
        coin.transfer(address(treasury), initTokenAmount);

        // Create user
        alice = new User();

        // Create the relayer
        relayer = new MultiIncreasingRewardRelayer(
          coinName, address(this), address(treasury), baseCallerReward, maxCallerReward, perSecondCallerRewardIncrease, reimburseDelay
        );

        // Setup treasury allowance
        treasury.setTotalAllowance(coinName, address(relayer), uint(-1));
        treasury.setPerBlockAllowance(coinName, address(relayer), uint(-1));

        me = address(this);
    }

    function test_setup() public {
        assertEq(relayer.authorizedAccounts(me), 1);
        assertEq(relayer.refundRequestor(), me);
        assertEq(relayer.lastReimburseTime(), 0);
        assertEq(relayer.reimburseDelay(), reimburseDelay);

        assertEq(relayer.baseUpdateCallerReward(), baseCallerReward);
        assertEq(relayer.maxUpdateCallerReward(), maxCallerReward);
        assertEq(relayer.perSecondCallerRewardIncrease(), perSecondCallerRewardIncrease);
        assertEq(relayer.maxRewardIncreaseDelay(), uint(-1));
        assertEq(address(relayer.treasury()), address(treasury));
    }

    function test_modify_parameters() public {
        MultiMockTreasury newTreasury = new MultiMockTreasury(address(coin));

        relayer.modifyParameters("treasury", address(newTreasury));
        relayer.modifyParameters("refundRequestor", address(0x1));

        relayer.modifyParameters("baseUpdateCallerReward", baseCallerReward + 10);
        relayer.modifyParameters("maxUpdateCallerReward", maxCallerReward + 10);
        relayer.modifyParameters("perSecondCallerRewardIncrease", perSecondCallerRewardIncrease + 5);
        relayer.modifyParameters("maxRewardIncreaseDelay", 2 hours);
        relayer.modifyParameters("reimburseDelay", 12 hours);

        // Checks
        assertEq(relayer.refundRequestor(), address(0x1));
        assertEq(address(relayer.treasury()), address(newTreasury));

        assertEq(relayer.baseUpdateCallerReward(), baseCallerReward + 10);
        assertEq(relayer.maxUpdateCallerReward(), maxCallerReward + 10);
        assertEq(relayer.perSecondCallerRewardIncrease(), perSecondCallerRewardIncrease + 5);
        assertEq(relayer.maxRewardIncreaseDelay(), 2 hours);
        assertEq(relayer.reimburseDelay(), 12 hours);
    }

    function testFail_reimburse_as_unauthed() public {
        alice.doReimburseCaller(relayer, address(0x1));
    }

    function testFail_reimburse_fee_receiver_null() public {
        relayer.reimburseCaller(address(0));
    }

    function testFail_reimburse_fee_receiver_is_requestor() public {
        relayer.reimburseCaller(me);
    }

    function test_reimburse() public {
        relayer.reimburseCaller(address(0x1));
        assertEq(coin.balanceOf(address(0x1)), baseCallerReward);

        hevm.warp(now + reimburseDelay);

        relayer.reimburseCaller(address(0x1));
        assertEq(coin.balanceOf(address(0x1)), baseCallerReward * 2);

        hevm.warp(now + reimburseDelay * 50);

        relayer.reimburseCaller(address(0x2));
        assertEq(coin.balanceOf(address(0x2)), maxCallerReward);
    }

    function test_reimburse_revertable_treasury() public {
        MultiMockRevertableTreasury revertTreasury = new MultiMockRevertableTreasury();
        relayer.modifyParameters("treasury", address(revertTreasury));

        relayer.reimburseCaller(address(0x1));
        assertEq(coin.balanceOf(address(0x1)), 0);
    }
}

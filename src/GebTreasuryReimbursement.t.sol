pragma solidity ^0.6.7;

import "ds-test/test.sol";

import "./GebTreasuryReimbursement.sol";

contract GebTreasuryReimbursementTest is DSTest {
    GebTreasuryReimbursement reimbursement;

    function setUp() public {
        reimbursement = new GebTreasuryReimbursement();
    }

    function testFail_basic_sanity() public {
        assertTrue(false);
    }

    function test_basic_sanity() public {
        assertTrue(true);
    }
}

/// MockTreasury.sol

// Copyright (C) 2020 Maker Ecosystem Growth Holdings, INC, Reflexer Labs, INC

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

pragma solidity 0.6.7;

abstract contract SystemCoinLike {
    function balanceOf(address) virtual public view returns (uint);
    function approve(address, uint) virtual public returns (uint);
    function transfer(address,uint) virtual public returns (bool);
    function transferFrom(address,address,uint) virtual public returns (bool);
}

contract MockTreasury {
    SystemCoinLike  public systemCoin;

    // --- Structs ---
    struct Allowance {
        uint total;
        uint perBlock;
    }

    mapping(address => Allowance) private allowance;

    modifier accountNotTreasury(address account) {
        require(account != address(this), "MockTreasury/account-cannot-be-treasury");
        _;
    }

    constructor(
        address systemCoin_
    ) public {
        systemCoin  = SystemCoinLike(systemCoin_);
    }

    // --- Math ---
    function multiply(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function getAllowance(address account) public view returns (uint256, uint256) {
        return (allowance[account].total, allowance[account].perBlock);
    }

    function setTotalAllowance(address account, uint rad) external {
        require(account != address(0), "MockTreasury/null-account");
        allowance[account].total = rad;
    }

    function setPerBlockAllowance(address account, uint rad) external {
        require(account != address(0), "MockTreasury/null-account");
        allowance[account].perBlock = rad;
    }

    function pullFunds(address dstAccount, address token, uint wad) external accountNotTreasury(dstAccount) {
        require(dstAccount != address(0), "MockTreasury/null-dst");
        require(wad > 0, "MockTreasury/null-transfer-amount");
        require(token == address(systemCoin), "MockTreasury/token-unavailable");
        require(systemCoin.balanceOf(address(this)) >= wad, "MockTreasury/not-enough-funds");
        require(allowance[msg.sender].total >= wad * 10**27, "StabilityFeeTreasury/not-allowed");
        require(allowance[msg.sender].perBlock >= wad * 10**27, "StabilityFeeTreasury/not-allowed");
        // Transfer money
        systemCoin.transfer(dstAccount, wad);
    }
}

contract MultiMockTreasury {
    SystemCoinLike public coin_;

    // --- Structs ---
    struct Allowance {
        uint total;
        uint perBlock;
    }

    mapping(address => Allowance) private allowance;

    modifier accountNotTreasury(address account) {
        require(account != address(this), "MultiMockTreasury/account-cannot-be-treasury");
        _;
    }

    constructor(
        address systemCoin_
    ) public {
        coin_  = SystemCoinLike(systemCoin_);
    }

    // --- Math ---
    function multiply(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function systemCoin(bytes32) public view returns (address) {
        return address(coin_);
    }

    function getAllowance(bytes32, address account) public view returns (uint256, uint256) {
        return (allowance[account].total, allowance[account].perBlock);
    }

    function setTotalAllowance(bytes32, address account, uint rad) external {
        require(account != address(0), "MultiMockTreasury/null-account");
        allowance[account].total = rad;
    }

    function setPerBlockAllowance(bytes32, address account, uint rad) external {
        require(account != address(0), "MultiMockTreasury/null-account");
        allowance[account].perBlock = rad;
    }

    function pullFunds(bytes32, address dstAccount, address token, uint wad) external accountNotTreasury(dstAccount) {
        require(dstAccount != address(0), "MultiMockTreasury/null-dst");
        require(wad > 0, "MultiMockTreasury/null-transfer-amount");
        require(token == address(coin_), "MultiMockTreasury/token-unavailable");
        require(coin_.balanceOf(address(this)) >= wad, "MultiMockTreasury/not-enough-funds");
        require(allowance[msg.sender].total >= wad * 10**27, "MultiMockTreasury/not-allowed");
        require(allowance[msg.sender].perBlock >= wad * 10**27, "MultiMockTreasury/not-allowed");
        // Transfer money
        coin_.transfer(dstAccount, wad);
    }
}

contract MockRevertableTreasury {
    SystemCoinLike  public systemCoin;

    // --- Structs ---
    struct Allowance {
        uint total;
        uint perBlock;
    }

    mapping(address => Allowance) private allowance;

    constructor() public {
        systemCoin = SystemCoinLike(address(0x123));
    }

    function getAllowance(address account) public view returns (uint256, uint256) {
        return (allowance[account].total, allowance[account].perBlock);
    }

    function setTotalAllowance(address account, uint rad) external {
        require(account != address(0), "MockRevertableTreasury/null-account");
        allowance[account].total = rad;
    }

    function setPerBlockAllowance(address account, uint rad) external {
        require(account != address(0), "MockRevertableTreasury/null-account");
        allowance[account].perBlock = rad;
    }

    function pullFunds(address dstAccount, address token, uint wad) external {
        revert();
    }
}

contract MultiMockRevertableTreasury {
    // --- Structs ---
    struct Allowance {
        uint total;
        uint perBlock;
    }

    mapping(address => Allowance) private allowance;

    constructor() public {}

    function systemCoin(bytes32) public view returns (address) {
        return address(0x1);
    }

    function getAllowance(bytes32, address account) public view returns (uint256, uint256) {
        return (allowance[account].total, allowance[account].perBlock);
    }

    function setTotalAllowance(bytes32, address account, uint rad) external {
        require(account != address(0), "MockRevertableTreasury/null-account");
        allowance[account].total = rad;
    }

    function setPerBlockAllowance(bytes32, address account, uint rad) external {
        require(account != address(0), "MockRevertableTreasury/null-account");
        allowance[account].perBlock = rad;
    }

    function pullFunds(bytes32, address dstAccount, address token, uint wad) external {
        revert();
    }
}

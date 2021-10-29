// SPDX-License-Identifier: BlueOak-1.0.0
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../RToken.sol";

contract RTokenMock is RToken {
    using SafeERC20 for IERC20;

    function mint(address recipient, uint256 amount) external {
        _mint(recipient, amount);
    }

    function maxSupply() external view returns (uint256) {
        return config.maxSupply;
    }

    function issuanceRate() external view returns (uint256) {
        return config.issuanceRate;
    }

    function spread() external view returns (uint256) {
        return config.spread;
    }

    function rebalancingFreezeCost() external view returns (uint256) {
        return config.rebalancingFreezeCost;
    }

    function circuitBreaker() external view returns (address) {
        return address(config.circuitBreaker);
    }

    function txFeeCalculator() external view returns (address) {
        return address(config.txFeeCalculator);
    }

    function startMinting(address account, uint256 amount) public {
        _startSlowMinting(account, amount);
    }

    function tryProcessMintings() public {
        _tryProcessMintings();
    }

    function seizeRSR(uint256 amount) external {
        IERC20(rsrToken.tokenAddress).safeTransferFrom(address(config.insurancePool), address(this), amount);
    }

    function makeInsurancePayment(uint256 amount) external {
        _mint(address(this), amount);
        _approve(address(this), address(config.insurancePool), amount);
        config.insurancePool.makeInsurancePayment(amount);
    }
}
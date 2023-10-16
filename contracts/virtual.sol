// SPDX-License-Identifier: AGPL-3.0-only
// Author: Rashad Haddad, GitHub @rashadalh
// Desc: Provides logic to manage payoffs in virtual box.
pragma solidity ^0.8.20;

import "../libs/ReentrancyGuard.sol";
import "../libs/IERC20.sol";
import "../libs/AggregatorV3Interface.sol";

contract Box is ReentrancyGuard {
    // public variables
    address public owner;
    address public collateralAsset;
    address public longToken;
    address public shortToken;
    uint256 public longTokenValue;
    uint256 public shortTokenValue;
    address public oracle;
    uint256 private collateralHeld;

    /* @notice Creates a new box
       @param collateralAsset The address of the collateral asset
       @param longToken The address of the long token
       @param shortToken The address of the short token
       @param oracle The address of the oracle

       The box is a virtual contruct that holds value in only the collateral asset. Everything else is a virtual represent of a token.
       The oracle address refers to a chainlink oracle that provides the price of the asset to value the long and short tokens against the collateral asset.

       For example. If the collateral asset is USDC, then the longToken could be WETH, the shortToken could be USDC, and the oracle could be the WETH/USDC price feed.
    */
    constructor(address _collateralAsset, address _longToken, address _shortToken, address _oracle) {
        collateralAsset = _collateralAsset;
        longToken = _longToken;
        shortToken = _shortToken;
        oracle = _oracle;

        owner = msg.sender;
        collateralHeld = 0;
        longTokenValue = 0;
        shortTokenValue = 0;
    }

    /* Approve's contract to spend value from msg.sender */
    function approveSpending(uint256 maxSpending) nonReentrant external {
        // approve spending of maxSpending
        IERC20(collateralAsset).approve(address(this), maxSpending);
    }

    function _getCollateralHeld() internal view returns (uint256) {
        return collateralHeld;
    }
    function getCollateralHeld() external view returns (uint256) {
        return _getCollateralHeld();
    }

    function _updateValues() internal {
        // get latest price from chainlink oracle
        (, int256 answer,,,) = AggregatorV3Interface(oracle).latestRoundData();

        // set long and short token values
        // TODO - check decimals
        longTokenValue = uint256(answer) * _getCollateralHeld();
        shortTokenValue = collateralHeld - longTokenValue;
    }

    function depositCollateral(uint256 amount) nonReentrant external {
        // require amount > 0
        require(amount > 0, "Amount must be greater than 0");

        // check that user has sufficient balance
        require(IERC20(collateralAsset).balanceOf(msg.sender) >= amount, "Insufficient balance");

        // check that user has approved spending
        require(IERC20(collateralAsset).allowance(msg.sender, address(this)) >= amount, "Insufficient allowance");

        // transfer amount from user to box
        IERC20(collateralAsset).transferFrom(msg.sender, address(this), amount);
        
        // set collateralHeld to amount
        collateralHeld += amount;

        // update values
        _updateValues();
    }

    // This function should only be called by external trade manager
    function withdraw(uint256 amount, address to) nonReentrant external {
        require(msg.sender == owner, "Only owner can withdraw");

        // require amount > 0
        require(amount > 0, "Amount must be greater than 0");

        // check that box has sufficient balance
        require(IERC20(collateralAsset).balanceOf(address(this)) >= amount, "Insufficient balance");

        // transfer amount from box to to
        IERC20(collateralAsset).transfer(to, amount);

        // update long and short values
        _updateValues();
    }
}
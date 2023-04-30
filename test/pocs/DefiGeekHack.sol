pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../../pocs/DefiGeekHack.sol";

contract RariHackTest is Test {
    uint256 mainnetFork;

    DefiGeekHack public defiGeekHack;

    function setUp() public {
        mainnetFork = vm.createFork("eth");
        vm.selectFork(mainnetFork);
        vm.rollFork(17_066_755 - 1);


        defiGeekHack = new DefiGeekHack();
    }

    function testAttack() public {
        defiGeekHack.initiateAttack();
    }
}

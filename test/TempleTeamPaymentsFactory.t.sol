// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/TempleTeamPaymentsFactory.sol";

contract TempleTeamPaymentsFactoryTest is Test {
    //
    TempleTeamPaymentsFactory public factory;
    IERC20 public temple = IERC20(0x470EBf5f030Ed85Fc1ed4C2d36B9DD02e77CF1b7);
    address multisig = 0xe2Bb722DA825eBfFa1E368De244bdF08ed68B5c4;
    address testUser = vm.addr(1);

    function setUp() public {
        vm.createSelectFork("https://rpc.ankr.com/eth");

        factory = new TempleTeamPaymentsFactory(0);
        factory.transferOwnership(multisig);
    }

    function testDirectPayoutsAssertions(uint256 _length) internal {
        uint256[] memory previousBalances = new uint256[](_length);
        address[] memory recip = new address[](_length);
        uint256[] memory values = new uint256[](_length);
        for (uint256 i; i < recip.length; i++) {
            address test = vm.addr(i + 1);
            recip[i] = test;
            uint256 testAmount = (i + 1) * 1 ether;
            values[i] = testAmount;
            previousBalances[i] = temple.balanceOf(test);
        }

        vm.startPrank(multisig);
        temple.approve(address(factory), type(uint256).max);
        factory.directPayouts(temple, recip, values);
        vm.stopPrank();

        for (uint256 i; i < recip.length; i++) {
            address tester = vm.addr(i + 1);
            uint256 currentBalance = temple.balanceOf(tester);
            assertEq(currentBalance, previousBalances[i] + values[i]);
        }
    }

    function testDirectPayoutsSingle() public {
        uint256 lengthOfUsers = 1;
        testDirectPayoutsAssertions(lengthOfUsers);
    }

    function testDirectPayoutsMany() public {
        uint256 lengthOfUsers = 50;
        testDirectPayoutsAssertions(lengthOfUsers);
    }

    function testDeployPayoutsAssertions(
        uint40 _claimStartTimestamp,
        uint256 _userTestLength
    ) internal returns (TempleTeamPaymentsV2) {
        address[] memory recip = new address[](_userTestLength);
        uint256[] memory values = new uint256[](_userTestLength);
        uint256 totalPaid;
        for (uint256 i; i < recip.length; i++) {
            address test = vm.addr(i + 1);
            recip[i] = test;
            uint256 testAmount = (i + 1) * 1 ether;
            values[i] = testAmount;
            totalPaid += testAmount;
        }

        vm.startPrank(multisig);
        temple.approve(address(factory), type(uint256).max);
        TempleTeamPaymentsV2 testContract = factory.deployPayouts(
            temple,
            recip,
            values,
            totalPaid,
            _claimStartTimestamp
        );
        vm.stopPrank();

        for (uint256 i; i < recip.length; i++) {
            address tester = vm.addr(i + 1);
            uint256 currentBalance = testContract.allocation(tester);
            assertEq(currentBalance, values[i]);
        }

        return testContract;
    }

    function testDeployPayoutsSingle() public returns (TempleTeamPaymentsV2) {
        return testDeployPayoutsAssertions(uint40(block.timestamp + 1 days), 1);
    }

    function testDeployPayoutsMany() public returns (TempleTeamPaymentsV2) {
        return
            testDeployPayoutsAssertions(uint40(block.timestamp + 1 days), 50);
    }

    function testRoundIncrementsDirectPayout() public {
        uint256 prev = factory.lastPaidEpoch();
        testDirectPayoutsSingle();
        assertEq(factory.lastPaidEpoch(), prev + 1);
    }

    function testRoundIncrementsDeployPayout() public {
        uint256 prev = factory.lastPaidEpoch();
        testDeployPayoutsSingle();
        assertEq(factory.lastPaidEpoch(), prev + 1);
    }

    function testCanClaimAllocation() public {
        TempleTeamPaymentsV2 testContract = testDeployPayoutsSingle();

        uint256 canClaimAfter = testContract.claimOpenTimestamp();
        vm.warp(canClaimAfter);

        uint256 prev = testContract.temple().balanceOf(testUser);
        vm.prank(testUser);
        testContract.claim();

        assertEq(
            testContract.temple().balanceOf(testUser),
            prev + testContract.allocation(testUser)
        );
    }

    function testCannotClaimEarly() public {
        TempleTeamPaymentsV2 testContract = testDeployPayoutsSingle();
        uint256 canClaimAfter = testContract.claimOpenTimestamp();

        vm.warp(canClaimAfter - 1);

        vm.prank(testUser);
        vm.expectRevert();
        testContract.claim();
    }

    function testCannotClaimTwice() public {
        TempleTeamPaymentsV2 testContract = testDeployPayoutsSingle();
        uint256 canClaimAfter = testContract.claimOpenTimestamp();

        vm.warp(canClaimAfter);
        vm.startPrank(testUser);

        testContract.claim();

        vm.expectRevert();
        testContract.claim();
    }

    function testCannotClaimPause() public {
        TempleTeamPaymentsV2 testContract = testDeployPayoutsSingle();

        vm.prank(multisig);
        testContract.toggleMember(testUser);

        vm.expectRevert();
        vm.prank(testUser);
        testContract.claim();
    }

    function testCannotInitializeTwice() public {
        TempleTeamPaymentsV2 testContract = testDeployPayoutsSingle();

        vm.expectRevert();
        testContract.initialize(temple);
    }

    function testCannotSetAllocationsZeroAddress() public {
        TempleTeamPaymentsV2 testContract = testDeployPayoutsSingle();

        address[] memory addrs = new address[](1);
        addrs[0] = address(0);

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1 ether;

        vm.expectRevert();
        vm.prank(multisig);
        testContract.setAllocations(addrs, amounts);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";
import "../src/Treasury.sol";
import "../src/MyGovernor.sol";
import "../src/Box.sol";

contract DAOTest is Test {
    GovernanceToken token;
    Treasury timelock;
    MyGovernor governor;
    Box box;

    address deployer = address(0x1);
    address voter1 = address(0x2);
    address voter2 = address(0x3);
    address treasuryRecipient = address(0x4);

    uint256 public constant MIN_DELAY = 2 days; // Timelock
    uint256 public constant VOTING_DELAY = 7200; // 1 день
    uint256 public constant VOTING_PERIOD = 50400; // 1 неделя

    function setUp() public {
        vm.startPrank(deployer);

        // 1токен
        token = new GovernanceToken();

        // 2 Timelock
        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);
        timelock = new Treasury(MIN_DELAY, proposers, executors, deployer);

        // 3 Governor
        governor = new MyGovernor(token, timelock);

        // 4 Timelock Role
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        bytes32 adminRole = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(proposerRole, address(governor));
        timelock.grantRole(executorRole, address(0));
        timelock.revokeRole(adminRole, deployer);

        // 5 Box
        box = new Box(address(timelock));

        // 6
        token.transfer(voter1, 5_000_000 * 10 ** 18); // 5% от Supply
        token.transfer(voter2, 2_000_000 * 10 ** 18); // 2% от Supply

        token.transfer(address(timelock), 10_000_000 * 10 ** 18);
        vm.deal(address(timelock), 10 ether);

        vm.stopPrank();

        vm.prank(voter1);
        token.delegate(voter1);

        vm.prank(voter2);
        token.delegate(voter2);

        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 12);
    }

    // ТЕСТ 1
    function test_1_DelegateToAnother() public {
        vm.prank(voter2);
        token.delegate(voter1);
        assertEq(token.delegates(voter2), voter1);
    }

    // ТЕСТ 2
    function test_2_ProposeFailsWithoutThreshold() public {
        address poorUser = address(0x99);
        vm.prank(poorUser);

        address[] memory targets = new address[](1);
        targets[0] = address(box);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("store(uint256)", 777);

        vm.expectRevert();
        governor.propose(targets, values, calldatas, "This should fail");
    }

    // ТЕСТ 3
    function test_3_ProposeSuccessfully() public returns (uint256) {
        address[] memory targets = new address[](1);
        targets[0] = address(box);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("store(uint256)", 42);

        vm.prank(voter1);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Set Box value to 42");

        assertEq(uint256(governor.state(proposalId)), 0);
        return proposalId;
    }

    // ТЕСТ 4
    function test_4_ProposalFails_NoQuorum() public {
        uint256 proposalId = test_3_ProposeSuccessfully();
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voter2);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(governor.state(proposalId)), 3);
    }

    // ТЕСТ 5
    function test_5_ProposalDefeated_Against() public {
        uint256 proposalId = test_3_ProposeSuccessfully();
        vm.roll(block.number + VOTING_DELAY + 1);

        vm.prank(voter1);
        governor.castVote(proposalId, 0);

        vm.roll(block.number + VOTING_PERIOD + 1);

        assertEq(uint256(governor.state(proposalId)), 3);
    }

    // ТЕСТ 6, 7, 8
    function test_6_7_8_FullLifecycle_Box() public {
        // Propose
        address[] memory targets = new address[](1);
        targets[0] = address(box);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("store(uint256)", 42);
        bytes32 descriptionHash = keccak256(bytes("Set Box value to 42"));

        vm.prank(voter1);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Set Box value to 42");

        //  Vote
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint256(governor.state(proposalId)), 4);

        //  Queue
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), 5);

        // ШExecute
        vm.warp(block.timestamp + MIN_DELAY + 1);
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(uint256(governor.state(proposalId)), 7);
        assertEq(box.retrieve(), 42);
    }

    // ТЕСТ 9
    function test_9_CannotExecuteBeforeTimelock() public {
        address[] memory targets = new address[](1);
        targets[0] = address(box);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("store(uint256)", 42);
        bytes32 descriptionHash = keccak256(bytes("Set Box value to 42"));

        vm.prank(voter1);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Set Box value to 42");

        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.expectRevert();
        governor.execute(targets, values, calldatas, descriptionHash);
    }

    // ТЕСТ 10
    function test_10_BoxRevertsIfNotTimelock() public {
        vm.prank(voter1);
        vm.expectRevert();
        box.store(99);
    }

    // ТЕСТ 11
    function test_11_TreasuryTransfer_Token() public {
        uint256 amountToTransfer = 1000 * 10 ** 18;

        address[] memory targets = new address[](1);
        targets[0] = address(token);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);

        calldatas[0] = abi.encodeWithSignature("transfer(address,uint256)", treasuryRecipient, amountToTransfer);
        bytes32 descriptionHash = keccak256(bytes("Send tokens to recipient"));

        vm.prank(voter1);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Send tokens to recipient");

        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(token.balanceOf(treasuryRecipient), amountToTransfer);
    }

    // ТЕСТ 12
    function test_12_TreasuryTransfer_ETH() public {
        uint256 amountToTransfer = 1 ether;

        address[] memory targets = new address[](1);
        targets[0] = treasuryRecipient;
        uint256[] memory values = new uint256[](1);
        values[0] = amountToTransfer;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = "";
        bytes32 descriptionHash = keccak256(bytes("Send ETH to recipient"));

        uint256 initialBalance = treasuryRecipient.balance;

        vm.prank(voter1);
        uint256 proposalId = governor.propose(targets, values, calldatas, "Send ETH to recipient");

        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(voter1);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + VOTING_PERIOD + 1);
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(treasuryRecipient.balance, initialBalance + amountToTransfer);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/GovernanceToken.sol";
import "../src/TokenVesting.sol";

contract GovernanceTokenTest is Test {
    GovernanceToken token;
    TokenVesting vesting;

    
    uint256 deployerPrivateKey = 0x12345;
    address deployer;
    
    address user1 = address(0x1);
    address user2 = address(0x2);

    function setUp() public {
        deployer = vm.addr(deployerPrivateKey);
        
        
        vm.startPrank(deployer); 

        token = new GovernanceToken();
        vesting = new TokenVesting(address(token));

        
        uint256 teamAllocation = 40_000_000 * 10**18;
        token.approve(address(vesting), teamAllocation);
        vesting.deposit(teamAllocation);

        
        token.transfer(user1, 1000 * 10**18);
        
        vm.stopPrank();
    }

    // 1
    function test_TotalSupply() public view {
        assertEq(token.totalSupply(), 100_000_000 * 10**18);
    }

    // 2
    function test_Delegation() public {
        vm.prank(user1);
        token.delegate(user2);
        assertEq(token.delegates(user1), user2);
    }

    // 3
    function test_VotingPowerSnapshots() public {
        vm.prank(user1);
        token.delegate(user1);

        vm.roll(block.number + 1);

        assertEq(token.getPastVotes(user1, block.number - 1), 1000 * 10**18);
    }

    // 4
    function test_NoVotingPowerWithoutDelegation() public view {
        assertEq(token.getVotes(user1), 0);
    }

    // 5
    function test_PermitSignature() public {
        uint256 deadline = block.timestamp + 1 days;
        uint256 amount = 100 * 10**18;
        uint256 nonce = token.nonces(deployer);

        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                deployer,
                user1,
                amount,
                nonce,
                deadline
            )
        );

        
        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", token.DOMAIN_SEPARATOR(), structHash)
        );

        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(deployerPrivateKey, digest);

        
        token.permit(deployer, user1, amount, deadline, v, r, s);

        
        assertEq(token.allowance(deployer, user1), amount);
    }

    // 6
    function test_VestingNoReleaseBeforeTime() public {
        vm.prank(deployer);
        vm.expectRevert("No tokens to release");
        vesting.release();
    }

    // 7
    function test_VestingPartialRelease() public {
        vm.warp(block.timestamp + 182 days + 12 hours);

        vm.prank(deployer);
        vesting.release();

        
        uint256 vestingBalance = token.balanceOf(address(vesting));
        assertEq(vestingBalance, 20_000_000 * 10**18);
    }

    // 8
    function test_VestingFullRelease() public {
        vm.warp(block.timestamp + 365 days);

        vm.prank(deployer);
        vesting.release();

        
        assertEq(token.balanceOf(address(vesting)), 0); 
    }
}
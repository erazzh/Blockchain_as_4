// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/GovernanceToken.sol";
import "../src/TokenVesting.sol";
import "../src/Treasury.sol";
import "../src/MyGovernor.sol";
import "../src/Box.sol";

contract DeployDAO is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        vm.startBroadcast(deployerKey);

        // 1 токен
        GovernanceToken token = new GovernanceToken();

        // 2 Timelock
        address[] memory emptyArray = new address[](0);
        // Передаем 2 days и массивы напрямую, не создавая лишних переменных
        Treasury timelock = new Treasury(2 days, emptyArray, emptyArray, deployer);

        // 3  Governor
        MyGovernor governor = new MyGovernor(token, timelock);

        // 4 timelock roles
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));

        // 5 Box
        Box box = new Box(address(timelock));

        // 6Vesting
        TokenVesting vesting = new TokenVesting(address(token));

        token.approve(address(vesting), 40_000_000 * 10 ** 18);
        vesting.deposit(40_000_000 * 10 ** 18);

        token.transfer(address(timelock), 30_000_000 * 10 ** 18);

        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployer);

        vm.stopBroadcast();
    }
}

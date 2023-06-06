// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../src/solc-0.8/DeployRdpxEthOracle.sol";
import "../src/solc-0.8/IRdpxEthOracle.sol";

import "forge-std/Test.sol";

contract DeployRdpxEthOracleTest is Test {
    string ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");

    IRdpxEthOracle rdpxEthOracle;

    address alice;

    function setUp() public {
        vm.createSelectFork(ARBITRUM_RPC_URL, 98202500);

        alice = makeAddr("alice");
    }

    function test_deploy() public {
        DeployRdpxEthOracle deployer = new DeployRdpxEthOracle();

        address rdpxEthOracleAddress = deployer.deploy(
            0x7418F5A2621E13c05d1EFBd71ec922070794b90a
        );

        rdpxEthOracle = IRdpxEthOracle(rdpxEthOracleAddress);

        vm.warp(block.timestamp + 31 minutes);

        rdpxEthOracle.update();
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

import "../src/RdpxEthOracle.sol";

import "forge-std/Test.sol";

contract RdpxEthOracleTest is Test {
    string ARBITRUM_RPC_URL = vm.envString("ARBITRUM_RPC_URL");

    RdpxEthOracle rdpxEthOracle;

    address rdpx = 0x32Eb7902D4134bf98A28b963D26de779AF92A212;

    address weth = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    address alice;

    function setUp() public {
        alice = makeAddr("alice");

        vm.createSelectFork(ARBITRUM_RPC_URL, 98202500);

        rdpxEthOracle = new RdpxEthOracle();

        vm.prank(alice);

        rdpxEthOracle.initialize(
            IUniswapV2Pair(0x7418F5A2621E13c05d1EFBd71ec922070794b90a),
            alice
        );
    }

    function test_initialize() public {
        RdpxEthOracle test = new RdpxEthOracle();

        test.initialize(
            IUniswapV2Pair(0x7418F5A2621E13c05d1EFBd71ec922070794b90a),
            alice
        );
    }

    function test_initialize_revert_ALREADY_INITIALIZED() public {
        vm.expectRevert("RdpxEthOracle: ALREADY_INITIALIZED");
        rdpxEthOracle.initialize(
            IUniswapV2Pair(0x7418F5A2621E13c05d1EFBd71ec922070794b90a),
            alice
        );
    }

    function test_updateTimePeriod_revert_NOT_ADMIN() public {
        vm.expectRevert("RdpxEthOracle: NOT_ADMIN");
        rdpxEthOracle.updateTimePeriod(35 minutes);
    }

    function test_updateTimePeriod() public {
        vm.prank(alice);

        rdpxEthOracle.updateTimePeriod(35 minutes);

        uint timePeriod = rdpxEthOracle.timePeriod();

        assertEq(timePeriod, 35 minutes);
    }

    function test_updateNonUpdateTolerance_revert_NOT_ADMIN() public {
        vm.expectRevert("RdpxEthOracle: NOT_ADMIN");
        rdpxEthOracle.updateNonUpdateTolerance(6 minutes);
    }

    function test_updateNonUpdateTolerance() public {
        vm.prank(alice);

        rdpxEthOracle.updateNonUpdateTolerance(6 minutes);

        uint nonUpdateTolerance = rdpxEthOracle.nonUpdateTolerance();

        assertEq(nonUpdateTolerance, 6 minutes);
    }

    function test_getRdpxPriceInEth_revert_PRICE_ZERO() public {
        vm.expectRevert("RdpxEthOracle: PRICE_ZERO");
        rdpxEthOracle.getRdpxPriceInEth();
    }

    function test_getEthPriceInRdpx_revert_PRICE_ZERO() public {
        vm.expectRevert("RdpxEthOracle: PRICE_ZERO");
        rdpxEthOracle.getEthPriceInRdpx();
    }

    function test_getETHPx() public {
        vm.warp(block.timestamp + 30 minutes);

        rdpxEthOracle.update();

        uint px0 = rdpxEthOracle.getETHPx(rdpxEthOracle.token0());
        uint px1 = rdpxEthOracle.getETHPx(rdpxEthOracle.token1());

        console.log("px0", px0);
        console.log("px1", px1);
    }

    function test_getLpPrice() public {
        vm.warp(block.timestamp + 30 minutes);

        rdpxEthOracle.update();

        uint lpPriceInEth = rdpxEthOracle.getLpPriceInEth();
        uint lpPriceInRdpx = rdpxEthOracle.getLpPriceInRdpx();

        console.log("LP Price in ETH", lpPriceInEth);
        console.log("LP Price in rDPX", lpPriceInRdpx);
    }

    function test_update() public {
        vm.warp(block.timestamp + 30 minutes);

        rdpxEthOracle.update();

        uint rdpxPrice = rdpxEthOracle.consult(rdpx, 1e18);

        uint ethPrice = rdpxEthOracle.consult(weth, 1e18);

        console.log("rDPX Price: ", rdpxPrice);
        console.log("ETH Price: ", ethPrice);
    }

    function test_update_revert_PERIOD_NOT_ELAPSED() public {
        vm.warp(block.timestamp + 30 minutes);
        rdpxEthOracle.update();
        vm.expectRevert("RdpxEthOracle: PERIOD_NOT_ELAPSED");
        rdpxEthOracle.update();
    }

    function test_update_twice() public {
        vm.warp(block.timestamp + 30 minutes);

        rdpxEthOracle.update();

        vm.warp(block.timestamp + 30 minutes);

        rdpxEthOracle.update();

        rdpxEthOracle.getRdpxPriceInEth();
    }

    function test_getRdpxPriceInEth_UPDATE_TOLERANCE_EXCEEDED() public {
        vm.warp(block.timestamp + 30 minutes);

        rdpxEthOracle.update();

        vm.warp(block.timestamp + 36 minutes);

        vm.expectRevert("RdpxEthOracle: UPDATE_TOLERANCE_EXCEEDED");

        rdpxEthOracle.getRdpxPriceInEth();
    }

    function test_getEthPriceInRdpx_UPDATE_TOLERANCE_EXCEEDED() public {
        vm.warp(block.timestamp + 30 minutes);

        rdpxEthOracle.update();

        vm.warp(block.timestamp + 36 minutes);

        vm.expectRevert("RdpxEthOracle: UPDATE_TOLERANCE_EXCEEDED");

        rdpxEthOracle.getEthPriceInRdpx();
    }

    function test_consult_INVALID_TOKEN() public {
        vm.warp(block.timestamp + 30 minutes);

        rdpxEthOracle.update();

        vm.expectRevert("RdpxEthOracle: INVALID_TOKEN");

        rdpxEthOracle.consult(address(0), 1e18);
    }
}

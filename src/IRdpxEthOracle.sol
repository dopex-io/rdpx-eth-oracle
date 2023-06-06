// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";

interface IRdpxEthOracle {
    event Update(
        FixedPoint.uq112x112 price0Average,
        FixedPoint.uq112x112 price1Average,
        uint price0Cumulative,
        uint price1Cumulative
    );

    event UpdateTimePeriod(uint timePeriod);

    event UpdateNonUpdateTolerance(uint nonUpdateTolerance);

    function initialize(IUniswapV2Pair _pair, address admin) external;

    function updateTimePeriod(uint _timePeriod) external;

    function updateNonUpdateTolerance(uint _nonUpdateTolerance) external;

    function update() external;

    function consult(
        address token,
        uint amountIn
    ) external view returns (uint amountOut);

    function getRdpxPriceInEth() external view returns (uint price);
}

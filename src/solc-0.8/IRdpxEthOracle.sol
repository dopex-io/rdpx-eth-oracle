// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IRdpxEthOracle {
    function initialize(address _pair, address admin) external;

    function updateTimePeriod(uint _timePeriod) external;

    function updateNonUpdateTolerance(uint _nonUpdateTolerance) external;

    function update() external;

    function consult(
        address token,
        uint amountIn
    ) external view returns (uint amountOut);

    function getRdpxPriceInEth() external view returns (uint price);
}

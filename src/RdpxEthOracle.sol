// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

// Interfaces
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";

// Libraries
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";

// Contracts
import "@openzeppelin/contracts/access/AccessControl.sol";

import "forge-std/console.sol";

// Fixed window oracle that recomputes the average price for the entire period once every period
// note that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract RdpxEthOracle is AccessControl {
    using FixedPoint for *;

    uint public timePeriod = 30 minutes;
    uint public nonUpdateTolerance = 5 minutes;

    IUniswapV2Pair immutable pair;
    address public immutable token0;
    address public immutable token1;

    uint public price0CumulativeLast;
    uint public price1CumulativeLast;
    uint32 public blockTimestampLast;
    FixedPoint.uq112x112 public price0Average;
    FixedPoint.uq112x112 public price1Average;

    event Update(
        FixedPoint.uq112x112 price0Average,
        FixedPoint.uq112x112 price1Average,
        uint price0Cumulative,
        uint price1Cumulative
    );

    event UpdateTimePeriod(uint timePeriod);

    event UpdateNonUpdateTolerance(uint nonUpdateTolerance);

    constructor(IUniswapV2Pair _pair) public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        pair = _pair;

        token0 = _pair.token0();
        token1 = _pair.token1();

        price0CumulativeLast = _pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        price1CumulativeLast = _pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = _pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, "RdpxEthOracle: NO_RESERVES"); // ensure that there's liquidity in the pair
    }

    function updateTimePeriod(uint _timePeriod) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "RdpxEthOracle: NOT_ADMIN"
        );
        timePeriod = _timePeriod;

        emit UpdateTimePeriod(_timePeriod);
    }

    function updateNonUpdateTolerance(uint _nonUpdateTolerance) external {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "RdpxEthOracle: NOT_ADMIN"
        );
        nonUpdateTolerance = _nonUpdateTolerance;

        emit UpdateNonUpdateTolerance(_nonUpdateTolerance);
    }

    function update() external {
        (
            uint price0Cumulative,
            uint price1Cumulative,
            uint32 blockTimestamp
        ) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        console.log(timeElapsed, blockTimestamp, blockTimestampLast);

        // ensure that at least one full timePeriod has passed since the last update
        require(timeElapsed >= timePeriod, "RdpxEthOracle: PERIOD_NOT_ELAPSED");

        // overflow is desired, casting never truncates
        // cumulative price is in (uq112x112 price * seconds) units so we simply wrap it after division by time elapsed
        price0Average = FixedPoint.uq112x112(
            uint224((price0Cumulative - price0CumulativeLast) / timeElapsed)
        );
        price1Average = FixedPoint.uq112x112(
            uint224((price1Cumulative - price1CumulativeLast) / timeElapsed)
        );

        price0CumulativeLast = price0Cumulative;
        price1CumulativeLast = price1Cumulative;
        blockTimestampLast = blockTimestamp;

        emit Update(
            price0Average,
            price1Average,
            price0CumulativeLast,
            price1CumulativeLast
        );
    }

    // note this will always return 0 before update has been called successfully for the first time.
    function consult(
        address token,
        uint amountIn
    ) public view returns (uint amountOut) {
        if (token == token0) {
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            require(token == token1, "RdpxEthOracle: INVALID_TOKEN");
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }

    function getRdpxPriceInEth() external view returns (uint price) {
        require(
            blockTimestampLast + timePeriod + nonUpdateTolerance >
                block.timestamp,
            "RdpxEthOracle: UPDATE_TOLERANCE_EXCEEDED"
        );

        price = consult(0x32Eb7902D4134bf98A28b963D26de779AF92A212, 1e18);

        require(price > 0, "RdpxEthOracle: PRICE_ZERO");
    }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.6.6;
pragma experimental ABIEncoderV2;

// Interfaces
import "./IRdpxEthOracle.sol";

// Libraries
import "@uniswap/lib/contracts/libraries/FixedPoint.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2OracleLibrary.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";

// Contracts
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @title rDPX/ETH TWAP price oracle derived from a UniswapV2 pool
/// @author Dopex
/// @notice Fixed window oracle that recomputes the average price for the entire period once every period
/// @dev that the price average is only guaranteed to be over at least 1 period, but may be over a longer period
contract RdpxEthOracle is AccessControl, IRdpxEthOracle {
    using FixedPoint for *;

    /// @notice The time period of the TWAP
    uint public timePeriod = 30 minutes;

    /// @notice The Non update tolerance, this is the maximum time allowed without an update
    /// (beyond the timePeriod) before which the price getter view reverts
    uint public nonUpdateTolerance = 5 minutes;

    /// @notice The last cumulative price stored for token0 against token1
    uint public price0CumulativeLast;

    /// @notice The last cumulative price stored for token1 against token0
    uint public price1CumulativeLast;

    /// @notice The last block.timestamp stored
    uint32 public blockTimestampLast;

    /// @notice The current price average of token0 against token1
    FixedPoint.uq112x112 public price0Average;

    /// @notice The current price average of token1 against token0
    FixedPoint.uq112x112 public price1Average;

    /// @notice The pair contract
    IUniswapV2Pair public pair;

    /// @notice The token0 address
    address public token0;

    /// @notice The token1 address
    address public token1;

    /// @notice Whether this contract was initialized or not
    bool public initialized;

    /// @notice Emitted when update() is called on this contract
    /// @param price0Average The price average of token0 against token1
    /// @param price1Average The price average of token1 against token0
    /// @param price0Cumulative The cumulative price stored for token0 against token1
    /// @param price1Cumulative The cumulative price stored for token1 against token0
    event Update(
        FixedPoint.uq112x112 price0Average,
        FixedPoint.uq112x112 price1Average,
        uint price0Cumulative,
        uint price1Cumulative
    );

    /// @notice Emitted when updateTimePeriod() is called on this contract
    /// @param timePeriod The new timePeriod
    event UpdateTimePeriod(uint timePeriod);

    /// @notice Emitted when updateNonUpdateTolerance() is called on this contract
    /// @param nonUpdateTolerance The new nonUpdateTolerance
    event UpdateNonUpdateTolerance(uint nonUpdateTolerance);

    /// @notice Initializes the contract with the pair contract and admin address
    /// @dev This function is used in place of a constructor to make it easy to deploy using bytecode
    /// for different version of solidity
    /// @param _pair The pair contract
    /// @param admin The admin address the return variables of a contract’s function state variable
    function initialize(IUniswapV2Pair _pair, address admin) external override {
        require(!initialized, "RdpxEthOracle: ALREADY_INITIALIZED");
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        pair = _pair;
        token0 = _pair.token0();
        token1 = _pair.token1();
        price0CumulativeLast = _pair.price0CumulativeLast(); // fetch the current accumulated price value (1 / 0)
        price1CumulativeLast = _pair.price1CumulativeLast(); // fetch the current accumulated price value (0 / 1)
        uint112 reserve0;
        uint112 reserve1;
        (reserve0, reserve1, blockTimestampLast) = _pair.getReserves();
        require(reserve0 != 0 && reserve1 != 0, "RdpxEthOracle: NO_RESERVES"); // ensure that there's liquidity in the pair
        initialized = true;
    }

    /// @notice Updates the time period of the TWAP
    /// @dev Only callable by admin
    /// @param _timePeriod The new time period
    function updateTimePeriod(uint _timePeriod) external override {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "RdpxEthOracle: NOT_ADMIN"
        );
        timePeriod = _timePeriod;

        emit UpdateTimePeriod(_timePeriod);
    }

    /// @notice Updates the nonUpdateTolerance
    /// @dev Only callable by admin
    /// @param _nonUpdateTolerance The new nonUpdateTolerance
    function updateNonUpdateTolerance(
        uint _nonUpdateTolerance
    ) external override {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "RdpxEthOracle: NOT_ADMIN"
        );
        nonUpdateTolerance = _nonUpdateTolerance;

        emit UpdateNonUpdateTolerance(_nonUpdateTolerance);
    }

    /// @notice Updates the cumulative and average prices of the tokens of the pair
    function update() external override {
        (
            uint price0Cumulative,
            uint price1Cumulative,
            uint32 blockTimestamp
        ) = UniswapV2OracleLibrary.currentCumulativePrices(address(pair));
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired

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

    /// @notice Returns the amountOut for a token and amountIn with the current TWAP stored
    /// @dev this will always return 0 before update has been called successfully for the first time
    /// @param token the address of the token to return the amountOut of
    /// @param amountIn the amountIn for the token
    /// @return amountOut the amountOut for the token for a amountIn
    function consult(
        address token,
        uint amountIn
    ) public view override returns (uint amountOut) {
        if (token == token0) {
            amountOut = price0Average.mul(amountIn).decode144();
        } else {
            require(token == token1, "RdpxEthOracle: INVALID_TOKEN");
            amountOut = price1Average.mul(amountIn).decode144();
        }
    }

    /// @notice Returns the price of rDPX in ETH
    /// @return price price of rDPX in ETH in 1e18 decimals
    function getRdpxPriceInEth() external view override returns (uint price) {
        require(
            blockTimestampLast + timePeriod + nonUpdateTolerance >
                block.timestamp,
            "RdpxEthOracle: UPDATE_TOLERANCE_EXCEEDED"
        );

        price = consult(0x32Eb7902D4134bf98A28b963D26de779AF92A212, 1e18);

        require(price > 0, "RdpxEthOracle: PRICE_ZERO");
    }
}

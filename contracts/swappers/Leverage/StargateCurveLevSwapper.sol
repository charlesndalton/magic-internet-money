// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "../../interfaces/ILevSwapperGeneric.sol";
import "../../interfaces/IBentoBoxV1.sol";
import "../../interfaces/IERC20.sol";
import "../../interfaces/curve/ICurvePool.sol";
import "../../interfaces/stargate/IStargateRouter.sol";
import "../../interfaces/stargate/IStargatePool.sol";

/// @notice Leverage Swapper for Stargate LP using Curve
contract StargateCurveLevSwapper is ILevSwapperGeneric {
    IBentoBoxV1 public immutable degenBox;
    IStargatePool public immutable pool;
    IStargateRouter public immutable stargateRouter;
    CurvePool public immutable curvePool;
    int128 public immutable curvePoolI;
    int128 public immutable curvePoolJ;
    uint256 public immutable poolId;
    IERC20 public immutable underlyingPoolToken;
    IERC20 public immutable mim;

    constructor(
        IBentoBoxV1 _degenBox,
        IStargatePool _pool,
        uint16 _poolId,
        IStargateRouter _stargateRouter,
        CurvePool _curvePool,
        int128 _curvePoolI,
        int128 _curvePoolJ
    ) {
        degenBox = _degenBox;
        pool = _pool;
        poolId = _poolId;
        stargateRouter = _stargateRouter;
        curvePool = _curvePool;
        curvePoolI = _curvePoolI;
        curvePoolJ = _curvePoolJ;
        mim = IERC20(_curvePool.coins(uint128(_curvePoolJ)));
        underlyingPoolToken = IERC20(_pool.token());

        mim.approve(address(_curvePool), type(uint256).max);
        underlyingPoolToken.approve(address(_stargateRouter), type(uint256).max);
        IERC20(address(pool)).approve(address(_degenBox), type(uint256).max);
    }

    // Swaps to a flexible amount, from an exact input amount
    function swap(
        address recipient,
        uint256 shareToMin,
        uint256 shareFrom
    ) public override returns (uint256 extraShare, uint256 shareReturned) {
        (uint256 amount, ) = degenBox.withdraw(mim, address(this), address(this), 0, shareFrom);

        // MIM -> Stargate Pool Underlying Token
        amount = curvePool.exchange_underlying(curvePoolI, curvePoolJ, amount, 0, address(this));

        // Underlying Token -> Stargate Pool LP
        stargateRouter.addLiquidity(poolId, amount, address(this));
        amount = IERC20(address(pool)).balanceOf(address(this));

        (, shareReturned) = degenBox.deposit(IERC20(address(pool)), address(this), recipient, amount, 0);
        extraShare = shareReturned - shareToMin;
    }
}

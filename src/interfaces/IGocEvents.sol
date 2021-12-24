// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IGocEvents {
    event MarketCreated(uint256 moveValue, address by);
    event OutcomeBought(uint256 moveValue, address by, uint256 amountIn, uint256 amunt0Out, uint256 amount1Out);
    event OutcomeSold(uint256 moveValue, address by, uint256 amountOut, uint256 amunt0In, uint256 amount1In);
    event WinningRedeemed(uint256 moveValue, address by);
    event BetRedeemed(uint256 moveValue, address by);
    event MoveMade(uint256 moveValue);
    event GameCreated(uint256 gameId);
}
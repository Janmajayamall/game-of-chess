// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

interface IGocEvents {
    event MarketCreated(uint256 moveValue, address by);
    event OutcomeBought(uint256 moveValue, address by);
    event OutcomeSold(uint256 moveValue, address by);
    event WinningRedeemed(uint256 moveValue);
    event BetRedeemed(uint256 moveValue);
    event MoveMade(uint256 moveValue);
    event GameCreated(uint256 gameId);
}
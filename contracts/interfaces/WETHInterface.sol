// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;


interface IWETH {
  function deposit() external payable;
  function withdraw(uint256 amount) external;
  function approve(address guy, uint wad) external returns (bool);
  function transfer(address dst, uint wad) external returns (bool);
  function balanceOf(address account) external returns(uint256);
  function transferFrom(address src, address dst, uint wad) external returns (bool);

}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IChainlinkAdapter} from "../../src/oracle/IChainlinkAdapter.sol";

contract MockChainlinkAdapter is IChainlinkAdapter {
    uint256 private _price;
    uint256 private _reserve;
    bool private _revertPrice;
    bool private _revertReserve;

    constructor(uint256 price, uint256 reserve) {
        _price = price;
        _reserve = reserve;
    }

    function setPrice(uint256 price) external {
        _price = price;
    }

    function setReserve(uint256 reserve) external {
        _reserve = reserve;
    }

    function setRevertPrice(bool shouldRevert) external {
        _revertPrice = shouldRevert;
    }

    function setRevertReserve(bool shouldRevert) external {
        _revertReserve = shouldRevert;
    }

    function getPrice() external view override returns (uint256) {
        require(!_revertPrice, "MockChainlinkAdapter: stale price");
        return _price;
    }

    function getProofOfReserve() external view override returns (uint256) {
        require(!_revertReserve, "MockChainlinkAdapter: stale reserve");
        return _reserve;
    }

    function decimals() external pure override returns (uint8) {
        return 18;
    }
}

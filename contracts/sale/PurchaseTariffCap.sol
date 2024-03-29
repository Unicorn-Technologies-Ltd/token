// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.14;

import {Sale} from "./Sale.sol";

/**
 * @title PurchaseTariffCap
 * @dev Sale with per-beneficiary caps.
 */
abstract contract PurchaseTariffCap is Sale {
  mapping(address => uint256) private _contributions;

  uint256 private _tariff;
  uint256 private _cap;

  /**
   * @dev Constructor, takes minimum amount of wei accepted in the sale.
   * @param t Min amount of wei to be contributed (tariff)
   * @param c Max amount of wei to be contributed (cap)
   */
  constructor(uint256 t, uint256 c) {
    require(t > 0, "Crowdsale: tariff 0");
    require(c > t, "Crowdsale: cap < tariff");

    _tariff = t;
    _cap = c;
  }

  /**
   * @dev Returns the investor cap of the crowdsale.
   * @return Returns the investor cap of the crowdsale.
   */
  function getInvestorCap() public view returns (uint256) {
    return _cap;
  }

  /**
   * @dev Returns the investor tariff of the crowdsale.
   * @return Returns the investor tariff of the crowdsale.
   */
  function getInvestorTariff() public view returns (uint256) {
    return _tariff;
  }

  /**
   * @dev Returns the amount contributed so far by a specific beneficiary.
   * @param beneficiary Address of contributor
   * @return Beneficiary contribution so far
   */
  function getContribution(address beneficiary) public view returns (uint256) {
    return _contributions[beneficiary];
  }

  /**
   * @dev Returns the amount that can still be contributed by the beneficiary.
   * @param beneficiary Address of contributor
   * @return Beneficiary contribution so far
   */
  function getRemainingContribution(address beneficiary) public view returns (uint256) {
    return _cap - _contributions[beneficiary];
  }

  /**
   * @dev Extend parent behavior to update beneficiary contributions.
   * @param beneficiary Token purchaser
   * @param weiAmount Amount of wei contributed
   */
  function _updatePurchasingState(
    address beneficiary,
    uint256 weiAmount
  ) internal virtual override {
    super._updatePurchasingState(beneficiary, weiAmount);

    _contributions[beneficiary] += weiAmount;
  }

  /**
   * @dev Extend parent behavior requiring purchase to respect the beneficiary's funding cap.
   * @param beneficiary Token purchaser
   * @param weiAmount Amount of wei contributed
   */
  function _preValidatePurchase(
    address beneficiary,
    uint256 weiAmount
  ) internal view virtual override {
    super._preValidatePurchase(beneficiary, weiAmount);

    uint256 diff = _cap - _contributions[beneficiary];
    bool diffException = diff < _cap && diff > 0 && diff == weiAmount;
    require(weiAmount <= _cap, "Crowdsale: wei > cap");
    require(weiAmount >= _tariff || diffException, "Crowdsale: wei < tariff");
    require(_contributions[beneficiary] + weiAmount <= _cap, "Crowdsale: cap >= hardCap");
  }
}

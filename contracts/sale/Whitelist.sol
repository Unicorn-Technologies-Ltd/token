// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.14;

import {Sale} from "./Sale.sol";

/**
 * @dev Sale in which only whitelisted users can contribute.
 */
abstract contract Whitelist is Sale {
  // Create a mapping of whitelistedAddresses
  // if an address is whitelisted, we would set it to true, it is false by default for all other addresses.
  mapping(address => bool) private _whitelisteds;
  address private _whitelistAdmin;

  event WhitelistedAdded(address indexed account);
  event WhitelistedRemoved(address indexed account);

  /**
   * @dev Throws if called by any account other than the whitelist admin.
   */
  modifier onlyWhitelistAdmin() {
    require(isWhitelistAdmin(_msgSender()), "Caller not whitelist admin");
    _;
  }

  /**
   * @dev Constructor, takes crowdsale whitelist limit.
   * @param whitelister The wallet that can add wallets to whitelist
   */
  constructor(address whitelister) {
    require(whitelister != address(0), "Zero whitelister address");

    _whitelistAdmin = whitelister;
  }

  function addWhitelisted(address account) public virtual onlyWhitelistAdmin {
    // check if the user has already been whitelisted
    require(!_whitelisteds[account], "Account already whitelisted");
    // Add the address which called the function to the whitelistedAddress array
    _whitelisteds[account] = true;

    emit WhitelistedAdded(account);
  }

  function removeWhitelisted(address account) public virtual onlyWhitelistAdmin {
    // check if the user has already been whitelisted
    require(_whitelisteds[account], "Account not whitelisted");

    _whitelisteds[account] = false;

    emit WhitelistedRemoved(account);
  }

  /**
   * @dev Checks if an account is the whitelist admin.
   */
  function isWhitelistAdmin(address account) public view returns (bool) {
    return _whitelistAdmin == account;
  }

  /**
   * @dev Checks if an account is whitelisted.
   */
  function isWhitelisted(address account) public view returns (bool) {
    return _whitelisteds[account];
  }

  /**
   * @dev Extend parent behavior requiring beneficiary to be whitelisted. Note that no
   * restriction is imposed on the account sending the transaction.
   * @param _beneficiary Token beneficiary
   * @param _weiAmount Amount of wei contributed
   */
  function _preValidatePurchase(
    address _beneficiary,
    uint256 _weiAmount
  ) internal view virtual override {
    super._preValidatePurchase(_beneficiary, _weiAmount);

    require(isWhitelisted(_beneficiary), "Beneficiary not whitelisted");
  }
}

// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./token/ERC20StrategicWalletRestrictions.sol";
import "./token/ERC20MintRestrictions.sol";
import "./token/ERC20Blacklistable.sol";
import "./token/ERC20Fees.sol";

/**
 * @dev Constructor
 * @param initialSupply The total number of tokens to mint without the decimals
 * @param finalSupply The minimum amount of token supply without the decimals
 * @param allocationsWalletTokens The total amount of tokens to be minted in the team allocation wallet
 * @param crowdsalesWalletTokens The total amount of tokens to be minted in the crowdsales-specific wallet
 * @param companyRate The percentage of every transfer that goes back to company wallet (0-1000)
 * @param esgFundRate The percentage of every transfer that ends up in the ESG fund (0-1000)
 * @param burnRate The percentage of every transfer that gets burned (0-1000)
 * @param allocationsWallet The address of the team allocation etc. token holder wallet
 * @param crowdsalesWallet The address of the crowdsales token holder wallet
 * @param companyRewardsWallet The address that receives the transfer fees for the company
 * @param esgFundWallet The address that handles the ESG fund from gathered transfer fees
 * @param pauserWallet The address with the authority to pause the ERC20 token
 * @param blacklisterWallet The address with the authority to blacklist addresses
 */
struct BTMTArgs {
  uint32 initialSupply;
  uint32 finalSupply;
  uint32 allocationsWalletTokens;
  uint32 crowdsalesWalletTokens;
  uint32 maxCompanyWalletTransfer;
  uint16 companyRate;
  uint16 esgFundRate;
  uint16 burnRate;
  address allocationsWallet;
  address crowdsalesWallet;
  address companyRewardsWallet;
  address esgFundWallet;
  address minterWallet;
  address pauserWallet;
  address blacklisterWallet;
  address feelessAdminWallet;
  address companyRestrictionWhitelistWallet;
}

/// @custom:security-contact security@bitmarkets.com
contract BITMarketsToken is
  ERC20,
  ERC20Snapshot,
  ERC20Pausable,
  ERC20Burnable,
  ERC20MintRestrictions,
  ERC20StrategicWalletRestrictions,
  ERC20Blacklistable,
  ERC20Fees,
  AccessControl
{
  using SafeMath for uint256;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
  bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
  bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");

  constructor(
    BTMTArgs memory args
  )
    ERC20("BITMarketsToken", "BTMT")
    ERC20MintRestrictions(args.minterWallet, 6)
    ERC20StrategicWalletRestrictions(
      args.companyRestrictionWhitelistWallet,
      args.allocationsWallet,
      args.crowdsalesWallet,
      args.maxCompanyWalletTransfer,
      1
    )
    ERC20Blacklistable(args.blacklisterWallet, 100000)
    ERC20Fees(
      args.finalSupply,
      args.companyRate,
      args.esgFundRate,
      args.burnRate,
      msg.sender,
      args.companyRewardsWallet,
      args.esgFundWallet,
      args.feelessAdminWallet
    )
  {
    require(
      args.allocationsWalletTokens + args.crowdsalesWalletTokens < args.initialSupply,
      "Invalid initial funds"
    );
    require(args.initialSupply >= args.finalSupply, "Invalid final supply");
    require(args.finalSupply > 0, "Less than zero final supply");

    // Company wallet
    _mint(msg.sender, args.initialSupply * 10 ** decimals());
    _approve(msg.sender, args.allocationsWallet, args.allocationsWalletTokens * 10 ** decimals());
    _approve(msg.sender, args.crowdsalesWallet, args.crowdsalesWalletTokens * 10 ** decimals());

    // Setup roles
    _setupRole(MINTER_ROLE, args.minterWallet);
    _setupRole(PAUSER_ROLE, args.pauserWallet);
    _setupRole(SNAPSHOT_ROLE, msg.sender);
  }

  /**
   * @dev Takes snapshot of state and can return to it
   */
  function snapshot() public onlyRole(SNAPSHOT_ROLE) {
    _snapshot();
  }

  /**
   * @dev Freezes transfers, burning, minting
   */
  function pause() public onlyRole(PAUSER_ROLE) {
    _pause();
  }

  /**
   * @dev Unfreezes transfers, burning, minting
   */
  function unpause() public onlyRole(PAUSER_ROLE) {
    _unpause();
  }

  /**
   * @dev Mints amount to address only if more than 6 months since and
   * only if totalSupply + 10% > amount
   */
  function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
    super._mint(to, amount);
  }

  function _mint(address to, uint256 amount) internal override(ERC20, ERC20MintRestrictions) {
    super._mint(to, amount);
  }

  /**
   * @dev Overridable function
   */
  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 amount
  )
    internal
    override(
      ERC20,
      ERC20Snapshot,
      ERC20Pausable,
      ERC20Blacklistable,
      ERC20Fees,
      ERC20StrategicWalletRestrictions
    )
  {
    super._beforeTokenTransfer(from, to, amount);
  }
}

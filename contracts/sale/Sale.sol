// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.14;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title Sale
 * @dev Sale is a base contract for managing a token sale,
 * allowing investors to purchase tokens with ether. This contract implements
 * such functionality in its most fundamental form and can be extended to provide additional
 * functionality and/or custom behavior.
 * The external interface represents the basic interface for purchasing tokens, and conforms
 * the base architecture for crowdsales. It is *not* intended to be modified / overridden.
 * The internal interface conforms the extensible and modifiable surface of sales. Override
 * the methods to add functionality. Consider using 'super' where appropriate to concatenate
 * behavior.
 */
abstract contract Sale is Context, ReentrancyGuard {
  using SafeERC20 for IERC20;

  // The token being sold
  IERC20 private _token;

  // Address where funds are collected
  address payable private _wallet;

  // Address that can purchase tokens on behalf of beneficiaries
  address payable private _purchaser;

  // How many token units a buyer gets per wei.
  // The rate is the conversion between wei and the smallest and indivisible token unit.
  // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
  // 1 wei will give you 1 unit, or 0.001 TOK.
  uint256 private _rate;

  // Amount of wei raised
  uint256 private _weiRaised;

  /**
   * Event for token purchase logging
   * @param purchaser who paid for the tokens
   * @param beneficiary who got the tokens
   * @param value weis paid for purchase
   * @param amount amount of tokens purchased
   */
  event TokensPurchased(
    address indexed purchaser,
    address indexed beneficiary,
    uint256 value,
    uint256 amount
  );

  /**
   * @dev The rate is the conversion between wei and the smallest and indivisible
   * token unit. So, if you are using a rate of 1 with a ERC20Detailed token
   * with 3 decimals called TOK, 1 wei will give you 1 unit, or 0.001 TOK.
   * @param r Number of token units a buyer gets per wei (rate)
   * @param w Address where collected funds will be forwarded to (wallet)
   * @param purchaser Address that can purchase tokens on behalf of clients
   * @param t Address of the token being sold (token)
   */
  constructor(uint256 r, address payable w, address payable purchaser, IERC20 t) {
    require(r > 0, "Crowdsale: 0 rate");
    require(w != address(0), "Crowdsale: wallet 0 address");
    require(purchaser != address(0), "Crowdsale: wallet 0 address");
    require(address(t) != address(0), "Crowdsale: token 0 address");

    _rate = r;
    _wallet = w;
    _purchaser = purchaser;
    _token = t;
  }

  receive() external payable {
    buyTokens(_msgSender());
  }

  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   * This function has a non-reentrancy guard, so it shouldn't be called by
   * another `nonReentrant` function.
   * @param beneficiary Recipient of the token purchase
   */
  function buyTokens(address beneficiary) public payable nonReentrant {
    uint256 weiAmount = msg.value;

    _preValidatePurchase(beneficiary, weiAmount);

    // calculate token amount to be bought
    uint256 tokens = _getTokenAmount(weiAmount);

    // update state
    _weiRaised += weiAmount;

    _processPurchase(beneficiary, tokens, 0);

    emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);

    _updatePurchasingState(beneficiary, weiAmount);

    _forwardFunds(weiAmount);

    _postValidatePurchase(beneficiary, weiAmount);
  }

  /**
   * @dev low level token purchase ***DO NOT OVERRIDE***
   * This function has a non-reentrancy guard, so it shouldn't be called by
   * another `nonReentrant` function.
   * @param beneficiary Recipient of the token purchase
   */
  function participateOnBehalfOf(
    address beneficiary,
    uint256 weiAmount,
    uint64 cliffSeconds
  ) public nonReentrant {
    require(_msgSender() == _purchaser, "Only purchaser wallet");

    _preValidatePurchase(beneficiary, weiAmount);

    // calculate token amount to be bought
    uint256 tokens = _getTokenAmount(weiAmount);

    // update state
    _weiRaised += weiAmount;

    _processPurchase(beneficiary, tokens, cliffSeconds);

    emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);

    _updatePurchasingState(beneficiary, weiAmount);

    _postValidatePurchase(beneficiary, weiAmount);
  }

  /**
   * @return the token being sold.
   */
  function token() public view returns (IERC20) {
    return _token;
  }

  /**
   * @return the address where funds are collected.
   */
  function wallet() public view returns (address payable) {
    return _wallet;
  }

  // /**
  //  * @return the number of token units a buyer gets per wei.
  //  */
  // function rate() virtual public view returns (uint256) {
  //     return _rate;
  // }

  /**
   * @return the amount of wei raised.
   */
  function weiRaised() public view returns (uint256) {
    return _weiRaised;
  }

  /**
   * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends
   * its tokens.
   * @param beneficiary Address performing the token purchase
   * @param tokenAmount Number of tokens to be emitted
   * @param cliffSeconds User only by the client purchaser wallet for reduced cliff
   */
  function _deliverTokens(
    address beneficiary,
    uint256 tokenAmount,
    uint64 cliffSeconds
  ) internal virtual {
    _token.safeTransfer(beneficiary, tokenAmount);
  }

  /**
   * @dev Executed when a purchase has been validated and is ready to be executed. Doesn't necessarily emit/send
   * tokens.
   * @param beneficiary Address receiving the tokens
   * @param tokenAmount Number of tokens to be purchased
   * @param cliffSeconds User only by the client purchaser wallet for reduced cliff
   */
  function _processPurchase(
    address beneficiary,
    uint256 tokenAmount,
    uint64 cliffSeconds
  ) internal virtual {
    _deliverTokens(beneficiary, tokenAmount, cliffSeconds);
  }

  /**
   * @dev Override for extensions that require an internal state to check for validity (current user contributions,
   * etc.)
   * @param beneficiary Address receiving the tokens
   * @param weiAmount Value in wei involved in the purchase
   */
  function _updatePurchasingState(address beneficiary, uint256 weiAmount) internal virtual {
    // solhint-disable-previous-line no-empty-blocks
  }

  /**
   * @dev Override to extend the way in which ether is converted to tokens.
   * @param weiAmount Value in wei to be converted into tokens
   * @return Number of tokens that can be purchased with the specified _weiAmount
   */
  function _getTokenAmount(uint256 weiAmount) internal virtual returns (uint256) {
    return weiAmount * _rate;
  }

  /**
   * @dev Determines how ETH is stored/forwarded on purchases.
   */
  function _forwardFunds(uint256 weiAmount) internal virtual {
    _wallet.transfer(weiAmount);
  }

  /**
   * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
   * Use `super` in contracts that inherit from Crowdsale to extend their validations.
   * Example from CappedCrowdsale.sol's _preValidatePurchase method:
   *     super._preValidatePurchase(beneficiary, weiAmount);
   *     require(weiRaised().add(weiAmount) <= cap);
   * @param beneficiary Address performing the token purchase
   * @param weiAmount Value in wei involved in the purchase
   */
  function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view virtual {
    require(beneficiary != address(0), "Crowdsale: beneficiary 0 address");
    require(weiAmount != 0, "Crowdsale: weiAmount is 0");
    this; // see https://github.com/ethereum/solidity/issues/2691
  }

  /**
   * @dev Validation of an executed purchase. Observe state and use revert statements to undo rollback when valid
   * conditions are not met.
   * @param beneficiary Address performing the token purchase
   * @param weiAmount Value in wei involved in the purchase
   */
  function _postValidatePurchase(address beneficiary, uint256 weiAmount) internal view virtual {
    // solhint-disable-previous-line no-empty-blocks
  }
}

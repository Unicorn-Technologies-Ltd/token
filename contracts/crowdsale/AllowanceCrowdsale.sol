// SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.14;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./Crowdsale.sol";

/**
 * @title AllowanceCrowdsale
 * @dev Extension of Crowdsale where tokens are held by a wallet, which approves an allowance to the crowdsale.
 */
abstract contract AllowanceCrowdsale is Crowdsale {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  address private _tokenWallet;

  /**
   * @dev Constructor, takes token wallet address.
   * @param wallet Address holding the tokens, which has approved allowance to the crowdsale.
   */
  constructor(address wallet) {
    // solhint-disable-next-line max-line-length
    require(wallet != address(0), "Crowdsale: wallet 0 address");
    _tokenWallet = wallet;
  }

  /**
   * @return the address of the wallet that will hold the tokens.
   */
  function tokenWallet() public view returns (address) {
    return _tokenWallet;
  }

  /**
   * @dev Checks the amount of tokens left in the allowance.
   * @return Amount of tokens left in the allowance
   */
  function remainingTokens() public view returns (uint256) {
    return
      Math.min(token().balanceOf(_tokenWallet), token().allowance(_tokenWallet, address(this)));
  }

  /**
   * @dev Overrides parent behavior by transferring tokens from wallet.
   * @param beneficiary Token purchaser
   * @param tokenAmount Amount of tokens purchased
   */
  function _deliverTokens(address beneficiary, uint256 tokenAmount) internal virtual override {
    // super._deliverTokens(beneficiary, tokenAmount);

    token().safeTransferFrom(_tokenWallet, beneficiary, tokenAmount);
  }
}

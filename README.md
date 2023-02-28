# BITMarketsToken (BTMT)

This repo contains the source code for the [BITMarkets token](https://bitmarkets.com) (BTMT) and its private and public sale.
It is a [Hardhat project](https://github.com/NomicFoundation/hardhat) that uses components from the battle-tested [OpenZeppelin contracts](https://github.com/OpenZeppelin/openzeppelin-contracts) library.

This repo can be useful to anyone looking to author their own ERC20 token in Solidity with fees, anti-corruption measures and native currency - token sales contracts on the blockchain.

## Table of contents

1. [Getting started](#gettingstarted)
2. [Important wallets](#importantwallets)
3. [BTMT](#btmt)
   1. [ERC20 Fees](#erc20fees)
   2. [ERC20 Strategic wallet restrictions](#erc20strategicwalletrestrictions)
4. [Sales](#sales)
   1. [Private sale](#privatesale)
   2. [Public sale](#publicsale)
5. [Linting](#linting)
6. [Testing](#testing)
7. [License](#license)
8. [Copyright](#copyright)

## Getting started <a name="gettingstarted"></a>

Clone this project from GitHub, go into the project directory,

```shell
git clone https://github.com/UAB-BITmarkets/token btmt
cd btmt
```

and run the following commands to get setup and running locally.

```shell
npm i
npm start
npm run deploy:dev
```

The commands above will install the project dependencies, compile the sample contract and run a local Hardhat node on port `8545`, using chain id `31337`.

## Important wallets <a name="importantwallets"></a>

1. Company liquidity wallet.
   After deployment, this wallet will hold 100 million BTMT.
   It is classified as a strategic wallet and is therefore restricted, in the sense that if the accumulated transactions reach 10 million then it will be locked for 1 month.
   BITMarkets uses this wallet to deploy the relevant smart contracts.
   This wallet’s private key is split into many parts using Shamir secret sharing so that it cannot be compromised by targeting a single holder.
2. Allocations wallet.
   This wallet also starts with 100 million tokens.
   It is also classified as strategic and its restriction is that it is only allowed to transfer tokens to the vesting wallets that are generated by the allocations-related smart contract.
3. Public/Private sales wallet.
   This wallet also holds 100 million tokens on deployment.
   It is strategic and its restriction is that it is only allowed to transfer to vesting wallets generated by the private sale and public sale smart contracts.
4. Company rewards wallet.
   This wallet receives 0.33% of each transfer amount as a company reward.
5. ESG wallet.
   This wallet also receives 0.33% of each transfer amount.
   The plan is to use this wallet for social impact investments by the company, based on the preferences of the BTMT holders.
   The smart contract for this functionality has not been created as of yet.
6. Pauser wallet.
   This wallet has the ability to pause all transfers.
   This functionality is useful if there is a bug somewhere.
7. Whitelister wallet.
   This wallet can whitelist client addresses to the private sale so that they can participate.
8. Feeless admin wallet.
   This wallet can make smart contracts feeless admins.
   This functionality exists because sales and allocations smart contracts need to be able to make their generated vesting wallets feeless because these wallets do not make signed transfers so as to be able to pay for fees.
   These feeless admin rights to smart contracts are given on deployment.
   This key also gives feeless status to the ESG wallet and the company rewards wallet.
9. Company restrictions admin wallet.
   This wallet can authorize the company liquidity wallet to make one unrestricted transfer to a specific address with specific amount, even if the liquidity wallet is locked.
   It also gives unrestricted access to the allocations and public/private sales wallets in their respective token wallets.
10. Allocations admin wallet.
    This wallet can ask the allocations smart contract to create vesting wallets.
    At some point it will be useless as it will have allocated all the tokens of the allocations wallet to their beneficiaries.
11. Sales client purchaser wallet.
    This wallet is used by the server infrastructure of BITMarkets in order to participate in the public and private sales on behalf of clients.

## BTMT

The BTMT token uses the ERC20 standard, which defines a set of functions that a smart contract implements to allow external clients to interact with the fungible token.
To be compliant with the standard, BTMT inherits from the battle-tested [ERC20 smart contract](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol) offered by OpenZeppelin on their GitHub repository and uses their extensions: [ERC20Snapshot](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Snapshot.sol), [ERC20Pausable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Pausable.sol), [ERC20Burnable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/ERC20Burnable.sol).
Other than these extensions, BITMarkets uses two more extensions, namely, transfer fees and strategic wallet restrictions.
You can see the relevant smart contract in [contracts/BITMarketsToken.sol](contracts/BITMarketsToken.sol).

### ERC20 Fees <a name="erc20fees"></a>

This extension calculates the transfer fees that will be distributed to two strategic wallets, namely, the company rewards and ESG wallets, based on prespecified percentages on the total amount of a transfer that are made available on deployment.
These fees are removed from the transfer amount and transferred from the sender’s wallet to the two mentioned wallets.
The fees will be 0.33% for each wallet and they will apply to all transfers.
Another percentage of 0.33% is removed from the transfer amount and burned.

The four wallets that are excluded from fee collection on deployment are the company rewards, the ESG, the public/private sales and the allocations wallets.
The feeless functionality methods can be accessed publically but the ability to add or remove a wallet from the feeless list is reserved for the feeless admin wallet, which provides the priviledge also to the sales and allocations smart contracts for their generated vesting wallets.

The relevant functions are:

```solidity
function addFeelessAdmin(address) public onlyFeelessAdmin;

function addFeeless(address) public onlyFeelessAdmins;

function removeFeeless(address) public onlyFeelessAdmins;

function isFeeless(address) public returns (bool);
```

You can browse the source code of the smart contract governing these fees in [contracts/token/ERC20Fees.sol.sol](contracts/token/ERC20Fees.sol).

### ERC20 Strategic wallet restrictions <a name="erc20strategicwalletrestrictions"></a>

The three wallets which hold a large amount of tokens in different times of the token’s lifecycle (company liquidity, allocations, public/private sale) need restrictions on their transfers so that the users can trust them and so that there exists some decentralized security on their tokens.
The relevant wallet here is the restrictions admin wallet, which serves as the wallet that offers allowance to the allocations and sales smart contracts to transfer tokens from their respective wallets.

```solidity
function addUnrestrictedReceiver(address, address, uint256) public onlyRestrictionsAdmin;

function removeUnrestrictedReceiver(address) public onlyRestrictionsAdmin;

function isStrategicWallet(address) public returns (bool);

function getApprovedReceiver(address) public returns (address);

function getApprovedReceiverLimit(address) public returns (uint256);

function companyLiquidityTransfersLimit() public returns (uint256);

function companyLiquidityTransfersSinceLastLimitReached() public returns (uint256);

function timeSinceCompanyLiquidityTransferLimitReached() public returns (uint256);
```

You can browse the source code of the smart contract governing these restrictions in [contracts/token/ERC20StrategicWalletRestrictions.sol](contracts/token/ERC20StrategicWalletRestrictions.sol).

## Sales

One third of the initial supply of BTMT will be sold in public and private sales.
The smart contracts that govern these sales have a combined allowance of 100 000 000 tokens from the sales wallet to distribute to the buyers.
The smart contracts expect to trade MATIC, Polygon’s native cryptocurrency, with BTMT.
The sales wallet will receive the MATIC that the buyer sends to the sales smart contracts and the contract will send in return the amount of BTMT that corresponds to the rate that is derived from the contract’s code to a vesting wallet whose beneficiary is the purchaser.
The purchased BTMT comes from the sales wallet, provided that it does not exceed the contract’s allowance.
The most important publicly exposed methods of public and private sale contracts, which are defined in
[contracts/sale/Sale.sol](contracts/sale/Sale.sol) are the following:

```solidity
function buyTokens(address) public payable;

function getContribution(address) public returns (uint256);

function remainingTokens() public view returns (uint256);

function token() public view returns (IERC20);

function tokenWallet() public view returns (address);

function wallet() public view returns (address payable);

function weiRaised() public view returns (uint256);
```

Every sale happens in a limited time window that is specified on deployment.
The private sale is planned to run from the 8th of March 2023 until 23rd of June 2023.
In order for external programs to track the timing, the [timing smart contract](contracts/sale/TimedSale.sol) provides the following, non-state-mutating functions:

```solidity
function isOpen() public view returns (bool);

function hasClosed() public view returns (bool);

function paused() public view returns (bool);

function openingTime() public view returns;

function closingTime() public view returns (uint256);
```

The smart contracts have algorithmic safeguards in order to ensure fair access to the sales for as many buyers as possible.
[One such safeguard](contracts/sale/PurchaseTariffCap.sol) is that an individual address will have both a tariff to participate and an individual cap to contribute:

```solidity
function getInvestorCap() public view returns (uint256);

function getInvestorTariff() public view returns (uint256);

function investorCap() public returns (uint256);

function investorTariff() public returns (uint256);
```

### Private sale <a name="privatesale"></a>

There will be a private sale with a fixed exchange rate between MATIC and BTMT which will happen before the public sale that will take place later in 2023.
The company will provide a way for prospective buyers to make it into the whitelist, either by completing a number of tasks, as a gift for their dedication or for VIP clients on the platform.
The publicly accessible functions that are relevant to the whitelist are the following:

```solidity
function addWhitelisted(address) public;

function removeWhitelisted(address) public;

function isWhitelistAdmin(address) public view returns (bool);

function isWhitelisted(address) public view returns (bool);
```

In order to ensure fair use of BTMT by the team and to reduce the volatility of its exchange price in the short run, there is a locking and vesting functionality built into the sales and the allocation contracts.
The vesting occurs linearly and starts from a point in time that is called the “cliff”.
As time goes by, more and more tokens are unlocked from the purpose-generated vesting wallets and are claimable by their original owners.
The mapping of the beneficiary and their vesting wallet is stored on the blockchain and it is visible to everyone.
We use the [VestingWallet smart contract from OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/finance/VestingWallet.sol) to generate the vesting wallets and you can check the relevant smart contracts [here](contracts/sale/Vesting.sol) and [here](contracts/BITMarketsTokenAllocations.sol).
The functions that expose this functionality to the public are the following:

```solidity
function vestingWallet(address) public view returns (address);

function vestedAmount(address) public view returns (uint256);

function withdrawTokens(address) public;
```

### Public sale <a name="publicsale"></a>

## Linting

To check if there are any linting issues you can run

```shell
npm run lint
```

and to fix them simply run.

```shell
npm run lint:fix
```

## Testing

To test the smart contracts you can run

```shell
npm test
```

and to collect coverage.

```shell
npm run coverage
```

## License

The source code is licensed under the terms of the Apache License version 2.0 (see [LICENSE](LICENSE)).

## Copyright

Copyright (C) 2023 UAB BITmarkets. All rights reserved.

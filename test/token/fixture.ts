import { ethers } from "hardhat";

import type { BITMarketsToken__factory } from "../../typechain-types/factories/contracts/BITMarketsToken__factory";

const initialSupply = 300000000;
const finalSupply = 200000000;

const companyWalletTokens = initialSupply / 3;
const allocationsWalletTokens = initialSupply / 3;
const crowdsalesWalletTokens = initialSupply / 3;

const maxCompanyWalletTransfer = companyWalletTokens / 10;

const companyRate = 1;
const esgFundRate = 1;
const burnRate = 1; // 1/1000 = 0.1%

export const loadContract = async () => {
  const [
    companyLiquidityWallet,
    addr1,
    addr2,
    allocationsWallet,
    crowdsalesWallet,
    companyRewardsWallet,
    esgFundWallet,
    minterWallet,
    pauserWallet,
    blacklisterWallet,
    feelessAdminWallet,
    companyRestrictionWhitelistWallet
  ] = await ethers.getSigners();

  // companyLiquidityWallet is the signer
  const BITMarketsTokenFactory = (await ethers.getContractFactory(
    "BITMarketsToken",
    companyLiquidityWallet
  )) as BITMarketsToken__factory;

  const token = await BITMarketsTokenFactory.deploy({
    initialSupply,
    finalSupply,
    allocationsWalletTokens,
    crowdsalesWalletTokens,
    maxCompanyWalletTransfer,
    companyRate,
    esgFundRate,
    burnRate,
    allocationsWallet: allocationsWallet.address,
    crowdsalesWallet: crowdsalesWallet.address,
    companyRewardsWallet: companyRewardsWallet.address,
    esgFundWallet: esgFundWallet.address,
    minterWallet: minterWallet.address,
    pauserWallet: pauserWallet.address,
    blacklisterWallet: blacklisterWallet.address,
    feelessAdminWallet: feelessAdminWallet.address,
    companyRestrictionWhitelistWallet: companyRestrictionWhitelistWallet.address
  });
  await token.deployed();

  return {
    token,
    companyLiquidityWallet,
    addr1,
    addr2,
    allocationsWallet,
    crowdsalesWallet,
    companyRewardsWallet,
    esgFundWallet,
    minterWallet,
    pauserWallet,
    blacklisterWallet,
    feelessAdminWallet,
    companyRestrictionWhitelistWallet
  };
};
import { ethers } from "ethers";
import { task } from "hardhat/config";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { env } from "node:process";
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { join, dirname, resolve } from "node:path";

import dotenv from "dotenv";

import getGasData from "../utils/getGasData";

import { BITMarketsTokenAllocations__factory } from "../typechain-types/factories/contracts/BITMarketsTokenAllocations__factory";

if (
  existsSync(
    join(
      dirname(".."),
      `.env_${
        process.env.NODE_ENV === "development"
          ? "dev"
          : process.env.NODE_ENV === "testing"
          ? "test"
          : "prod"
      }`
    )
  )
) {
  dotenv.config({
    path: resolve(
      dirname(".."),
      `.env_${
        process.env.NODE_ENV === "development"
          ? "dev"
          : process.env.NODE_ENV === "testing"
          ? "test"
          : "prod"
      }`
    )
  });
}

const provider =
  process.env.NODE_ENV === "development"
    ? new ethers.JsonRpcProvider("HTTP://127.0.0.1:8545")
    : process.env.NODE_ENV === "testing"
    ? new ethers.AlchemyProvider("maticmum", env.ALCHEMY_API_KEY || "")
    : new ethers.AlchemyProvider("matic", env.ALCHEMY_API_KEY || "");

const allocations = BITMarketsTokenAllocations__factory.connect(
  env.ALLOCATIONS_CONTRACT_ADDRESS || "BITMarketsTokenAllocations",
  provider
);

task("allocate", "Allocate to team etc.").setAction(
  async (_, hre: HardhatRuntimeEnvironment): Promise<void> => {
    const [
      companyLiquidityWallet, // needed
      allocationsWallet, // needed
      crowdsalesWallet, // needed
      companyRewardsWallet,
      esgFundWallet,
      whitelisterWallet,
      feelessAdminWallet, // needed
      companyRestrictionWhitelistWallet, // needed
      allocationsAdminWallet, // needed
      crowdsalesClientPurchaserWallet
    ] = await hre.ethers.getSigners();

    const teamWalletsLen = 1070;

    if (!existsSync(join(__dirname, "teamAllocationsWallets.csv"))) {
      writeFileSync(
        join(__dirname, "teamAllocationsWallets.csv"),
        `PRIVATE_KEY,ADDRESS,AMOUNT,TX_HASH,NONCE`
      );
    }

    let maxFeePerGas = ethers.parseEther("0");
    let maxPriorityFeePerGas = ethers.parseEther("0");

    const fees = await getGasData();
    maxFeePerGas = fees.maxFeePerGas;
    maxPriorityFeePerGas = fees.maxPriorityFeePerGas;

    for (let i = 0; i < teamWalletsLen; i++) {
      const file = readFileSync(join(__dirname, "teamAllocationsWallets.csv"), "utf8");

      const wallet = ethers.Wallet.createRandom();

      const amount = i < 10 ? 1000000 : i < 20 ? 500000 : i < 70 ? 100000 : 10000;

      if (i % 5 === 0) {
        const fees = await getGasData();
        maxFeePerGas = fees.maxFeePerGas;
        maxPriorityFeePerGas = fees.maxPriorityFeePerGas;
      }

      const tx = await allocations
        .connect(allocationsAdminWallet)
        .allocate(wallet.address, ethers.parseEther(`${amount}`), 0, {
          maxFeePerGas,
          maxPriorityFeePerGas
        });

      console.log(
        `Iteration #${i + 1}. Allocated to ${wallet.address} amount ${amount} for team. Tx hash ${
          tx.hash
        } with nonce ${tx.nonce}.`
      );

      writeFileSync(
        join(__dirname, "teamAllocationsWallets.csv"),
        `${file}\n${wallet.privateKey},${wallet.address},${amount},${tx.hash},${tx.nonce}`
      );

      await tx.wait();

      await new Promise((resolve) => setTimeout(resolve, 1 + Math.random() * 1000));
    }

    const salesWalletsLen = 565;

    if (!existsSync(join(__dirname, "salesAllocationsWallets.csv"))) {
      writeFileSync(
        join(__dirname, "salesAllocationsWallets.csv"),
        `PRIVATE_KEY,ADDRESS,AMOUNT,TX_HASH,NONCE`
      );
    }

    for (let i = 0; i < salesWalletsLen; i++) {
      const file = readFileSync(join(__dirname, "salesAllocationsWallets.csv"), "utf8");

      const wallet = ethers.Wallet.createRandom();

      const amount = i < 5 ? 1000000 : i < 15 ? 500000 : i < 65 ? 100000 : 10000;

      if (i % 5 === 0) {
        const fees = await getGasData();
        maxFeePerGas = fees.maxFeePerGas;
        maxPriorityFeePerGas = fees.maxPriorityFeePerGas;
      }

      const tx = await allocations
        .connect(allocationsAdminWallet)
        .allocate(wallet.address, ethers.parseEther(`${amount}`), 0, {
          maxFeePerGas,
          maxPriorityFeePerGas
        });

      console.log(
        `Iteration #${i + 1}. Allocated to ${wallet.address} amount ${amount} for sales. Tx hash ${
          tx.hash
        } with nonce ${tx.nonce}.`
      );

      writeFileSync(
        join(__dirname, "salesAllocationsWallets.csv"),
        `${file}\n${wallet.privateKey},${wallet.address},${amount},${tx.hash},${tx.nonce}`
      );

      await tx.wait();

      await new Promise((resolve) => setTimeout(resolve, 1 + Math.random() * 1000));
    }
  }
);

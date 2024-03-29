import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";

import {
  loadContracts,
  cliff,
  vestingDuration,
  allocationsWalletTokens
} from "./allocations/fixture";

import type { HDNodeWallet } from "ethers";

const salesWalletsLen = 10;
const salesWallets: HDNodeWallet[] = [];
for (let i = 0; i < salesWalletsLen; i++) {
  salesWallets.push(ethers.Wallet.createRandom());
}
const salesAllocationPerWallet = (allocationsWalletTokens * 40) / 100 / salesWalletsLen;

const marketingWallet = ethers.Wallet.createRandom();
const marketingAllocation = (allocationsWalletTokens * 25) / 100;

const teamWalletsLen = 3;
const teamWallets: HDNodeWallet[] = [];
for (let i = 0; i < teamWalletsLen; i++) {
  teamWallets.push(ethers.Wallet.createRandom());
}
const teamAllocationPerWallet = (allocationsWalletTokens * 30) / 100 / teamWalletsLen;

const airdropsWalletsLen = 10;
const airdropsWallets: HDNodeWallet[] = [];
for (let i = 0; i < airdropsWalletsLen; i++) {
  airdropsWallets.push(ethers.Wallet.createRandom());
}
const airdropsAllocationPerWallet = (allocationsWalletTokens * 5) / 100 / airdropsWalletsLen;

describe("BITMarkets ERC20 token allocations tests", () => {
  describe("Allocation", () => {
    it("Should be possible to allocate", async () => {
      const { token, allocations, addr1, allocationsAdminWallet } =
        await loadFixture(loadContracts);

      const amount = ethers.parseEther("1.0");

      await allocations.connect(allocationsAdminWallet).allocate(addr1.address, amount, 0);

      const vestingWalletAddress = await allocations.vestingWallet(addr1.address);

      expect(await token.balanceOf(vestingWalletAddress)).to.be.equal(amount);
    });

    it("Vesting and withdrawals should work as expected", async () => {
      const { token, allocations, addr1, allocationsAdminWallet } =
        await loadFixture(loadContracts);

      const openingTime = Date.now();
      await ethers.provider.send("evm_mine", [openingTime]);

      const amount = ethers.parseEther("100.0");

      await allocations.connect(allocationsAdminWallet).allocate(addr1.address, amount, 0);

      expect(await token.balanceOf(addr1.address)).to.be.equal(ethers.parseEther("0"));

      expect(await allocations.vestedAmount(addr1.address)).to.be.equal(ethers.parseEther("0"));

      await ethers.provider.send("evm_mine", [openingTime + cliff + vestingDuration / 2]);

      expect(await allocations.vestedAmount(addr1.address)).to.be.equal(ethers.parseEther("45"));

      await allocations.connect(addr1).withdraw(addr1.address);

      expect(await token.balanceOf(addr1.address)).to.be.equal(ethers.parseEther("50"));

      await ethers.provider.send("evm_mine", [openingTime + cliff + vestingDuration]);

      await allocations.connect(addr1).withdraw(addr1.address);

      expect(await token.balanceOf(addr1.address)).to.be.equal(amount);
    });

    it("Should not be possible for a non-allocation admin to allocate.", async () => {
      const { allocations, addr1 } = await loadFixture(loadContracts);

      const amount = ethers.parseEther("1.0");

      await expect(
        allocations.connect(addr1).allocate(addr1.address, amount, 0)
      ).to.be.revertedWith("Invalid message sender");
    });

    it("Should be possible for an already allocated wallet to reallocate.", async () => {
      const { allocations, addr1, allocationsAdminWallet } = await loadFixture(loadContracts);

      const amount = ethers.parseEther("1.0");

      await allocations.connect(allocationsAdminWallet).allocate(addr1.address, amount, 0);

      await expect(allocations.connect(allocationsAdminWallet).allocate(addr1.address, amount, 0))
        .to.not.be.reverted;
    });

    it("Should be possible to do allocations with different cliffs.", async () => {
      const { allocations, addr1, addr2, allocationsAdminWallet } =
        await loadFixture(loadContracts);

      const amount = ethers.parseEther("1.0");

      await allocations.connect(allocationsAdminWallet).allocate(addr1.address, amount, 0);

      await allocations.connect(allocationsAdminWallet).allocate(addr2.address, amount, cliff - 5);

      const addr1Cliff = await allocations
        .connect(allocationsAdminWallet)
        .getVestingWalletCliff(addr1.address);

      const addr2Cliff = await allocations
        .connect(allocationsAdminWallet)
        .getVestingWalletCliff(addr2.address);

      expect(addr2Cliff).to.be.lessThan(addr1Cliff);
    });

    it("Should not be possible to allocate more than the max amount.", async () => {
      const { allocations, addr1, allocationsAdminWallet } = await loadFixture(loadContracts);

      const amount = ethers.parseEther(`${allocationsWalletTokens + 1}`);

      await expect(
        allocations.connect(allocationsAdminWallet).allocate(addr1.address, amount, 0)
      ).to.be.revertedWith("Amount too large");
    });

    it("Should not be possible to withdraw if not beneficiary.", async () => {
      const { allocations, addr1, allocationsAdminWallet } = await loadFixture(loadContracts);

      const amount = ethers.parseEther(`${allocationsWalletTokens}`);

      await expect(allocations.connect(addr1).withdraw(addr1.address)).to.revertedWith(
        "No vesting wallet"
      );

      await allocations.connect(allocationsAdminWallet).allocate(addr1.address, amount, 0);

      // await expect(allocations.connect(addr2).withdraw(addr1.address)).to.revertedWith(
      //   "Invalid msg sender"
      // );
    });

    it("Should not be possible to get vesting wallet address if not on the list", async () => {
      const { allocations, addr1 } = await loadFixture(loadContracts);

      await expect(allocations.connect(addr1).vestingWallet(addr1.address)).to.revertedWith(
        "No vesting wallet"
      );
    });

    it("Should not be possible to get vested amount if not on the list", async () => {
      const { allocations, addr1 } = await loadFixture(loadContracts);

      await expect(allocations.connect(addr1).vestedAmount(addr1.address)).to.revertedWith(
        "No vesting wallet"
      );
    });

    it("Should only be possible to do transfers to the allocations smart contract.", async () => {
      const { token, allocationsWallet, addr1 } = await loadFixture(loadContracts);

      await expect(
        token.connect(allocationsWallet).transfer(addr1.address, ethers.parseEther("1"))
      ).to.revertedWith("Illegal transfer");
    });

    it("Should be possible for BITMarkets allocations to happen", async () => {
      const { token, allocations, allocationsWallet, allocationsAdminWallet } =
        await loadFixture(loadContracts);

      expect(
        teamWalletsLen * teamAllocationPerWallet +
          marketingAllocation +
          airdropsWalletsLen * airdropsAllocationPerWallet +
          salesWalletsLen * salesAllocationPerWallet
      ).to.be.equal(allocationsWalletTokens);

      let i = 0;

      const salesAllocationPerWalletDecimals = ethers.parseEther(`${salesAllocationPerWallet}`);
      for (i = 0; i < salesWalletsLen; i++) {
        await allocations
          .connect(allocationsAdminWallet)
          .allocate(salesWallets[i].address, salesAllocationPerWalletDecimals, 0);
      }

      const teamAllocationPerWalletDecimals = ethers.parseEther(`${teamAllocationPerWallet}`);
      for (i = 0; i < teamWalletsLen; i++) {
        await allocations
          .connect(allocationsAdminWallet)
          .allocate(teamWallets[i].address, teamAllocationPerWalletDecimals, 0);
      }

      const marketingAllocationDecimals = ethers.parseEther(`${marketingAllocation}`);
      await allocations
        .connect(allocationsAdminWallet)
        .allocate(marketingWallet.address, marketingAllocationDecimals, 0);

      const airdropsAllocationDecimals = ethers.parseEther(`${airdropsAllocationPerWallet}`);
      for (i = 0; i < airdropsWalletsLen; i++) {
        await allocations
          .connect(allocationsAdminWallet)
          .allocate(airdropsWallets[i].address, airdropsAllocationDecimals, 0);
      }

      let allocationsWalletTokensVesting = ethers.parseEther("0");

      expect(await token.balanceOf(allocationsWallet.address)).to.be.equal(
        allocationsWalletTokensVesting
      );

      for (i = 0; i < salesWalletsLen; i++) {
        const vestingWallet = await allocations.vestingWallet(salesWallets[i].address);

        const balance = await token.balanceOf(vestingWallet);

        allocationsWalletTokensVesting = allocationsWalletTokensVesting + balance;
      }

      for (i = 0; i < teamWalletsLen; i++) {
        const vestingWallet = await allocations.vestingWallet(teamWallets[i].address);

        const balance = await token.balanceOf(vestingWallet);

        allocationsWalletTokensVesting = allocationsWalletTokensVesting + balance;
      }

      const marketingVestingWallet = await allocations.vestingWallet(marketingWallet.address);

      const marketingVestingBalance = await token.balanceOf(marketingVestingWallet);

      allocationsWalletTokensVesting = allocationsWalletTokensVesting + marketingVestingBalance;

      for (i = 0; i < airdropsWalletsLen; i++) {
        const vestingWallet = await allocations.vestingWallet(airdropsWallets[i].address);

        const balance = await token.balanceOf(vestingWallet);

        allocationsWalletTokensVesting = allocationsWalletTokensVesting + balance;
      }

      expect(allocationsWalletTokensVesting).to.be.equal(
        ethers.parseEther(`${allocationsWalletTokens}`)
      );

      // expect(await crowdsale.remainingTokens()).to.lessThan(
      //   companyLiquidityWalletCurrentTokenBalance
      // );
      // expect(addr2TokenBalanceWhenLocked).to.equal(0);
      // expect(addr2VestedAmountBeforeCliff).to.lessThan(addr2RemainingTokensBeforeCliff);
      // expect(addr2VestedAmountBeforeCliff).to.equal(0);
      // expect(addr2TokenBalanceAfterCliffBeforeCompleteVestingNoWithdraw).to.equal(0);
      // expect(addr2TokenBalanceWhenLocked).to.lessThan(
      //   addr2TokenBalanceAfterCliffBeforeCompleteVesting
      // );
      // expect(addr2TokenBalanceAfterCliffBeforeCompleteVesting).to.lessThan(
      //   addr2TokenBalanceAfterCliffCompleteVesting
      // );
      // expect(companyLiquidityWalletInitialTokenBalance.sub(companyLiquidityWalletCurrentTokenBalance)).to.equal(addr2TokenBalance);
    });
  });
});

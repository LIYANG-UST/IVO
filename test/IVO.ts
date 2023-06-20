import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { IVOFixture } from "./IVO.fixture";

describe("Initial Ve Offering", function () {
  const PENDING_START = 1;
  const LIVE = 2;
  const CLAIMABLE = 3;

  it("should be able to add a new token sale", async function () {
    const { ivo, admin, alice, bob } = await loadFixture(IVOFixture);

    const currentTime = await ethers.provider.getBlock("latest").then((block) => block.timestamp);
    console.log("Current timestamp", currentTime);

    await expect(
      ivo.addNewSale(false, 0, ethers.utils.parseEther("0.001"), ethers.utils.parseEther("10000"), currentTime + 100),
    )
      .to.emit(ivo, "NewSaleAdded")
      .withArgs(1, false, 0, ethers.utils.parseEther("0.001"), ethers.utils.parseEther("10000"), currentTime + 100);

    const sale = await ivo.sales(1);
    expect(sale.status).to.equal(PENDING_START);
    expect(sale.totalAmount).to.equal(ethers.utils.parseEther("10000"));
    expect(sale.soldAmount).to.equal(0);
    expect(sale.deadline).to.equal(currentTime + 100);
    expect(sale.price).equal(ethers.utils.parseEther("0.001"));

    const tokenType = await ivo.tokenTypes(1);
    expect(tokenType.isVeToken).to.equal(false);
    expect(tokenType.lockedPeriod).to.equal(0);

    await expect(
      ivo.addNewSale(true, 3600, ethers.utils.parseEther("0.001"), ethers.utils.parseEther("10000"), currentTime + 100),
    )
      .to.emit(ivo, "NewSaleAdded")
      .withArgs(2, true, 3600, ethers.utils.parseEther("0.001"), ethers.utils.parseEther("10000"), currentTime + 100);

    const sale2 = await ivo.sales(2);
    expect(sale2.status).to.equal(PENDING_START);
    expect(sale2.totalAmount).to.equal(ethers.utils.parseEther("10000"));
    expect(sale2.soldAmount).to.equal(0);
    expect(sale2.deadline).to.equal(currentTime + 100);
    expect(sale2.price).equal(ethers.utils.parseEther("0.001"));

    const tokenType2 = await ivo.tokenTypes(2);
    expect(tokenType2.isVeToken).to.equal(true);
    expect(tokenType2.lockedPeriod).to.equal(3600);
  });

  it("should be able to start a token sale", async function () {
    const { ivo, admin, alice, bob } = await loadFixture(IVOFixture);
    const currentTime = await ethers.provider.getBlock("latest").then((block) => block.timestamp);
    await ivo.addNewSale(
      false,
      0,
      ethers.utils.parseEther("0.001"),
      ethers.utils.parseEther("10000"),
      currentTime + 100,
    );

    await ivo.startSale(1);

    const sale = await ivo.sales(1);
    expect(sale.status).to.equal(LIVE);
  });

  it("should be able to buy tokens", async function () {
    const { ivo, admin, alice, bob } = await loadFixture(IVOFixture);
    const currentTime = await ethers.provider.getBlock("latest").then((block) => block.timestamp);
    await ivo.addNewSale(
      false,
      0,
      ethers.utils.parseEther("0.001"),
      ethers.utils.parseEther("10000"),
      currentTime + 100,
    );
    await ivo.startSale(1);

    await ivo.connect(alice).buy(1, ethers.utils.parseEther("1000"), { value: ethers.utils.parseEther("1") });

    const userBought = await ivo.userBought(alice.address, 1);
    expect(userBought).to.equal(ethers.utils.parseEther("1000"));

    const sale = await ivo.sales(1);
    expect(sale.soldAmount).to.equal(ethers.utils.parseEther("1000"));
  });

  it("should be able to settle and claim tokens", async function () {
    const { ivo, baseToken, admin, alice, bob } = await loadFixture(IVOFixture);
    const currentTime = await ethers.provider.getBlock("latest").then((block) => block.timestamp);
    await ivo.addNewSale(
      false,
      0,
      ethers.utils.parseEther("0.001"),
      ethers.utils.parseEther("10000"),
      currentTime + 100,
    );
    await ivo.startSale(1);

    await ivo.connect(alice).buy(1, ethers.utils.parseEther("1000"), { value: ethers.utils.parseEther("1") });
    await ivo.connect(bob).buy(1, ethers.utils.parseEther("2000"), { value: ethers.utils.parseEther("2") });

    await ethers.provider.send("evm_setNextBlockTimestamp", [currentTime + 101]);

    await ivo.settle(1);

    const sale = await ivo.sales(1);
    expect(sale.status).to.equal(CLAIMABLE);

    await ivo.connect(alice).claim(1);
    await ivo.connect(bob).claim(1);

    expect(await baseToken.balanceOf(alice.address)).to.equal(ethers.utils.parseEther("1000"));
    expect(await baseToken.balanceOf(bob.address)).to.equal(ethers.utils.parseEther("2000"));
  });
});

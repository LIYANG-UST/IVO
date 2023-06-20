import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

import { VeTokenFixture } from "./VeToken.fixture";

describe("Ve Token", function () {
  it("should be able to create a new lock for veNFT", async function () {
    const { baseToken, veToken, admin, alice, bob } = await loadFixture(VeTokenFixture);

    // Lock 100 baseToken for 30 days
    await veToken.connect(alice).createLock(ethers.utils.parseEther("100"), 1, alice.address);

    // * Alice has 1 veNFT
    expect(await veToken.balanceOf(alice.address)).to.equal(1);
    // * Token ID 1 is owned by Alice
    expect(await veToken.ownerOf(1)).to.equal(alice.address);
    // * Total minted veNFT is 1
    expect(await veToken.totalVeNFTs()).to.equal(1);
    // * Total veToken supply is 20
    expect(await veToken.totalSupply()).to.equal(ethers.utils.parseEther("20"));

    const currentTime = await ethers.provider.getBlock("latest").then((block) => block.timestamp);

    const lockInfo = await veToken.locks(1);
    expect(lockInfo.amount).to.equal(ethers.utils.parseEther("100"));
    expect(lockInfo.endTimestamp).to.equal(currentTime + 100);
  });
});

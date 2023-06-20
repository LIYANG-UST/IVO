import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import { VeToken } from "../types/contracts/VeToken";
import { MockBaseToken } from "../types/contracts/mocks/MockBaseToken";
import { InitialVeTokenOffering__factory } from "../types/factories/contracts/InitialVeTokenOffering.sol";
import { VeToken__factory } from "../types/factories/contracts/VeToken__factory";
import { MockBaseToken__factory } from "../types/factories/contracts/mocks/MockBaseToken__factory";

export async function VeTokenFixture(): Promise<{
  baseToken: MockBaseToken;
  veToken: VeToken;
  admin: SignerWithAddress;
  alice: SignerWithAddress;
  bob: SignerWithAddress;
}> {
  const [admin, alice, bob] = await ethers.getSigners();

  const baseToken = await new MockBaseToken__factory(admin).deploy();

  const veToken = await new VeToken__factory(admin).deploy();
  await veToken.initialize("VeToken", "VET", baseToken.address);

  await baseToken.mint(alice.address, ethers.utils.parseEther("1000"));
  await baseToken.mint(bob.address, ethers.utils.parseEther("1000"));

  await baseToken.connect(alice).approve(veToken.address, ethers.constants.MaxUint256);
  await baseToken.connect(bob).approve(veToken.address, ethers.constants.MaxUint256);

  await veToken.setLockLevels(
    [100, 200, 300, 400],
    [
      ethers.utils.parseEther("0.2"),
      ethers.utils.parseEther("0.4"),
      ethers.utils.parseEther("0.6"),
      ethers.utils.parseEther("1"),
    ],
  );

  return { baseToken, veToken, admin, alice, bob };
}

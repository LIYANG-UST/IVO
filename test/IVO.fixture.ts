import { ethers } from "hardhat";

import { InitialVeTokenOffering__factory } from "../types/factories/contracts/InitialVeTokenOffering.sol";
import { VeToken__factory } from "../types/factories/contracts/VeToken__factory";
import { MockBaseToken__factory } from "../types/factories/contracts/mocks/MockBaseToken__factory";

export async function IVOFixture(): Promise<any> {
  const [admin, alice, bob] = await ethers.getSigners();

  const baseToken = await new MockBaseToken__factory(admin).deploy();

  const veToken = await new VeToken__factory(admin).deploy();
  await veToken.initialize("VeToken", "VET", baseToken.address);

  const ivo = await new InitialVeTokenOffering__factory(admin).deploy(baseToken.address, veToken.address);

  return { baseToken, veToken, ivo, admin, alice, bob };
}

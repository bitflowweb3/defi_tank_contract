
describe("deploy contract", function () {
  it("Multicall contract", async function () {
    const Factory = await ethers.getContractFactory("Multicall");
    let Multicall = await Factory.deploy();
    await Multicall.deployed();
    console.log(Multicall.address)
  });
});
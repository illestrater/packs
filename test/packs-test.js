const { expect } = require("chai");
const { utils } = require('ethers')

function base64toJSON(string) {
  return JSON.parse(Buffer.from(string.replace('data:application/json;base64,',''), 'base64').toString())
}

describe("Greeter", function() {
  let tokenPrice = ethers.utils.parseEther("0.0777");
  let packsInstance;
  let tokenCounts = [10, 50, 20];
  let totalTokenCount = 0;
  
  tokenCounts.forEach(e => totalTokenCount += e);

  before(async () => {
    const Packs = await ethers.getContractFactory("Packs");
    packsInstance = await Packs.deploy(
      '0x0000000000000000000000000000000000000000', // '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      'Relics',
      'MONSTERCAT',
      'https://arweave.net/',
      ['First name', 'Name two', 'Thirds'],
      ['The first description', 'Second descript', 'Third yooooo'],
      ['one,two,three','ayyyooo,twooooo', 'hello'],
      tokenCounts,
      true,
      [tokenPrice, 50, 1948372],
      'https://arweave.net/license'
    );
    await packsInstance.deployed();
  });

  it("should mint one token", async function() {
    await packsInstance.functions['mint()']({value: tokenPrice})

    expect((await packsInstance.getTokens()).length).to.equal(totalTokenCount - 1);
  });

  it("should bulk mint all tokens", async function() {
    expect(packsInstance.bulkMint(10000, {value: tokenPrice.mul(10000) })).to.be.reverted;

    await packsInstance.bulkMint(50, {value: tokenPrice.mul(50) });
    expect((await packsInstance.getTokens()).length).to.equal(totalTokenCount - 1 - 50);

    await packsInstance.bulkMint(totalTokenCount - 1 - 50, {value: tokenPrice.mul(totalTokenCount - 1 - 50) });
    expect((await packsInstance.getTokens()).length).to.equal(0);

    const [owner] = await ethers.getSigners();
    expect(await packsInstance.ownerOf(100001)).to.equal(owner.address);
  });

  it("first token ", async function() {
    await packsInstance.addVersion(1, 'fourrrrrrr');
    await packsInstance.updateVersion(1, 4);
    const yo = await packsInstance.tokenURI(100008);
    console.log(base64toJSON(yo));
  });
});

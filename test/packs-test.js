const { expect } = require("chai");
const { utils } = require('ethers')

describe("Greeter", function() {
  let tokenPrice = ethers.utils.parseEther("0.0777");
  let packsInstance;

  before(async () => {
    const Packs = await ethers.getContractFactory("Packs");
    packsInstance = await Packs.deploy(
      '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      'Relics',
      'MONSTERCAT',
      'https://arweave.net/',
      [utils.formatBytes32String('One'), utils.formatBytes32String('Two'), utils.formatBytes32String('Three')],
      [utils.formatBytes32String('The first'), utils.formatBytes32String('The second'), utils.formatBytes32String('The third')],
      [utils.formatBytes32String('1234'), utils.formatBytes32String('34242'), utils.formatBytes32String('f123')],
      [10, 50, 20],
      true,
      tokenPrice,
      20,
      1948372,
      'https://arweave.net/license'
    );
    await packsInstance.deployed();
  });

  it("should mint one token", async function() {
    await packsInstance.mint({ value: tokenPrice });

    packsInstance.getTokens().then(e => {
      e.forEach(n => {
        console.log(n.toString());
      })
    });

    // expect(await packs.shuffleIDs).to.equal("Hello, world!");

    // const setGreetingTx = await greeter.setGreeting("Hola, mundo!");
    
    // // wait until the transaction is mined
    // await setGreetingTx.wait();

    // expect(await greeter.greet()).to.equal("Hola, mundo!");
  });
});

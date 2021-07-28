const { expect } = require("chai");
const { utils } = require('ethers')
const mock = require('./mock-metadata.json');

function base64toJSON(string) {
  return JSON.parse(Buffer.from(string.replace('data:application/json;base64,',''), 'base64').toString())
}

describe("Greeter", function() {
  const baseURI = 'https://arweave.net/';
  const tokenPrice = ethers.utils.parseEther("0.0777");
  const tokenCounts = [10, 50, 20];
  const metadata = mock.data;
  
  let totalTokenCount = 0;
  tokenCounts.forEach(e => totalTokenCount += e);
  
  let packsInstance;

  before(async () => {
    const Packs = await ethers.getContractFactory("Packs");
    packsInstance = await Packs.deploy(
      // '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
      'Relics',
      'MONSTERCAT',
      baseURI,
      true,
      [tokenPrice, 50, 1948372],
      'https://arweave.net/license',
    );
    await packsInstance.deployed();
  });

  it("should create collectible", async function() {
    await packsInstance.addCollectible(metadata[0].coreData, metadata[0].assets, metadata[0].metaData);
  });

  it("should bulk add collectible", async function() {
    const coreData = [metadata[1].coreData, metadata[2].coreData]
    const assets = [metadata[1].assets, metadata[2].assets]
    const metaData = [metadata[1].metaData, metadata[2].metaData]
    await packsInstance.bulkAddCollectible(coreData, assets, metaData);
  });

  it("should match the total token count", async function() {
    expect((await packsInstance.totalTokenCount())).to.equal(totalTokenCount);
  });

  it("should mint one token", async function() {
    await packsInstance.functions['mint()']({value: tokenPrice})
    expect((await packsInstance.getTokens()).length).to.equal(totalTokenCount - 1);
  });

  it("should reject mints with insufficient funds", async function() {
    expect(packsInstance.functions['mint()']({value: tokenPrice.div(2) })).to.be.reverted;
    expect(packsInstance.bulkMint(50, {value: tokenPrice.mul(49) })).to.be.reverted;
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

  it("metadata should match and be updated", async function() {
    const yo = await packsInstance.tokenURI(100008);
    const tokenJSON = base64toJSON(yo);
    expect(tokenJSON.name).to.equal(`${ metadata[0].coreData[0] } #8`);
    expect(tokenJSON.description).to.equal(metadata[0].coreData[1]);
    expect(tokenJSON.image).to.equal(`${ baseURI }one`);
    expect(tokenJSON.attributes[0].trait_type).to.equal(metadata[0].metaData[0][0]);
    expect(tokenJSON.attributes[0].value).to.equal(metadata[0].metaData[0][1]);
  });

  it ("should update metadata", async function() {
    const newMetadata = 'new new';
    await packsInstance.updateMetadata(1, 0, newMetadata);
    const yo = await packsInstance.tokenURI(100008);
    const tokenJSON = base64toJSON(yo);
    expect(tokenJSON.attributes[0].trait_type).to.equal(metadata[0].metaData[0][0]);
    expect(tokenJSON.attributes[0].value).to.equal(newMetadata);
  });

  it ("should not be able to update permanent metadata", async function() {
    expect(packsInstance.updateMetadata(1, 1, 'should not update')).to.be.reverted;
  })

  it("should update image asset and version", async function() {
    await packsInstance.addVersion(1, 'fourrrrrrr');
    await packsInstance.updateVersion(1, 4);
    const tokenJSON = base64toJSON(await packsInstance.tokenURI(100008));
    expect(tokenJSON.image).to.equal(`${ baseURI }fourrrrrrr`);
  });

  it("should add new license version", async function() {
    const license = await packsInstance.getLicense();
    expect(license).to.equal('https://arweave.net/license');

    await packsInstance.addNewLicense('https://arweave.net/new-license');
    const updatedLicense = await packsInstance.getLicense();
    expect(updatedLicense).to.equal('https://arweave.net/new-license');
  });

  it("should have original license", async function() {
    const license = await packsInstance.getLicenseVersion(1);
    expect(license).to.equal('https://arweave.net/license');
  })

  /* TODO: Write test to check non-editioned names */
});

// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ERC721PresetMinterPauserAutoId.sol";
import "./IPacks.sol";

contract Packs is IPacks, ERC721PresetMinterPauserAutoId, ReentrancyGuard {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  address payable public daoAddress;
  bool public daoInitialized;

  string private _name;
  string private _symbol;
  string private _baseURI;
  bytes32[] public titles;
  bytes32[] public descriptions;
  bytes32[] public assets;
  uint256[] public counts;
  uint256[] public tokenIDs;
  uint256[] public shuffleIDs;
  uint256 public totalNFTCount;
  uint256 public tokenPrice;
  uint256 public bulkBuyLimit;
  uint256 public maxSupply;
  bool public editioned;
  uint256 public saleStartTime;
  string public licenseURI;

  mapping (uint256 => address) private _owners;
  mapping (address => uint256) private _balances;
  mapping (uint256 => address) private _tokenApprovals;
  mapping (address => mapping (address => bool)) private _operatorApprovals;

  mapping (uint256 => uint256) internal _minted;
  uint256 internal _mintPointer = 0;

  constructor(
    address payable _daoAddress,
    string memory name,
    string memory symbol,
    string memory baseURI,
    bytes32[] memory _titles,
    bytes32[] memory _descriptions,
    bytes32[] memory _assets,
    uint256[] memory _counts,
    bool _editioned,
    uint256 _tokenPrice,
    uint256 _bulkBuyLimit,
    uint256 _saleStartTime,
    string memory _licenseURI
  ) ERC721PresetMinterPauserAutoId(name, symbol, baseURI) public {
    require(_titles.length == _descriptions.length && _titles.length == _assets.length && _titles.length == _counts.length);
    daoAddress = _daoAddress;
    _name = name;
    _symbol = symbol;
    _baseURI  = baseURI;
    daoInitialized = _daoAddress != address(0);
    titles = _titles;
    descriptions = _descriptions;
    assets = _assets;
    counts = _counts;
    editioned = _editioned;
    tokenPrice = _tokenPrice;
    bulkBuyLimit = _bulkBuyLimit;
    saleStartTime = _saleStartTime;
    licenseURI = _licenseURI;

    createTokenIDs();
  }

  modifier onlyDAO() {
    require(msg.sender == daoAddress, "Not called from the dao");
    _;
  }

  function random() private view returns (uint) {
    return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, assets)));
    // random()%assets.length
  }

  /** 
   * Map token order w/ URI upon mints
   * Sample token ID (edition #77) with collection of 12 different assets: 1200077
   */
  function createTokenIDs() private {
    uint256 tokenCount = 0;
    for (uint256 i = 0; i < assets.length; i++) {
      tokenCount = tokenCount + counts[i];
    }

    // uint256[] memory ids = new uint256[](tokenCount);
    uint256[] storage ids;
    uint256 count = 0;
    for (uint256 i = 0; i < assets.length; i++) {
      for (uint256 j = 0; j < counts[i]; j++) {
        ids.push((i + 1) * 100000 + (j + 1));
        count = count + 1;
      }
    }

    shuffleIDs = ids;
  }

  function getTokens() public view returns (uint256[] memory) {
    return shuffleIDs;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    return bytes(_baseURI).length > 0
        ? string(abi.encodePacked(_baseURI, tokenId))
        : '';
  }

  // Define current owners of each ID (reference infinfts)
  function mint() public override payable nonReentrant {
    uint256 randomTokenID = random() % (shuffleIDs.length - 1);
    uint256 tokenID = shuffleIDs[randomTokenID];
    shuffleIDs[randomTokenID] = shuffleIDs[shuffleIDs.length - 1];
    shuffleIDs.pop();

    if (daoInitialized) {
      (bool transferToDaoStatus, ) = daoAddress.call{value:tokenPrice}("");
      require(transferToDaoStatus, "Address: unable to send value, recipient may have reverted");
    }

    uint256 excessAmount = msg.value.sub(tokenPrice);
    if (excessAmount > 0) {
      (bool returnExcessStatus, ) = _msgSender().call{value: excessAmount}("");
      require(returnExcessStatus, "Failed to return excess.");
    }

    _mint(_msgSender(), tokenID);
  }

  function bulkBuy(uint256 amount) public override payable nonReentrant {
    require(amount <= bulkBuyLimit, "Cannot bulk buy more than the preset limit");
    require(_tokenIdTracker.current().add(amount) <= maxSupply, "Total supply reached");

    if (daoInitialized) {
      (bool transferToDaoStatus, ) = daoAddress.call{value:tokenPrice.mul(amount)}("");
      require(transferToDaoStatus, "Address: unable to send value, recipient may have reverted");
    }

    uint256 excessAmount = msg.value.sub(tokenPrice.mul(amount));
    if (excessAmount > 0) {
      (bool returnExcessStatus, ) = _msgSender().call{value: excessAmount}("");
      require(returnExcessStatus, "Failed to return excess.");
    }

    for (uint256 i = 0; i < amount; i++) {
      mint();
    }
  }

  function mint(address to) public override(ERC721PresetMinterPauserAutoId) {
    revert("Should not use this one");
  }
}
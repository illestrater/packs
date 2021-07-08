// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./ERC721PresetMinterPauserAutoId.sol";
import "./IPacks.sol";

contract Relics is IPacks, ERC721PresetMinterPauserAutoId, ReentrancyGuard {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  address payable public daoAddress;
  bool public daoInitialized;

  bytes32[] public titles;
  bytes32[] public descriptions;
  bytes32[] public assets;
  uint256[] public counts;
  uint256[] public soldCounts;
  uint256 public tokenPrice;
  uint256 public bulkBuyLimit;
  uint256 public maxSupply;
  bool public editioned;
  uint256 public saleStartTime;
  string public licenseURI;

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
    uint256 _bulkBuyLimit,
    uint256 _saleStartTime,
    string memory _licenseURI
  ) ERC721PresetMinterPauserAutoId(name, symbol, baseURI) public {
    require(_titles.length == _descriptions.length && _titles.length == _assets.length && _titles.length == _counts.length);
    daoAddress = _daoAddress;
    daoInitialized = _daoAddress != address(0);
    titles = _titles;
    descriptions = _descriptions;
    assets = _assets;
    counts = _counts;
    editioned = _editioned;
    bulkBuyLimit = _bulkBuyLimit;
    saleStartTime = _saleStartTime;
    licenseURI = _licenseURI;

    uint256 _count = 0;
    uint256[] memory _soldCounts = uint256[](_counts.length);
    for (uint i = 0; i < _counts.length; i++) {
      _count = _count + _counts[i];
      _soldCounts[i] = 0;
    }

    soldCounts = _soldCounts;
    maxSupply = _count;
  }

  modifier onlyDAO() {
    require(msg.sender == daoAddress, "Not called from the dao");
    _;
  }

  function random() private view returns (uint) {
    return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, players)));
    // random()%assets.length
  }

  /** 
   * Map token order w/ URI upon mints
   * Sample token ID (edition #77) with collection of 12 different assets: 001200077
   */

   // 10
   // 50
   // 20
  function mint() public override payable nonReentrant {
    uint256 i = 0;

    while (uint256 i = 0; i < _assets.length; i++) {

    }

    uint256 tokenId = _tokenIdTracker.current();

    if (daoInitialized) {
      (bool transferToDaoStatus, ) = daoAddress.call{value:tokenPrice}("");
      require(transferToDaoStatus, "Address: unable to send value, recipient may have reverted");
    }

    uint256 excessAmount = msg.value.sub(tokenPrice);
    if (excessAmount > 0) {
      (bool returnExcessStatus, ) = _msgSender().call{value: excessAmount}("");
      require(returnExcessStatus, "Failed to return excess.");
    }

    _mint(_msgSender(), tokenId);
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
      _tokenIdTracker.increment();
      uint256 tokenId = _tokenIdTracker.current();
      _mint(_msgSender(), tokenId);
    }
  }

  function lastTokenId() public override view returns (uint256 tokenId) {
    return _tokenIdTracker.current();
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    string memory baseURI = _baseURI();
    return bytes(baseURI).length > 0
        ? string(abi.encodePacked(baseURI, tokenId.toString()))
        : '';
  }
}
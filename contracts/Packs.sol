// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import 'base64-sol/base64.sol';
import "./ERC721PresetMinterPauserAutoId.sol";
import "./IPacks.sol";
import "hardhat/console.sol";

contract Packs is IPacks, ERC721PresetMinterPauserAutoId, ReentrancyGuard {
  using SafeMath for uint256;
  using Counters for Counters.Counter;

  address payable public daoAddress;
  bool public daoInitialized;

  string private _name;
  string private _symbol;
  string private _baseURI;

  mapping (uint256 => string) versionedAssets;
  struct SingleCollectible {
    string title;
    string description;
    uint256 count;
    uint256 versionCount;
    uint256 currentVersion;
    string[] assets; // Each asset in array is a version
  }

  mapping (uint256 => SingleCollectible) collectibles;

  uint256[] public shuffleIDs;

  uint256 public collectibleCount;
  uint256 public totalTokenCount;
  uint256 public tokenPrice;
  uint256 public bulkBuyLimit;
  uint256 public saleStartTime;
  bool public editioned;
  string public licenseURI;

  constructor(
    string memory name,
    string memory symbol,
    string memory baseURI,
    string[] memory _titles,
    string[] memory _descriptions,
    string[] memory _assets,
    uint256[] memory _counts,
    bool _editioned,
    uint256[] memory _initParams,
    string memory _licenseURI
  ) ERC721PresetMinterPauserAutoId(name, symbol, baseURI) public {
    require(_titles.length == _descriptions.length && _titles.length == _assets.length && _titles.length == _counts.length);
    daoAddress = msg.sender;
    daoInitialized = false;

    _name = name;
    _symbol = symbol;
    _baseURI  = baseURI;

    uint256 _collectibleCount = 0;
    uint256 _totalTokenCount = 0;
    for (uint256 i = 0; i < _titles.length; i++) {
      string[] memory _singleAssets = new string[](bytes(_assets[i]).length);
      uint256 substringPointer = 0;
      uint256 count = 0;
      for (uint256 j = 0; j < bytes(_assets[i]).length; j++) {
        if (bytes(_assets[i])[j] == ",") {
          // console.log(substringPointer, substring(_assets[i], substringPointer, j));
          _singleAssets[count] = substring(_assets[i], substringPointer, j);
          substringPointer = j + 1;
          count++;
        }

        if (j == bytes(_assets[i]).length - 1) {
          // console.log(substringPointer, substring(_assets[i], substringPointer, j + 1));
          _singleAssets[count] = substring(_assets[i], substringPointer, j + 1);
          substringPointer = j;
          count++;
        }
      }
      // console.log(substring(_assets[i], substringPointer, j));

      collectibles[i] = SingleCollectible({
        title: _titles[i],
        description: _descriptions[i],
        count: _counts[i],
        versionCount: count,
        currentVersion: 0,
        assets: _singleAssets
      });

      _collectibleCount++;
      _totalTokenCount += _counts[i];
    }

    collectibleCount = _collectibleCount;
    totalTokenCount = _totalTokenCount;
    editioned = _editioned;
    tokenPrice = _initParams[0];
    bulkBuyLimit = _initParams[1];
    saleStartTime = _initParams[2];
    licenseURI = _licenseURI;

    createTokenIDs();
  }

  modifier onlyDAO() {
    require(msg.sender == daoAddress, "Not called from the dao");
    _;
  }

  function transferDAOownership(address payable _daoAddress) public onlyDAO {
    daoAddress = daoAddress;
    daoInitialized = true;
  }

  function random() private view returns (uint) {
    return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, totalTokenCount)));
  }

  /** 
   * Map token order w/ URI upon mints
   * Sample token ID (edition #77) with collection of 12 different assets: 1200077
   */
  function createTokenIDs() private {
    uint256 tokenCount = 0;
    for (uint256 i = 0; i < collectibleCount; i++) {
      tokenCount = tokenCount + collectibles[i].count;
    }

    uint256[] memory ids = new uint256[](tokenCount);
    uint256 count = 0;
    for (uint256 i = 0; i < collectibleCount; i++) {
      for (uint256 j = 0; j < collectibles[i].count; j++) {
        ids[count] = (i + 1) * 100000 + (j + 1);
        count++;
      }
    }

    shuffleIDs = ids;
  }

  function getTokens() public view returns (uint256[] memory) {
    return shuffleIDs;
  }

  // Define current owners of each ID (reference infinfts)
  function mint() public override payable {
    if (daoInitialized) {
      (bool transferToDaoStatus, ) = daoAddress.call{value:tokenPrice}("");
      require(transferToDaoStatus, "Address: unable to send value, recipient may have reverted");
    }

    uint256 excessAmount = msg.value.sub(tokenPrice);
    if (excessAmount > 0) {
      (bool returnExcessStatus, ) = _msgSender().call{value: excessAmount}("");
      require(returnExcessStatus, "Failed to return excess.");
    }

    uint256 randomTokenID = random() % (shuffleIDs.length - 1);
    uint256 tokenID = shuffleIDs[randomTokenID];
    shuffleIDs[randomTokenID] = shuffleIDs[shuffleIDs.length - 1];
    shuffleIDs.pop();
    _mint(_msgSender(), tokenID);
  }

  function bulkMint(uint256 amount) public override payable nonReentrant {
    require(amount <= bulkBuyLimit, "Cannot bulk buy more than the preset limit");
    require(amount <= shuffleIDs.length, "Total supply reached");

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
      uint256 randomTokenID = shuffleIDs.length == 1 ? 0 : random() % (shuffleIDs.length - 1);
      uint256 tokenID = shuffleIDs[randomTokenID];
      shuffleIDs[randomTokenID] = shuffleIDs[shuffleIDs.length - 1];
      shuffleIDs.pop();
      _mint(_msgSender(), tokenID);
    }
  }

  function mint(address to) public override(ERC721PresetMinterPauserAutoId) {
    revert("Should not use this one");
  }

  // Index starts at version 1, collectible 1 (so shifts 1 for 0th index)
  function updateVersion(uint256 collectibleNumber, uint256 versionNumber) public onlyDAO {
    collectibles[collectibleNumber - 1].currentVersion = versionNumber - 1;
  }

  function addVersion(uint256 collectibleNumber, string memory asset) public onlyDAO {
    collectibles[collectibleNumber - 1].assets[collectibles[collectibleNumber - 1].versionCount] = asset;
    collectibles[collectibleNumber - 1].versionCount++;
  }

  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    string memory stringId = toString(tokenId);
    uint256 edition = safeParseInt(substring(stringId, bytes(stringId).length - 5, bytes(stringId).length)) - 1;
    uint256 collectibleId = (tokenId - edition) / 100000 - 1;

    return
      string(
        abi.encodePacked(
          'data:application/json;base64,',
          Base64.encode(
            bytes(
              abi.encodePacked(
                '{"name":"',
                collectibles[collectibleId].title,
                editioned ? ' #' : '',
                editioned ? toString(edition) : '',
                '", "description":"',
                collectibles[collectibleId].description,
                '", "image": "',
                _baseURI,
                collectibles[collectibleId].assets[collectibles[collectibleId].currentVersion],
                '"}'
              )
            )
          )
        )
      );
  }

  function toString(uint256 value) internal pure returns (string memory) {
    if (value == 0) {
        return "0";
    }
    uint256 temp = value;
    uint256 digits;
    while (temp != 0) {
        digits++;
        temp /= 10;
    }
    bytes memory buffer = new bytes(digits);
    uint256 index = digits - 1;
    temp = value;
    while (temp != 0) {
        buffer[index--] = bytes1(uint8(48 + temp % 10));
        temp /= 10;
    }
    return string(buffer);
  }

  // Functions from https://github.com/provable-things/ethereum-api/blob/master/provableAPI_0.6.sol
  function safeParseInt(string memory _a) internal pure returns (uint _parsedInt) {
    return safeParseInt(_a, 0);
  }

  function safeParseInt(string memory _a, uint _b) internal pure returns (uint _parsedInt) {
    bytes memory bresult = bytes(_a);
    uint mint = 0;
    bool decimals = false;
    for (uint i = 0; i < bresult.length; i++) {
      if ((uint(uint8(bresult[i])) >= 48) && (uint(uint8(bresult[i])) <= 57)) {
        if (decimals) {
            if (_b == 0) break;
            else _b--;
        }
        mint *= 10;
        mint += uint(uint8(bresult[i])) - 48;
      } else if (uint(uint8(bresult[i])) == 46) {
        require(!decimals, 'More than one decimal encountered in string!');
        decimals = true;
      } else {
        revert("Non-numeral character encountered in string!");
      }
    }
    if (_b > 0) {
      mint *= 10 ** _b;
    }
    return mint;
  }

  function substring(string memory str, uint startIndex, uint endIndex) internal pure returns (string memory) {
    bytes memory strBytes = bytes(str);
    bytes memory result = new bytes(endIndex-startIndex);
    for(uint i = startIndex; i < endIndex; i++) {
        result[i-startIndex] = strBytes[i];
    }
    return string(result);
  }
}
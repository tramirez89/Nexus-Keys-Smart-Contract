//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract NexusKeys is ERC1155Supply, Ownable {
  string public website = "https://nexuslegends.io";
  event PermanentURI(string _value, uint256 indexed _id);

  uint256 public MAX_MINT = 4;

  bool saleOpen;
  bool publicSaleOpen;
  bool frozen;
  bytes32 merkleRoot;
  bytes32 claimMerkleRoot;

  struct Key {
    string metadataURI;
    uint256 mintPrice;
    uint256 maxSupply;
  }

  mapping(uint256 => Key) public Keys;
  mapping(address => uint256) public minted;
  mapping(address => uint256) public allowlistMinted;
  mapping(address => uint256) public claimed;

  string public name_;
  string public symbol_;

  constructor() ERC1155("ipfs://") {
    name_ = "Nexus Keys";
    symbol_ = "NEXUSKEYS";
  }

  modifier callerIsUser() {
    require(tx.origin == msg.sender, "The caller is another contract");
    _;
  }

  function ownerMint(
    address[] calldata _to,
    uint256[] calldata _amount,
    uint256[] calldata keyId
  ) external onlyOwner {
    require(!frozen, "Frozen.");
    require(_to.length == _amount.length, "same length required");

    for (uint256 i; i < _to.length; i++) {
      require(totalSupply(keyId[i]) + _amount[i] <= Keys[keyId[i]].maxSupply, "Max supply reached");
      _mint(_to[i], keyId[i], _amount[i], "");
    }
  }

  struct ALLOC {
    uint256 t;
    uint256 c;
    uint256 e;
    uint256 l;
    uint256 i;
    uint256 f;
    uint256 n;
  }

  function allowlistMint(
    uint256[] calldata amount,
    bytes32[] calldata merkleProof,
    ALLOC calldata alloc
  ) external payable callerIsUser {
    require(saleOpen, "Sale not started");
    uint256 totalPrice;
    uint256 total;
    for (uint256 i; i < amount.length; i++) {
      require(Keys[i].maxSupply > 0, "Key does not exist");
      require(amount[i] + totalSupply(i) <= Keys[i].maxSupply, "Max supply reached");

      total += amount[i];
      totalPrice += Keys[i].mintPrice * amount[i];
    }
    require(msg.value == totalPrice, "Incorrect ETH amount");

    bytes32 leaf = keccak256(
      abi.encodePacked(msg.sender, alloc.t, alloc.c, alloc.e, alloc.l, alloc.i, alloc.f, alloc.n)
    );
    require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "Invalid proof.");

    require(allowlistMinted[msg.sender] + total < MAX_MINT, "Exceeds max mint");
    require(allowlistMinted[msg.sender] + total < alloc.e + alloc.l, "Exceeds your allocation");

    allowlistMinted[msg.sender] += total;

    for (uint256 i; i < amount.length; i++) {
      _mint(msg.sender, i, amount[i], "");
    }
  }

  function claim(
    uint256 keyId,
    bytes32[] calldata merkleProof,
    ALLOC calldata alloc
  ) external callerIsUser {
    require(saleOpen, "Sale not started");
    require(!frozen, "Frozen.");
    require(1 + totalSupply(keyId) <= Keys[keyId].maxSupply, "Max supply reached");
    require(Keys[keyId].maxSupply > 0, "Key does not exist");
    require(claimed[msg.sender] == 0, "Exceeds your allocation");
    bytes32 leaf = keccak256(
      abi.encodePacked(msg.sender, alloc.t, alloc.c, alloc.e, alloc.l, alloc.i, alloc.f, alloc.n)
    );
    require(MerkleProof.verify(merkleProof, claimMerkleRoot, leaf), "Invalid proof.");

    claimed[msg.sender]++;
    _mint(msg.sender, keyId, 1, "");
  }

  function mint(uint256 amount, uint256 keyId) external payable callerIsUser {
    require(publicSaleOpen, "Sale not started");
    require(!frozen, "Frozen.");
    require(amount + totalSupply(keyId) <= Keys[keyId].maxSupply, "Max supply reached");
    require(Keys[keyId].maxSupply > 0, "Key does not exist");
    require(minted[msg.sender] + amount < MAX_MINT, "Exceeds max mint");
    require(msg.value == (Keys[keyId].mintPrice * amount), "Incorrect ETH amount");

    minted[msg.sender] += amount;
    _mint(msg.sender, keyId, amount, "");
  }

  /**
   * @notice Create a Nexus Key.
   * @param keyId The token id to set this key to.
   * @param key ["metadataURI", mintPrice, maxSupply]
   */
  function createKey(uint256 keyId, Key calldata key) external onlyOwner {
    require(!frozen, "Frozen.");
    require(Keys[keyId].maxSupply == 0, "Key already exists");
    Keys[keyId] = key;
  }

  function updateURI(uint256 keyId, string calldata _uri) external onlyOwner {
    require(!frozen, "Frozen.");
    require(Keys[keyId].maxSupply > 0, "Key does not exist");
    Keys[keyId].metadataURI = _uri;
  }

  function updateMintPrice(uint256 keyId, uint256 price) external onlyOwner {
    require(!frozen, "Frozen.");
    require(Keys[keyId].maxSupply > 0, "Key does not exist");
    Keys[keyId].mintPrice = price;
  }

  function updateMaxSupply(uint256 keyId, uint256 qty) external onlyOwner {
    require(!frozen, "Frozen.");
    require(Keys[keyId].maxSupply > 0, "Key does not exist");
    Keys[keyId].maxSupply = qty;
  }

  /**
   * @notice Toggle the sale.
   */
  function toggleSale() external onlyOwner {
    require(!frozen, "Frozen.");
    saleOpen = !saleOpen;
  }

  function togglePublicSale() external onlyOwner {
    require(!frozen, "Frozen.");
    publicSaleOpen = !publicSaleOpen;
  }

  function updateWebsite(string calldata url) external onlyOwner {
    website = url;
  }

  /**
   * @notice Set the merkle root.
   */
  function updateMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
    merkleRoot = _merkleRoot;
  }

  function updateClaimMerkleRoot(bytes32 _merkleRoot) external onlyOwner {
    claimMerkleRoot = _merkleRoot;
  }

  // Permanently freeze metadata and minting functions
  function freeze() external onlyOwner {
    frozen = true;

    emit PermanentURI(Keys[0].metadataURI, 0);
    emit PermanentURI(Keys[1].metadataURI, 1);
    emit PermanentURI(Keys[2].metadataURI, 2);
    emit PermanentURI(Keys[3].metadataURI, 3);
  }

  /**
   * @notice Get the metadata uri for a specific key.
   * @param _id The key to return metadata for.
   */
  function uri(uint256 _id) public view override returns (string memory) {
    require(exists(_id), "URI: nonexistent token");

    return string(abi.encodePacked(Keys[_id].metadataURI));
  }

  function getKey(uint256 id) external view returns (Key memory) {
    return Keys[id];
  }

  function getMintedQty(
    address addr,
    uint256 mintType // 1: Minted, 2: allowlistMinted, 3: Claimed
  ) external view returns (uint256) {
    if (mintType == 1) {
      return minted[addr];
    } else if (mintType == 2) {
      return allowlistMinted[addr];
    } else {
      return claimed[addr];
    }
  }

  function getSalesStatus() external view returns (bool, bool) {
    return (saleOpen, publicSaleOpen);
  }
}
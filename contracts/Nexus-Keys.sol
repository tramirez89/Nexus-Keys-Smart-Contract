//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract NexusKeys is ERC1155Supply, Ownable {
    string public website = "https://nexuslegends.io";

    uint256 public MAX_MINT = 4;

    bool saleOpen;
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
            require(
                totalSupply(keyId[i]) + _amount[i] <= Keys[keyId[i]].maxSupply,
                "Max supply reached"
            );
            _mint(_to[i], keyId[i], _amount[i], "");
        }
    }

    function allowlistMint(
        uint256 amount,
        uint256 maxAmount,
        uint256 keyId,
        uint256 ticket,
        bytes32[] calldata merkleProof
    ) external payable callerIsUser {
        require(saleOpen, "Sale not started");
        require(
            amount + totalSupply(keyId) <= Keys[keyId].maxSupply,
            "Max supply reached"
        );
        require(Keys[keyId].maxSupply > 0, "Key does not exist");
        require(minted[msg.sender] + amount < MAX_MINT, "Exceeds max mint");
        require(
            minted[msg.sender] + amount < maxAmount,
            "Exceeds your allocation"
        );
        require(
            msg.value == Keys[keyId].mintPrice * amount,
            "Incorrect ETH amount"
        );
        bytes32 leaf = keccak256(
            abi.encodePacked(msg.sender, ticket, maxAmount)
        );
        require(
            MerkleProof.verify(merkleProof, merkleRoot, leaf),
            "Invalid proof."
        );

        minted[msg.sender] += amount;

        _mint(msg.sender, keyId, amount, "");
    }

    function claim(
        uint256 amount,
        uint256 maxAmount,
        uint256 keyId,
        uint256 ticket,
        bytes32[] calldata merkleProof
    ) external callerIsUser {
        require(saleOpen, "Sale not started");
        require(
            amount + totalSupply(keyId) <= Keys[keyId].maxSupply,
            "Max supply reached"
        );
        require(Keys[keyId].maxSupply > 0, "Key does not exist");
        require(
            claimed[msg.sender] + amount < maxAmount,
            "Exceeds your allocation"
        );
        bytes32 leaf = keccak256(
            abi.encodePacked(msg.sender, ticket, maxAmount)
        );
        require(
            MerkleProof.verify(merkleProof, claimMerkleRoot, leaf),
            "Invalid proof."
        );

        claimed[msg.sender] += amount;

        _mint(msg.sender, keyId, amount, "");
    }

    /**
     * OWNER FUNCTIONS
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
    }

    /**
     * @notice Get the metadata uri for a specific key.
     * @param _id The key to return metadata for.
     */
    function uri(uint256 _id) public view override returns (string memory) {
        require(exists(_id), "URI: nonexistent token");

        return string(abi.encodePacked(Keys[_id].metadataURI));
    }
}

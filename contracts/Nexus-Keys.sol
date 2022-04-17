//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import './AbstractERC1155Factory.sol';
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract NexusKeys is AbstractERC1155Factory {
    string public website = "https://nexuslegends.io";

    uint256 public constant MAX_MINT = 2;

    bytes32 merkleRoot;
    bool saleOpen;
    bool frozen;

    struct Key {
        string name;
        string image;
        string description;
        string metadataURI;
        uint256 maxSupply;
        uint256 mintPrice;
    }

    mapping(uint256 => Key) public Keys;
    mapping(address => uint256) public minted;

    constructor() {
        name_ = "Nexus Keys";
        symbol_ = "NEXUSKEYS";
    }

    modifier callerIsUser() {
        require(tx.origin == msg.sender, "The caller is another contract");
        _;
    }

    function ownerMint (
        address[] calldata _to, 
        uint256[] calldata _amount,
        uint256[] calldata keyId
    ) external onlyOwner {
        require(!frozen, "Frozen.");
        require(_to.length == _amount.length, "same length required");

        for(uint256 i; i < _to.length; i++) {
            require(totalSupply(keyId[i]) + _amount[i] <= Keys[keyId[i]].maxSupply, "Max supply reached");
            _mint(_to[i], keyId[i], _amount[i], "");
        }
    }
    
    function allowlistMint(
        uint256 amount,
        uint256 maxAmount,
        uint256 keyId,
        bytes32[] merkleProof
    ) external payable callerIsUser {
        require(saleOpen, "Sale not started");
        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply reached");
        require(Keys[keyId].maxSupply > 0, "Key does not exist");
        require(minted[msg.sender] + amount < MAX_MINT, "Exceeds max mint");
        require(minted[msg.sender] + amount < maxAmount, "Exceeds your allocation");
        require(msg.value == Keys[keyId].price * amount, "Incorrect ETH amount" );
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender, ticket, maxAmount));
        require(MerkleProof.verify(merkleProof, chapter.merkleRoot, leaf), "Invalid proof.");

        minted[msg.sender] += amount;

        _mint(msg.sender, keyId, amount)
    }

    /**
    * OWNER FUNCTIONS
     */
    function createKey(uint256 keyId, Key calldata key) external onlyOwner{
        require(!frozen, "Frozen.");
        require(Keys[keyId].maxSupply == 0, "Key already exists" );
        Keys[keyId] = key;
    }


     function updateURI(uint256 keyId, string calldata uri) external onlyOwner {
        require(!frozen, "Frozen.");
        require(Keys[keyId].maxSupply > 0, "Key does not exist");
        Keys[keyId].metadataURI = uri;
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
    * @notice Set the merkle root for a chapter.
    */
    function updateMerkleRoot(bytes32 _merkleRoot) external chapterExists(chapterId) onlyOwner {
        // chapterMerkle[chapterId] = merkleRoot;
        merkleRoot = _merkleRoot;
    }

    // Permanently freeze metadata and minting functions
     function freeze() external onlyOwner {
         frozen = true;
     }
}

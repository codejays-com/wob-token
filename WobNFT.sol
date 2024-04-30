// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WobNFT is ERC721URIStorage, Ownable {
    using SafeMath for uint256;

    struct Item {
        string name;
        uint256 damage;
        uint256 attackSpeed;
        uint256 durability;
        uint256 maxDurability;
        uint256 durabilityPerUse;
        string weaponType;
        string imageUrl;
        uint256 price;
    }

    mapping(uint256 => Item) private items;
    mapping(uint256 => bool) private isForSale;
    mapping(uint256 => string) private tokenURIs;

    IERC20 private WOB;
    uint256 private tokenIdCounter;
    string private _baseTokenURI;

    address public constant WOBTokenContract =
        0x71B54fd9F928FF10D5990f80D1E19c2BC866a821;

    event ItemCreated(uint256 indexed tokenId, address indexed owner);

    event ItemListedForSale(
        uint256 indexed tokenId,
        address indexed owner,
        uint256 price
    );

    event ItemDelistedFromSale(uint256 indexed tokenId, address indexed owner);

    event ItemPurchased(
        uint256 indexed tokenId,
        address indexed buyer,
        address indexed seller,
        uint256 price
    );

    event ItemUpdated(uint256 indexed tokenId, address indexed owner);

    modifier onlyTokenOwner(uint256 tokenId) {
        require(
            ownerOf(tokenId) == msg.sender,
            "You are not the owner of this token"
        );
        _;
    }

    constructor(address initialOwner)
        ERC721("World Of Blast NFT", "WobNFT")
        Ownable(initialOwner)
    {
        WOB = IERC20(WOBTokenContract);
    }

    function Mint(
        string memory name,
        uint256 damage,
        uint256 attackSpeed,
        uint256 durability,
        uint256 maxDurability,
        uint256 durabilityPerUse,
        string memory weaponType,
        string memory imageUrl,
        uint256 price,
        uint256 quantity
    ) external onlyOwner {
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = tokenIdCounter;
            tokenIdCounter++;
            items[tokenId] = Item(
                name,
                damage,
                attackSpeed,
                maxDurability,
                durability,
                durabilityPerUse,
                weaponType,
                imageUrl,
                price
            );
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, imageUrl);
            emit ItemCreated(tokenId, msg.sender);
        }
    }

    function listItemForSale(uint256 tokenId, uint256 price)
        external
        onlyTokenOwner(tokenId)
    {
        isForSale[tokenId] = true;
        emit ItemListedForSale(tokenId, ownerOf(tokenId), price);
    }

    function delistItemForSale(uint256 tokenId)
        external
        onlyTokenOwner(tokenId)
    {
        isForSale[tokenId] = false;
        emit ItemDelistedFromSale(tokenId, ownerOf(tokenId));
    }

    function buyItem(uint256 tokenId) external {
        address seller = ownerOf(tokenId);
        address buyer = msg.sender;
        uint256 price = items[tokenId].price;

        require(isForSale[tokenId], "Item is not listed for sale");
        require(balanceOf(seller) > 0, "Seller does not own the token");
        require(
            WOB.allowance(buyer, address(this)) >= price,
            "Insufficient allowance"
        );

        // Ensure buyer pays the correct amount of tokens
        require(
            WOB.transferFrom(buyer, seller, price),
            "Token transfer failed"
        );

        // Transfer the NFT to the buyer
        _transfer(seller, buyer, tokenId);

        // Mark the item as not for sale
        isForSale[tokenId] = false;
        emit ItemPurchased(tokenId, buyer, seller, price);
    }

    function updateTokenURI(uint256 tokenId, string memory newTokenURI)
        external
        onlyOwner
    {
        require(balanceOf(ownerOf(tokenId)) > 0, "Token ID does not exist");
        _setTokenURI(tokenId, newTokenURI);
        tokenURIs[tokenId] = newTokenURI;
        emit ItemUpdated(tokenId, ownerOf(tokenId));
    }

    function updateItemDurability(uint256 tokenId, uint256 newDurability)
        external
        onlyOwner
    {
        require(balanceOf(ownerOf(tokenId)) > 0, "Token ID does not exist");
        Item storage item = items[tokenId];
        item.durability = newDurability;
        emit ItemUpdated(tokenId, ownerOf(tokenId));
    }

    function getItem(uint256 tokenId)
        external
        view
        returns (
            string memory name,
            uint256 damage,
            uint256 attackSpeed,
            uint256 maxDurability,
            uint256 durability,
            uint256 durabilityPerUse,
            string memory weaponType,
            string memory imageUrl,
            uint256 price
        )
    {
        Item storage item = items[tokenId];
        return (
            item.name,
            item.damage,
            item.attackSpeed,
            item.maxDurability,
            item.durability,
            item.durabilityPerUse,
            item.weaponType,
            item.imageUrl,
            item.price
        );
    }

    function transferItem(address to, uint256 tokenId)
        external
        onlyTokenOwner(tokenId)
    {
        _transfer(msg.sender, to, tokenId);
    }
 

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(balanceOf(ownerOf(tokenId)) > 0, "Token ID does not exist");

        string memory baseURI = _baseURI();
        string memory json = string(
            abi.encodePacked(
                '{"name": "',
                items[tokenId].name,
                '", ',
                '"description": "NFT Description", ',
                '"image": "',
                items[tokenId].imageUrl,
                '", ',
                '"attributes": {',
                '"damage": ',
                uint2str(items[tokenId].damage),
                ", ",
                '"attackSpeed": ',
                uint2str(items[tokenId].attackSpeed),
                ", ",
                '"durability": ',
                uint2str(items[tokenId].durability),
                ", ",
                '"maxDurability": ',
                uint2str(items[tokenId].maxDurability),
                ", ",
                '"durabilityPerUse": ',
                uint2str(items[tokenId].durabilityPerUse),
                ", ",
                '"weaponType": "',
                items[tokenId].weaponType,
                '"',
                "}}"
            )
        );
        return string(abi.encodePacked(baseURI, json));
    }

    function uint2str(uint256 _i)
        internal
        pure
        returns (string memory _uintAsString)
    {
        if (_i == 0) {
            return "0";
        }
        uint256 j = _i;
        uint256 length;
        while (j != 0) {
            length++;
            j /= 10;
        }
        bytes memory bstr = new bytes(length);
        uint256 k = length;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - (_i / 10) * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
}

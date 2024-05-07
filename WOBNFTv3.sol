// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Crafting contract
contract Crafting {
    struct Item {
        string name;
        string description;
        uint256 damage;
        uint256 attackSpeed;
        uint256 durability;
        uint256 durabilityPerUse;
        string weaponType;
        string imageUrl;
        uint256 price;
        string rarity;
    }

    Item[] public craftableItems;
    mapping(uint256 => uint256) public craftableItemIndex;
    mapping(address => bool) public creators;

    uint256 public totalCraftableItems;

    address public owner;

    event CraftableItemCreated(uint256 indexed itemId, Item craftableItem);
    event CraftableItemEdited(uint256 indexed itemId, Item craftableItem);
    event CraftableItemDeleted(uint256 indexed itemId);

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only contract owner can call this function"
        );
        _;
    }

    constructor() {
        creators[msg.sender] = true;
        owner = msg.sender;
    }

    function addCreator(address _creator) external onlyOwner {
        creators[_creator] = true;
    }

    function removeCreator(address _creator) external onlyOwner {
        creators[_creator] = false;
    }

    function createCraftableItem(
        string memory name,
        string memory description,
        uint256 damage,
        uint256 attackSpeed,
        uint256 durability,
        uint256 durabilityPerUse,
        string memory weaponType,
        string memory imageUrl,
        uint256 price,
        string memory rarity
    ) external onlyOwner {
        Item memory newItem = Item({
            name: name,
            description: description,
            damage: damage,
            attackSpeed: attackSpeed,
            durability: durability,
            durabilityPerUse: durabilityPerUse,
            weaponType: weaponType,
            imageUrl: imageUrl,
            price: price,
            rarity: rarity
        });
        craftableItems.push(newItem);
        craftableItemIndex[totalCraftableItems] = craftableItems.length - 1;
        totalCraftableItems++;
        emit CraftableItemCreated(totalCraftableItems - 1, newItem);
    }

    function editCraftableItem(
        uint256 itemId,
        string memory name,
        string memory description,
        uint256 damage,
        uint256 attackSpeed,
        uint256 durability,
        uint256 durabilityPerUse,
        string memory weaponType,
        string memory imageUrl,
        uint256 price,
        string memory rarity
    ) external onlyOwner {
        require(itemId < totalCraftableItems, "Item ID out of range");
        uint256 index = craftableItemIndex[itemId];
        Item storage craftableItem = craftableItems[index];
        craftableItem.name = name;
        craftableItem.description = description;
        craftableItem.damage = damage;
        craftableItem.attackSpeed = attackSpeed;
        craftableItem.durability = durability;
        craftableItem.durabilityPerUse = durabilityPerUse;
        craftableItem.weaponType = weaponType;
        craftableItem.imageUrl = imageUrl;
        craftableItem.price = price;
        craftableItem.rarity = rarity;
        emit CraftableItemEdited(itemId, craftableItem);
    }

    function deleteCraftableItem(uint256 itemId) external onlyOwner {
        require(itemId < totalCraftableItems, "Item ID out of range");
        uint256 indexToDelete = craftableItemIndex[itemId];
        delete craftableItems[indexToDelete];
        emit CraftableItemDeleted(itemId);
    }

    function getAllCraftableItems() external view returns (Item[] memory) {
        return craftableItems;
    }
}

contract WorldOfBlastNft is ERC721URIStorage, Ownable {
    using SafeMath for uint256;

    struct Item {
        string name;
        string description;
        uint256 damage;
        uint256 attackSpeed;
        uint256 durability;
        uint256 durabilityPerUse;
        string weaponType;
        string imageUrl;
        uint256 price;
        string rarity;
        bool isStaked;
    }

    Crafting public craftingContract;
    IERC20 private WOB;

    address payable public _owner;

    address public constant WOBTokenContract =
        0x0BCAEec9dF553b0E59a0928FCCd9dcf8C0b42601;

    uint256 public priceToCreateNftWOB;
    uint256 private tokenIdCounter;
    string private _contractURI;

    mapping(uint256 => Item) private items;
    mapping(address => bool) public creators;

    event ItemCreated(uint256 indexed tokenId, address indexed owner);
    event ItemUpdated(uint256 indexed tokenId, uint256 durability);
    event InBattleSet(uint256 indexed tokenId, bool value);

    modifier onlyTokenOwner(uint256 tokenId) {
        require(
            ownerOf(tokenId) == msg.sender,
            "You are not the owner of this token"
        );
        _;
    }
    modifier onlyOwnerOrCreator() {
        require(
            msg.sender == _owner || creators[msg.sender],
            "Only owner or creator"
        );
        _;
    }

    constructor() ERC721("World Of Blast", "WOBNFTs") Ownable(msg.sender) {
        WOB = IERC20(WOBTokenContract);
        _owner = payable(msg.sender);
        _contractURI = "https://worldofblast.com/assets/contract.json";
        creators[msg.sender] = true;
        craftingContract = new Crafting();
    }

    function withdrawWOB(address to, uint256 amount) external onlyOwner {
        require(WOB.transfer(to, amount), "Failed to transfer WOB");
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function updatePriceToCreateNftWOB(uint256 price) external onlyOwner {
        priceToCreateNftWOB = price;
    }

    function addCreator(address _creator) external onlyOwner {
        creators[_creator] = true;
        craftingContract.addCreator(_creator);
    }

    function removeCreator(address _creator) external onlyOwner {
        creators[_creator] = false;
        craftingContract.removeCreator(_creator);
    }

    function getAllCraftableItems()
        external
        view
        returns (Crafting.Item[] memory)
    {
        return craftingContract.getAllCraftableItems();
    }

    function createCraftableItem(
        string memory name,
        string memory description,
        uint256 damage,
        uint256 attackSpeed,
        uint256 durability,
        uint256 durabilityPerUse,
        string memory weaponType,
        string memory imageUrl,
        uint256 price,
        string memory rarity
    ) external onlyOwnerOrCreator {
        craftingContract.createCraftableItem(
            name,
            description,
            damage,
            attackSpeed,
            durability,
            durabilityPerUse,
            weaponType,
            imageUrl,
            price,
            rarity
        );
    }

    function editCraftableItem(
        uint256 itemId,
        string memory name,
        string memory description,
        uint256 damage,
        uint256 attackSpeed,
        uint256 durability,
        uint256 durabilityPerUse,
        string memory weaponType,
        string memory imageUrl,
        uint256 price,
        string memory rarity
    ) external onlyOwnerOrCreator {
        craftingContract.editCraftableItem(
            itemId,
            name,
            description,
            damage,
            attackSpeed,
            durability,
            durabilityPerUse,
            weaponType,
            imageUrl,
            price,
            rarity
        );
    }

    function getCraftableItem(uint256 itemId)
        external
        view
        returns (string memory)
    {
        require(
            itemId < craftingContract.totalCraftableItems(),
            "Index out of range"
        );
        (
            string memory name,
            string memory description,
            uint256 damage,
            uint256 attackSpeed,
            uint256 durability,
            uint256 durabilityPerUse,
            string memory weaponType,
            string memory imageUrl,
            uint256 price,
            string memory rarity
        ) = craftingContract.craftableItems(itemId);

        string memory json = string(
            abi.encodePacked(
                '{"name": "',
                name,
                '", ',
                '"description": "',
                description,
                '", ',
                '"damage": ',
                uint2str(damage),
                ", ",
                '"attackSpeed": ',
                uint2str(attackSpeed),
                ", ",
                '"durability": ',
                uint2str(durability),
                ", ",
                '"durabilityPerUse": ',
                uint2str(durabilityPerUse),
                ", ",
                '"weaponType": "',
                weaponType,
                '", ',
                '"imageUrl": "',
                imageUrl,
                '", ',
                '"price": ',
                uint2str(price),
                ", ",
                '"rarity": "',
                rarity,
                '"}'
            )
        );

        return json;
    }

    function deleteCraftableItem(uint256 itemId) external onlyOwner {
        craftingContract.deleteCraftableItem(itemId);
    }

    function mint(uint256 craftableItemId, uint256 quantity)
        external
        onlyOwnerOrCreator
    {
        require(
            craftableItemId < craftingContract.totalCraftableItems(),
            "Invalid craftable item ID"
        );
        (
            string memory name,
            string memory description,
            uint256 damage,
            uint256 attackSpeed,
            uint256 durability,
            uint256 durabilityPerUse,
            string memory weaponType,
            string memory imageUrl,
            uint256 price,
            string memory rarity
        ) = craftingContract.craftableItems(craftableItemId);
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = tokenIdCounter++;
            items[tokenId] = Item(
                name,
                description,
                damage,
                attackSpeed,
                durability,
                durabilityPerUse,
                weaponType,
                imageUrl,
                price,
                rarity,
                false
            );
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, imageUrl);
            emit ItemCreated(tokenId, msg.sender);
        }
    }

    function mintWithWOB(uint256 quantity) external {
        uint256 priceWOB = priceToCreateNftWOB * quantity;

        require(
            WOB.balanceOf(msg.sender) >= priceWOB,
            "Insufficient WOB balance"
        );

        require(
            WOB.allowance(msg.sender, address(this)) >= priceWOB,
            "Insufficient allowance for WOB"
        );

        require(
            WOB.transferFrom(msg.sender, address(this), priceWOB),
            "Failed to transfer WOB"
        );

        for (uint256 i = 0; i < quantity; i++) {
            uint256 randomTokenId = uint256(
                keccak256(abi.encodePacked(block.timestamp, tokenIdCounter))
            );
            uint256 craftableItemId = randomTokenId %
                craftingContract.totalCraftableItems();
            (
                string memory name,
                string memory description,
                uint256 damage,
                uint256 attackSpeed,
                uint256 durability,
                uint256 durabilityPerUse,
                string memory weaponType,
                string memory imageUrl,
                uint256 price,
                string memory rarity
            ) = craftingContract.craftableItems(craftableItemId);

            uint256 tokenId = tokenIdCounter++;
            items[tokenId] = Item(
                name,
                description,
                damage,
                attackSpeed,
                durability,
                durabilityPerUse,
                weaponType,
                imageUrl,
                price,
                rarity,
                false
            );
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, imageUrl);
            emit ItemCreated(tokenId, msg.sender);
        }
    }

    function updateItemDurability(uint256 tokenId, uint256 durability)
        external
        onlyOwnerOrCreator
    {
        Item storage item = items[tokenId];
        require(item.isStaked, "Item is not in staked");
        item.durability = durability;
        emit ItemUpdated(tokenId, durability);
    }

    function setIsStakedTrue(uint256 tokenId) external onlyTokenOwner(tokenId) {
        Item storage item = items[tokenId];
        require(!item.isStaked, "Item is already in staked");
        item.isStaked = true;
        emit InBattleSet(tokenId, true);
    }

    function setIsStakedFalse(uint256 tokenId) external onlyOwnerOrCreator {
        Item storage item = items[tokenId];
        require(item.isStaked, "Item is not in staked");
        item.isStaked = false;
        emit InBattleSet(tokenId, false);
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
                '"description": "',
                items[tokenId].description,
                '", ',
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
                '"durabilityPerUse": ',
                uint2str(items[tokenId].durabilityPerUse),
                ", ",
                '"rarity": "',
                items[tokenId].rarity,
                '", ',
                '"weaponType": "',
                items[tokenId].weaponType,
                '"',
                "}, ",
                '"external_link": "https://worldofblast.com"'
                "}"
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

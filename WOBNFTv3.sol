// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

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
        bool isStaked;
    }

    struct CraftingItem {
        string name;
        string description;
        uint256 damage;
        uint256 attackSpeed;
        uint256 durability;
        uint256 durabilityPerUse;
        string weaponType;
        string imageUrl;
        uint256 price;
        uint256 weightProbability;
    }

    struct Crafting {
        CraftingItem[] craftableItems;
        mapping(uint256 => uint256) craftableItemIndex;
        uint256 totalCraftableItems;
    }

    Crafting private craftingContract;

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

    modifier onlyCreator() {
        require(creators[msg.sender], "Only owner or creator");
        _;
    }

    constructor() ERC721("World Of Blast", "WOBNFTs") Ownable(msg.sender) {
        WOB = IERC20(WOBTokenContract);
        _owner = payable(msg.sender);
        _contractURI = "https://worldofblast.com/assets/contract.json";
        creators[msg.sender] = true;
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
    }

    function removeCreator(address _creator) external onlyOwner {
        creators[_creator] = false;
    }

    function getAllCraftableItems()
        external
        view
        returns (CraftingItem[] memory)
    {
        return craftingContract.craftableItems;
    }

    function getCraftableItem(uint256 id)
        external
        view
        returns (string memory)
    {
        CraftingItem storage craftableItem = craftingContract.craftableItems[
            id
        ];
        string memory itemData = string(
            abi.encodePacked(
                craftableItem.name,
                ";",
                craftableItem.description,
                ";",
                uint2str(craftableItem.damage),
                ";",
                uint2str(craftableItem.attackSpeed),
                ";",
                uint2str(craftableItem.durability),
                ";",
                uint2str(craftableItem.durabilityPerUse),
                ";",
                craftableItem.weaponType,
                ";",
                craftableItem.imageUrl,
                ";",
                ";",
                uint2str(craftableItem.weightProbability)
            )
        );
        return itemData;
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
        uint256 weightProbability
    ) external onlyCreator {
        CraftingItem memory newItem = CraftingItem({
            name: name,
            description: description,
            damage: damage,
            attackSpeed: attackSpeed,
            durability: durability,
            durabilityPerUse: durabilityPerUse,
            weaponType: weaponType,
            imageUrl: imageUrl,
            price: price,
            weightProbability: weightProbability
        });
        craftingContract.craftableItems.push(newItem);
        craftingContract.craftableItemIndex[
            craftingContract.totalCraftableItems
        ] = craftingContract.craftableItems.length - 1;
        craftingContract.totalCraftableItems++;
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
        uint256 weightProbability
    ) external onlyCreator {
        require(
            itemId < craftingContract.totalCraftableItems,
            "Item ID out of range"
        );
        uint256 index = craftingContract.craftableItemIndex[itemId];
        CraftingItem storage craftableItem = craftingContract.craftableItems[
            index
        ];
        craftableItem.name = name;
        craftableItem.description = description;
        craftableItem.damage = damage;
        craftableItem.attackSpeed = attackSpeed;
        craftableItem.durability = durability;
        craftableItem.durabilityPerUse = durabilityPerUse;
        craftableItem.weaponType = weaponType;
        craftableItem.imageUrl = imageUrl;
        craftableItem.price = price;
        craftableItem.weightProbability = weightProbability;
    }

    function deleteCraftableItem(uint256 itemId) external onlyOwner {
        require(
            itemId < craftingContract.totalCraftableItems,
            "Item ID out of range"
        );
        uint256 indexToDelete = craftingContract.craftableItemIndex[itemId];
        delete craftingContract.craftableItems[indexToDelete];
    }

    function mint(uint256 craftableItemId, uint256 quantity)
        external
        onlyCreator
    {
        require(
            craftableItemId < craftingContract.totalCraftableItems,
            "Invalid craftable item ID"
        );
        CraftingItem memory craftableItem = craftingContract.craftableItems[
            craftableItemId
        ];
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = tokenIdCounter++;
            items[tokenId] = Item(
                craftableItem.name,
                craftableItem.description,
                craftableItem.damage,
                craftableItem.attackSpeed,
                craftableItem.durability,
                craftableItem.durabilityPerUse,
                craftableItem.weaponType,
                craftableItem.imageUrl,
                craftableItem.price,
                false
            );
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, craftableItem.imageUrl);
            emit ItemCreated(tokenId, msg.sender);
        }
    }

    function mintWithWOB(uint256 quantity) external returns (uint256[] memory) {
        uint256 priceWOB = priceToCreateNftWOB * quantity;
        require(
            WOB.balanceOf(msg.sender) >= priceWOB,
            "Insufficient WOB balance"
        );
        require(
            WOB.transferFrom(msg.sender, address(this), priceWOB),
            "Failed to transfer WOB"
        );

        require(
            craftingContract.totalCraftableItems > 0,
            "No craftable items available"
        );

        uint256 totalweightProbability = 0;
        for (uint256 x = 0; x < craftingContract.totalCraftableItems; x++) {
            totalweightProbability += craftingContract
                .craftableItems[x]
                .weightProbability;
        }

        uint256[] memory itemIds = new uint256[](quantity);
        uint256 cumulativeWeight = 0;

        for (uint256 i = 0; i < quantity; i++) {
            uint256 randomNumber = uint256(
                keccak256(abi.encodePacked(block.timestamp, tokenIdCounter, i))
            ) % totalweightProbability;

            uint256 selectedItemId;

            for (
                uint256 itemId = 0;
                itemId < craftingContract.totalCraftableItems;
                itemId++
            ) {
                cumulativeWeight += craftingContract
                    .craftableItems[itemId]
                    .weightProbability;
                if (randomNumber < cumulativeWeight) {
                    selectedItemId = itemId;
                    break;
                }
            }

            uint256 tokenId = tokenIdCounter++;
            CraftingItem memory selectedCraftableItem = craftingContract
                .craftableItems[selectedItemId];
            items[tokenId] = Item(
                selectedCraftableItem.name,
                selectedCraftableItem.description,
                selectedCraftableItem.damage,
                selectedCraftableItem.attackSpeed,
                selectedCraftableItem.durability,
                selectedCraftableItem.durabilityPerUse,
                selectedCraftableItem.weaponType,
                selectedCraftableItem.imageUrl,
                selectedCraftableItem.price,
                false
            );
            itemIds[i] = tokenId;
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, selectedCraftableItem.imageUrl);
            emit ItemCreated(tokenId, msg.sender);
        }
        return itemIds;
    }

    function updateItemDurability(uint256 tokenId, uint256 durability)
        external
        onlyCreator
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

    function setIsStakedFalse(uint256 tokenId) external onlyCreator {
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

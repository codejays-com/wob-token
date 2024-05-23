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
        uint256 id;
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
    uint256 private craftingItemIdCounter;
    string private _contractURI;

    mapping(uint256 => Item) private items;
    mapping(address => bool) public creators;
    mapping(address => mapping(uint256 => bool))
        private authorizedContractsByItem;

    event ItemCreated(uint256 indexed tokenId, address indexed owner);
    event ItemUpdated(uint256 indexed tokenId, uint256 durability);
    event InBattleSet(uint256 indexed tokenId, bool value);
    event AuthorizedContract(
        address indexed contractAddress,
        uint256 indexed tokenId,
        bool authorized
    );

    modifier onlyTokenOwner(uint256 tokenId) {
        require(
            ownerOf(tokenId) == msg.sender,
            "You are not the owner of this token"
        );
        _;
    }

    modifier onlyAuthorizedContract(uint256 tokenId) {
        require(
            authorizedContractsByItem[msg.sender][tokenId],
            "Not authorized to edit this item"
        );
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
        uint256 index = craftingContract.craftableItemIndex[id];
        CraftingItem storage craftableItem = craftingContract.craftableItems[
            index
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
    ) external {
        uint256 newItemId = craftingItemIdCounter++;
        CraftingItem memory newItem = CraftingItem({
            id: newItemId,
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
        craftingContract.craftableItemIndex[newItemId] =
            craftingContract.craftableItems.length -
            1;
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
    ) external {
        require(
            craftingContract.craftableItemIndex[itemId] <
                craftingContract.totalCraftableItems,
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
            craftingContract.craftableItemIndex[itemId] <
                craftingContract.totalCraftableItems,
            "Item ID out of range"
        );
        uint256 indexToDelete = craftingContract.craftableItemIndex[itemId];
        uint256 lastIndex = craftingContract.craftableItems.length - 1;

        if (indexToDelete != lastIndex) {
            CraftingItem storage lastItem = craftingContract.craftableItems[
                lastIndex
            ];
            craftingContract.craftableItems[indexToDelete] = lastItem;
            craftingContract.craftableItemIndex[lastItem.id] = indexToDelete;
        }

        craftingContract.craftableItems.pop();
        delete craftingContract.craftableItemIndex[itemId];
        craftingContract.totalCraftableItems--;
    }

    function mint(uint256 craftableItemId, uint256 quantity) external {
        require(
            craftingContract.craftableItemIndex[craftableItemId] <
                craftingContract.totalCraftableItems,
            "Invalid craftable item ID"
        );
        uint256 index = craftingContract.craftableItemIndex[craftableItemId];
        CraftingItem memory craftableItem = craftingContract.craftableItems[
            index
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
        CraftingItem[] memory craftableItems = craftingContract.craftableItems;
        uint256 totalItems = craftableItems.length;

        for (uint256 x = 0; x < totalItems; x++) {
            totalweightProbability += craftableItems[x].weightProbability;
        }

        uint256[] memory itemIds = new uint256[](quantity);
        uint256 cumulativeWeight;
        uint256 tokenId;
        uint256 randomNumber;

        for (uint256 i = 0; i < quantity; i++) {
            randomNumber =
                uint256(
                    keccak256(
                        abi.encodePacked(block.timestamp, tokenIdCounter, i)
                    )
                ) %
                totalweightProbability;
            cumulativeWeight = 0;

            uint256 selectedItemId;
            for (uint256 itemId = 0; itemId < totalItems; itemId++) {
                cumulativeWeight += craftableItems[itemId].weightProbability;
                if (randomNumber < cumulativeWeight) {
                    selectedItemId = itemId;
                    break;
                }
            }

            tokenId = tokenIdCounter++;
            CraftingItem memory selectedCraftableItem = craftableItems[
                selectedItemId
            ];
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

    function updateImage(uint256 tokenId, string memory imageUrl)
        external
        onlyOwner
    {
        _setTokenURI(tokenId, imageUrl);
        items[tokenId].imageUrl = imageUrl;
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

    function authorizeContract(
        address contractAddress,
        uint256 tokenId,
        bool authorized
    ) external {
        require(
            ownerOf(tokenId) == msg.sender,
            "Only the owner can authorize a contract"
        );
        require(!items[tokenId].isStaked, "Item staked");
        authorizedContractsByItem[contractAddress][tokenId] = authorized;
        emit AuthorizedContract(contractAddress, tokenId, authorized);
    }

    function updateDurability(uint256 tokenId, uint256 newDurability)
        external
        onlyAuthorizedContract(tokenId)
    {
        items[tokenId].durability = newDurability;
        emit ItemUpdated(tokenId, newDurability);
    }

    function setStakedStatus(uint256 tokenId, bool status)
        external
        onlyAuthorizedContract(tokenId)
    {
        items[tokenId].isStaked = status;
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

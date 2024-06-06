// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WorldOfBlastCrafting is Ownable {
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
        uint256 weightProbability;
    }

    struct Crafting {
        Item[] craftableItems;
        uint256 totalCraftableItems;
    }

    Crafting private craftingContract;

    mapping(uint256 => Item) public items;
    mapping(address => bool) public creators;

    event ItemCreated(uint256 indexed itemId, address indexed owner);
    event ItemUpdated(uint256 indexed itemId, uint256 durability);
    event ItemDeleted(uint256 indexed itemId);
    event CreatorAdded(address indexed creator);
    event CreatorRemoved(address indexed creator);

    modifier onlyCreator() {
        require(creators[msg.sender], "Only owner or creator");
        _;
    }

    constructor() Ownable(msg.sender) {
        creators[msg.sender] = true;
        emit CreatorAdded(msg.sender);
    }

    function addCreator(address _creator) external onlyOwner {
        creators[_creator] = true;
        emit CreatorAdded(_creator);
    }

    function removeCreator(address _creator) external onlyOwner {
        creators[_creator] = false;
        emit CreatorRemoved(_creator);
    }

    function getCraftableItem(uint256 id)
        external
        view
        returns (
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
        )
    {
        require(
            id < craftingContract.totalCraftableItems,
            "Item ID out of range"
        );
        Item storage craftableItem = craftingContract.craftableItems[id];
        return (
            craftableItem.name,
            craftableItem.description,
            craftableItem.damage,
            craftableItem.attackSpeed,
            craftableItem.durability,
            craftableItem.durabilityPerUse,
            craftableItem.weaponType,
            craftableItem.imageUrl,
            craftableItem.price,
            craftableItem.weightProbability
        );
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
    ) external payable onlyCreator {
        // Example of adding a fee for item creation (adjust fee amount as needed)
        require(msg.value >= 0.1 ether, "Insufficient fee");

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
            weightProbability: weightProbability
        });
        craftingContract.craftableItems.push(newItem);
        craftingContract.totalCraftableItems++;
        emit ItemCreated(craftingContract.totalCraftableItems - 1, msg.sender);
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
        Item storage craftableItem = craftingContract.craftableItems[itemId];
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
        emit ItemUpdated(itemId, durability);
    }

    function deleteCraftableItem(uint256 itemId) external onlyOwner {
        require(
            itemId < craftingContract.totalCraftableItems,
            "Item ID out of range"
        );
        uint256 lastIndex = craftingContract.craftableItems.length - 1;

        if (itemId != lastIndex) {
            craftingContract.craftableItems[itemId] = craftingContract
                .craftableItems[lastIndex];
        }

        craftingContract.craftableItems.pop();
        craftingContract.totalCraftableItems--;

        emit ItemDeleted(itemId);
    }

    function drawCraftableItem() public view returns (Item memory) {
        require(craftingContract.totalCraftableItems > 0, "No items available");

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < craftingContract.totalCraftableItems; i++) {
            totalWeight += craftingContract.craftableItems[i].weightProbability;
        }

        uint256 randomWeight = random(block.timestamp, totalWeight);

        uint256 cumulativeWeight = 0;
        for (uint256 i = 0; i < craftingContract.totalCraftableItems; i++) {
            cumulativeWeight += craftingContract
                .craftableItems[i]
                .weightProbability;
            if (randomWeight < cumulativeWeight) {
                return craftingContract.craftableItems[i];
            }
        }

        revert("No item selected");
    }

    function random(uint256 seed, uint256 limit)
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(seed))) % limit;
    }
}

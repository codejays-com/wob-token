// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract WorldOfBlastCrafting is Ownable {
    using SafeMath for uint256;

    struct Item {
        uint256 id;
        string name;
        string description;
        uint256 damage;
        uint256 attackSpeed;
        uint256 durability;
        uint256 durabilityPerUse;
        string weaponType;
        string imageUrl;
        uint256 weightProbability;
    }

    struct Crafting {
        uint256[] itemIds;
        uint256 totalCraftableItems;
    }

    Crafting private craftingContract;
    uint256 private nextItemId;

    mapping(uint256 => Item) private items;
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
        public
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
            uint256 weightProbability
        )
    {
        require(items[id].id != 0, "Item ID does not exist");
        Item storage craftableItem = items[id];
        return (
            craftableItem.name,
            craftableItem.description,
            craftableItem.damage,
            craftableItem.attackSpeed,
            craftableItem.durability,
            craftableItem.durabilityPerUse,
            craftableItem.weaponType,
            craftableItem.imageUrl,
            craftableItem.weightProbability
        );
    }

    function getTotalCraftableItems() public view returns (uint256) {
        return craftingContract.totalCraftableItems;
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
        uint256 weightProbability
    ) external payable onlyCreator {
        nextItemId++;
        Item memory newItem = Item({
            id: nextItemId,
            name: name,
            description: description,
            damage: damage,
            attackSpeed: attackSpeed,
            durability: durability,
            durabilityPerUse: durabilityPerUse,
            weaponType: weaponType,
            imageUrl: imageUrl,
            weightProbability: weightProbability
        });
        items[nextItemId] = newItem;
        craftingContract.itemIds.push(nextItemId);
        craftingContract.totalCraftableItems++;
        emit ItemCreated(nextItemId, msg.sender);
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
        uint256 weightProbability
    ) external onlyCreator {
        require(items[itemId].id != 0, "Item ID does not exist");
        Item storage craftableItem = items[itemId];
        craftableItem.name = name;
        craftableItem.description = description;
        craftableItem.damage = damage;
        craftableItem.attackSpeed = attackSpeed;
        craftableItem.durability = durability;
        craftableItem.durabilityPerUse = durabilityPerUse;
        craftableItem.weaponType = weaponType;
        craftableItem.imageUrl = imageUrl;
        craftableItem.weightProbability = weightProbability;
        emit ItemUpdated(itemId, durability);
    }

    function deleteCraftableItem(uint256 itemId) external onlyOwner {
        require(items[itemId].id != 0, "Item ID does not exist");

        delete items[itemId];
        for (uint256 i = 0; i < craftingContract.itemIds.length; i++) {
            if (craftingContract.itemIds[i] == itemId) {
                craftingContract.itemIds[i] = craftingContract.itemIds[
                    craftingContract.itemIds.length - 1
                ];
                craftingContract.itemIds.pop();
                break;
            }
        }

        craftingContract.totalCraftableItems--;
        emit ItemDeleted(itemId);
    }

    function drawCraftableItem()
        public
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
            uint256 weightProbability
        )
    {
        require(craftingContract.totalCraftableItems > 0, "No items available");

        uint256 totalWeight = 0;
        for (uint256 i = 0; i < craftingContract.itemIds.length; i++) {
            totalWeight += items[craftingContract.itemIds[i]].weightProbability;
        }

        uint256 randomWeight = random(block.timestamp, totalWeight);

        uint256 cumulativeWeight = 0;
        for (uint256 i = 0; i < craftingContract.itemIds.length; i++) {
            cumulativeWeight += items[craftingContract.itemIds[i]]
                .weightProbability;
            if (randomWeight < cumulativeWeight) {
                return getCraftableItem(craftingContract.itemIds[i]);
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

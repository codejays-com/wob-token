// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract WorldOfBlastCrafting is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

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
        string rarity;
    }

    struct Crafting {
        uint256[] itemIds;
        uint256 totalCraftableItems;
    }

    Crafting private craftingContract;
    uint256 public nextItemId;
    bool public isCreationRestricted;

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
        isCreationRestricted = true;
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

    function setCreationRestriction(bool _isRestricted) external onlyOwner {
        isCreationRestricted = _isRestricted;
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
            uint256 weightProbability,
            string memory rarity
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
            craftableItem.weightProbability,
            craftableItem.rarity
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
        uint256 weightProbability,
        string memory rarity
    ) external payable {
        if (isCreationRestricted) {
            require(
                creators[msg.sender],
                "Only owner or creator can create items"
            );
        }
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
            weightProbability: weightProbability,
            rarity: rarity
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
        uint256 weightProbability,
        string memory rarity
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
        craftableItem.rarity = rarity;
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

    function drawCraftableItem(uint256 nonce)
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
            uint256 weightProbability,
            string memory rarity
        )
    {
        require(craftingContract.totalCraftableItems > 0, "No items available");

        uint256 totalWeight = 0;

        for (uint256 i = 0; i < craftingContract.itemIds.length; i++) {
            totalWeight = totalWeight.add(
                items[craftingContract.itemIds[i]].weightProbability
            );
        }

        require(totalWeight > 0, "Total weight must be greater than zero");

        uint256 cumulativeWeight = 0;

        uint256 randomWeight = random(totalWeight, nonce);

        for (uint256 i = 0; i < craftingContract.itemIds.length; i++) {
            uint256 currentItemWeight = items[craftingContract.itemIds[i]]
                .weightProbability;

            cumulativeWeight = cumulativeWeight.add(currentItemWeight);

            if (randomWeight <= cumulativeWeight) {
                Item storage selectedItem = items[craftingContract.itemIds[i]];
                return (
                    selectedItem.name,
                    selectedItem.description,
                    selectedItem.damage,
                    selectedItem.attackSpeed,
                    selectedItem.durability,
                    selectedItem.durabilityPerUse,
                    selectedItem.weaponType,
                    selectedItem.imageUrl,
                    selectedItem.weightProbability,
                    selectedItem.rarity
                );
            }
        }

        revert("No item selected");
    }

    function random(uint256 limit, uint256 nonce)
        internal
        view
        returns (uint256)
    {
        uint256 randomIndex = uint256(
            keccak256(abi.encodePacked(block.timestamp, limit, nonce))
        ) % 99999999999999;
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        nonce,
                        randomIndex,
                        msg.sender
                    )
                )
            ) % limit;
    }

    function withdrawERC20(
        address _contract,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(IERC20(_contract).transfer(to, amount), "Failed to transfer");
    }
}
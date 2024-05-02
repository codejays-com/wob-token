// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IBlast {
    enum YieldMode {
        AUTOMATIC,
        VOID,
        CLAIMABLE
    }
    enum GasMode {
        VOID,
        CLAIMABLE
    }

    function configureContract(
        address contractAddress,
        YieldMode _yield,
        GasMode gasMode,
        address governor
    ) external;

    function configure(
        YieldMode _yield,
        GasMode gasMode,
        address governor
    ) external;

    function configureClaimableYield() external;

    function configureClaimableYieldOnBehalf(address contractAddress) external;

    function configureAutomaticYield() external;

    function configureAutomaticYieldOnBehalf(address contractAddress) external;

    function configureVoidYield() external;

    function configureVoidYieldOnBehalf(address contractAddress) external;

    function configureClaimableGas() external;

    function configureClaimableGasOnBehalf(address contractAddress) external;

    function configureVoidGas() external;

    function configureVoidGasOnBehalf(address contractAddress) external;

    function configureGovernor(address _governor) external;

    function configureGovernorOnBehalf(
        address _newGovernor,
        address contractAddress
    ) external;

    function claimYield(
        address contractAddress,
        address recipientOfYield,
        uint256 amount
    ) external returns (uint256);

    function claimAllYield(address contractAddress, address recipientOfYield)
        external
        returns (uint256);

    function claimAllGas(address contractAddress, address recipientOfGas)
        external
        returns (uint256);

    function claimGasAtMinClaimRate(
        address contractAddress,
        address recipientOfGas,
        uint256 minClaimRateBips
    ) external returns (uint256);

    function claimMaxGas(address contractAddress, address recipientOfGas)
        external
        returns (uint256);

    function claimGas(
        address contractAddress,
        address recipientOfGas,
        uint256 gasToClaim,
        uint256 gasSecondsToConsume
    ) external returns (uint256);

    function readClaimableYield(address contractAddress)
        external
        view
        returns (uint256);

    function readYieldConfiguration(address contractAddress)
        external
        view
        returns (uint8);

    function readGasParams(address contractAddress)
        external
        view
        returns (
            uint256 etherSeconds,
            uint256 etherBalance,
            uint256 lastUpdated,
            GasMode
        );
}

interface IBlastPoints {
    function configurePointsOperator(address operator) external;

    function configurePointsOperatorOnBehalf(
        address contractAddress,
        address operator
    ) external;
}

interface IERC20Rebasing {
    enum YieldMode {
        AUTOMATIC,
        VOID,
        CLAIMABLE
    }

    function configure(YieldMode) external returns (uint256);

    function claim(address recipient, uint256 amount)
        external
        returns (uint256);

    function getClaimableAmount(address account)
        external
        view
        returns (uint256);
}

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
        owner = msg.sender;
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
}

contract WorldOfBlastNft is ERC721URIStorage, Ownable {
    using SafeMath for uint256;
    Crafting public craftingContract;

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

    IERC20 private WOB;
    address private _operator;
    address payable public _owner;
    address public pointsOperator;

    address public constant WOBTokenContract =
        0x0BCAEec9dF553b0E59a0928FCCd9dcf8C0b42601;
    address public constant BLAST_CONTRACT =
        0x4300000000000000000000000000000000000002;
    address public constant blastPointsAddress =
        0x2fc95838c71e76ec69ff817983BFf17c710F34E0;
    IERC20Rebasing public constant USDB =
        IERC20Rebasing(0x4200000000000000000000000000000000000022);
    IERC20Rebasing public constant WETH =
        IERC20Rebasing(0x4200000000000000000000000000000000000023);

    uint256 public priceToCreateNftWOB;
    uint256 private tokenIdCounter;
    string private _contractURI;

    mapping(uint256 => Item) private items;
    mapping(address => bool) private creators;

    event ItemCreated(uint256 indexed tokenId, address indexed owner);
    event ItemUpdated(uint256 indexed tokenId, uint256 durability);
    event OperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );

    modifier onlyTokenOwner(uint256 tokenId) {
        require(
            ownerOf(tokenId) == msg.sender,
            "You are not the owner of this token"
        );
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == _owner, "Only the operator");
        _;
    }

    modifier onlyCreator() {
        require(
            creators[msg.sender],
            "Only authorized creator can perform this action"
        );
        _;
    }

    constructor() ERC721("World Of Blast", "WOBNFTs") Ownable(msg.sender) {
        WOB = IERC20(WOBTokenContract);
        _owner = payable(msg.sender);
        _operator = msg.sender;
        creators[msg.sender] = true;
        pointsOperator = msg.sender;
        _contractURI = "https://worldofblast.com/assets/contract.json";
        priceToCreateNftWOB = 10;
        IBlast(BLAST_CONTRACT).configureAutomaticYield();
        IBlast(BLAST_CONTRACT).configureClaimableYield();
        IBlast(BLAST_CONTRACT).configureClaimableGas();
        IBlast(BLAST_CONTRACT).configureGovernor(msg.sender);
        USDB.configure(IERC20Rebasing.YieldMode.CLAIMABLE);
        WETH.configure(IERC20Rebasing.YieldMode.CLAIMABLE);
        IBlastPoints(blastPointsAddress).configurePointsOperator(
            pointsOperator
        );

        craftingContract = new Crafting();
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function updateContractURI(string memory newContractURI)
        external
        onlyOwner
    {
        _contractURI = newContractURI;
    }

    function updatePriceToCreateNftWOB(uint256 price) external onlyOwner {
        priceToCreateNftWOB = price;
    }

    /*********************** BLAST ***********************/
    function setNewPointsOperator(address contractAddress, address newOperator)
        external
        onlyOwner
    {
        pointsOperator = newOperator;
        IBlastPoints(blastPointsAddress).configurePointsOperatorOnBehalf(
            contractAddress,
            newOperator
        );
    }

    function configureYieldModeTokens(
        IERC20Rebasing.YieldMode _weth,
        IERC20Rebasing.YieldMode _usdb
    ) external onlyOperator {
        USDB.configure(_usdb);
        WETH.configure(_weth);
    }

    function claimYieldTokens(address recipient, uint256 amount)
        external
        onlyOperator
    {
        USDB.claim(recipient, amount);
        WETH.claim(recipient, amount);
    }

    function claimYield(address recipient, uint256 amount)
        external
        onlyOperator
    {
        IBlast(BLAST_CONTRACT).claimYield(address(this), recipient, amount);
    }

    function claimAllYield(address recipient) external onlyOperator {
        IBlast(BLAST_CONTRACT).claimAllYield(address(this), recipient);
    }

    function configureGovernorOnBehalf(
        address _newGovernor,
        address contractAddress
    ) public onlyOwner {
        IBlast(BLAST_CONTRACT).configureGovernorOnBehalf(
            _newGovernor,
            contractAddress
        );
        emit OperatorTransferred(_operator, _newGovernor);
        _operator = _newGovernor;
    }

    function claimGasAtMinClaimRate(
        address contractAddress,
        address recipientOfGas,
        uint256 minClaimRateBips
    ) external onlyOwner returns (uint256) {
        return
            IBlast(BLAST_CONTRACT).claimGasAtMinClaimRate(
                contractAddress,
                recipientOfGas,
                minClaimRateBips
            );
    }

    function claimMaxGas(address contractAddress, address recipientOfGas)
        external
        onlyOwner
        returns (uint256)
    {
        return
            IBlast(BLAST_CONTRACT).claimMaxGas(contractAddress, recipientOfGas);
    }

    function claimGas(
        address contractAddress,
        address recipientOfGas,
        uint256 gasToClaim,
        uint256 gasSecondsToConsume
    ) external onlyOwner returns (uint256) {
        return
            IBlast(BLAST_CONTRACT).claimGas(
                contractAddress,
                recipientOfGas,
                gasToClaim,
                gasSecondsToConsume
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
        string memory rarity
    ) external onlyOwner {
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
    ) external onlyOwner {
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

    function addCreator(address _creator) external onlyOwner {
        creators[_creator] = true;
    }

    function removeCreator(address _creator) external onlyOwner {
        creators[_creator] = false;
    }

    function mint(uint256 craftableItemId, uint256 quantity)
        external
        onlyCreator
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
                rarity
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
                rarity
            );
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, imageUrl);
            emit ItemCreated(tokenId, msg.sender);
        }
    }

    function updateItemDurability(uint256 tokenId, uint256 newDurability)
        external
        onlyOwner
    {
        require(balanceOf(ownerOf(tokenId)) > 0, "Token ID does not exist");
        Item storage item = items[tokenId];
        item.durability = newDurability;
        emit ItemUpdated(tokenId, newDurability);
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

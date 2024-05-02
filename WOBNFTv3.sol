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

contract WorldOfBlast is ERC721URIStorage, Ownable {
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
    }

    struct CraftableItem {
        Item item;
    }

    CraftableItem[] public craftableItems;

    IERC20 private WOB;
    address private _operator;
    address payable public _owner;
    address public pointsOperator;
    address public constant WOBTokenContract =
        0x043F051534fA9Bd99a5DFC51807a45f4d2732021;
    address public constant BLAST_CONTRACT =
        0x4300000000000000000000000000000000000002;
    address public constant blastPointsAddress =
        0x2fc95838c71e76ec69ff817983BFf17c710F34E0;
    IERC20Rebasing public constant USDB =
        IERC20Rebasing(0x4200000000000000000000000000000000000022);
    IERC20Rebasing public constant WETH =
        IERC20Rebasing(0x4200000000000000000000000000000000000023);

    uint256 private priceToCreateNftWOB;
    uint256 private tokenIdCounter;
    string private _contractURI;

    mapping(uint256 => Item) private items;
    mapping(address => bool) private creators;

    event CraftableItemCreated(
        uint256 indexed itemId,
        CraftableItem craftableItem
    );
    event CraftableItemEdited(
        uint256 indexed itemId,
        CraftableItem craftableItem
    );
    event ItemCreated(uint256 indexed tokenId, address indexed owner);
    event ItemUpdated(uint256 indexed tokenId, uint256 durability);

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

    function getTotalCraftableItems() external view returns (uint256) {
        return craftableItems.length;
    }

    function getCraftableItem(uint256 _index)
        external
        view
        returns (string memory)
    {
        require(_index < craftableItems.length, "Index out of range");
        CraftableItem memory craftableItem = craftableItems[_index];
        string memory json = string(
            abi.encodePacked(
                '{"name": "',
                craftableItem.item.name,
                '", ',
                '"description": "',
                craftableItem.item.description,
                '", ',
                '"damage": ',
                uint2str(craftableItem.item.damage),
                ", ",
                '"attackSpeed": ',
                uint2str(craftableItem.item.attackSpeed),
                ", ",
                '"durability": ',
                uint2str(craftableItem.item.durability),
                ", ",
                '"durabilityPerUse": ',
                uint2str(craftableItem.item.durabilityPerUse),
                ", ",
                '"weaponType": "',
                craftableItem.item.weaponType,
                '", ',
                '"imageUrl": "',
                craftableItem.item.imageUrl,
                '", ',
                '"price": ',
                uint2str(craftableItem.item.price),
                ", ",
                '"rarity": "',
                craftableItem.item.rarity,
                '"',
                "}"
            )
        );

        return json;
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
        require(itemId < craftableItems.length, "Item ID out of range");
        CraftableItem storage craftableItem = craftableItems[itemId];
        craftableItem.item.name = name;
        craftableItem.item.description = description;
        craftableItem.item.damage = damage;
        craftableItem.item.attackSpeed = attackSpeed;
        craftableItem.item.durability = durability;
        craftableItem.item.durabilityPerUse = durabilityPerUse;
        craftableItem.item.weaponType = weaponType;
        craftableItem.item.imageUrl = imageUrl;
        craftableItem.item.price = price;
        craftableItem.item.rarity = rarity;
        emit CraftableItemEdited(itemId, craftableItem);
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
        Item memory newItem = Item(
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
        CraftableItem memory newCraftableItem = CraftableItem(newItem);
        craftableItems.push(newCraftableItem);
        emit CraftableItemCreated(craftableItems.length - 1, newCraftableItem);
    }

    function addCreator(address _creator) external onlyOwner {
        creators[_creator] = true;
    }

    function removeCreator(address _creator) external onlyOwner {
        creators[_creator] = false;
    }

    function Mint(uint256 craftableItemId, uint256 quantity)
        external
        onlyCreator
    {
        require(
            craftableItemId < craftableItems.length,
            "Invalid craftable item ID"
        );
        CraftableItem memory craftableItem = craftableItems[craftableItemId];
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = tokenIdCounter++;
            items[tokenId] = Item(
                craftableItem.item.name,
                craftableItem.item.description,
                craftableItem.item.damage,
                craftableItem.item.attackSpeed,
                craftableItem.item.durability,
                craftableItem.item.durabilityPerUse,
                craftableItem.item.weaponType,
                craftableItem.item.imageUrl,
                craftableItem.item.price,
                craftableItem.item.rarity
            );
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, craftableItem.item.imageUrl);
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
            uint256 craftableItemId = randomTokenId % craftableItems.length;
            CraftableItem memory craftableItem = craftableItems[
                craftableItemId
            ];
            uint256 tokenId = tokenIdCounter++;

            items[tokenId] = Item(
                craftableItem.item.name,
                craftableItem.item.description,
                craftableItem.item.damage,
                craftableItem.item.attackSpeed,
                craftableItem.item.durability,
                craftableItem.item.durabilityPerUse,
                craftableItem.item.weaponType,
                craftableItem.item.imageUrl,
                craftableItem.item.price,
                craftableItem.item.rarity
            );
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, craftableItem.item.imageUrl);
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

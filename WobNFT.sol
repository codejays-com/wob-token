//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IBlastPoints {
    function configurePointsOperator(address operator) external;

    function configurePointsOperatorOnBehalf(
        address contractAddress,
        address operator
    ) external;
}

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

    // configure
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

    // base configuration options
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

    // claim yield
    function claimYield(
        address contractAddress,
        address recipientOfYield,
        uint256 amount
    ) external returns (uint256);

    function claimAllYield(address contractAddress, address recipientOfYield)
        external
        returns (uint256);

    // claim gas
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

    // read functions
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

interface IERC20Rebasing {
    enum YieldMode {
        AUTOMATIC,
        VOID,
        CLAIMABLE
    }

    // changes the yield mode of the caller and update the balance
    // to reflect the configuration
    function configure(YieldMode) external returns (uint256);

    // "claimable" yield mode accounts can call this this claim their yield
    // to another address
    function claim(address recipient, uint256 amount)
        external
        returns (uint256);

    // read the claimable amount for an account
    function getClaimableAmount(address account)
        external
        view
        returns (uint256);
}

contract WorldOfBlast is ERC721URIStorage, Ownable {
    using SafeMath for uint256;

    address private _operator;
    address payable public _owner;
    address public pointsOperator;

    struct Item {
        string name;
        string description;
        uint256 damage;
        uint256 attackSpeed;
        uint256 durability;
        uint256 maxDurability;
        uint256 durabilityPerUse;
        string weaponType;
        string imageUrl;
        uint256 price;
    }

    IERC20 private WOB;
    uint256 private tokenIdCounter;
    string private _baseTokenURI;

    address public constant WOBTokenContract =
        0x71B54fd9F928FF10D5990f80D1E19c2BC866a821;

    address public constant BLAST_CONTRACT =
        0x4300000000000000000000000000000000000002;

    /*********************** BLAST MAINNET **********************
    address public constant blastPointsAddress =
    0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800;
    IERC20Rebasing public constant USDB =
    IERC20Rebasing(0x4300000000000000000000000000000000000003);
    IERC20Rebasing public constant WETH =
    IERC20Rebasing(0x4300000000000000000000000000000000000004);
    */

    /*********************** BLAST TESTNET ***********************/
    address public constant blastPointsAddress =
        0x2fc95838c71e76ec69ff817983BFf17c710F34E0;
    IERC20Rebasing public constant USDB =
        IERC20Rebasing(0x4200000000000000000000000000000000000022);
    IERC20Rebasing public constant WETH =
        IERC20Rebasing(0x4200000000000000000000000000000000000023);

    mapping(uint256 => Item) private items;
    mapping(uint256 => bool) private isForSale;
    mapping(uint256 => string) private tokenURIs;
    mapping(address => bool) private creators;

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

    event ItemUpdatedDescription(uint256 indexed tokenId, string description);

    event ItemUpdatedDurability(uint256 indexed tokenId, uint256 durability);

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

        IBlast(BLAST_CONTRACT).configureAutomaticYield();
        IBlast(BLAST_CONTRACT).configureClaimableYield();
        IBlast(BLAST_CONTRACT).configureClaimableGas();
        IBlast(BLAST_CONTRACT).configureGovernor(msg.sender);

        USDB.configure(IERC20Rebasing.YieldMode.CLAIMABLE);

        WETH.configure(IERC20Rebasing.YieldMode.CLAIMABLE);

        IBlastPoints(blastPointsAddress).configurePointsOperator(
            pointsOperator
        );

        emit OperatorTransferred(address(0), _operator);
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

    // claim gas start
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

    // read functions
    function readClaimableYield(address contractAddress)
        external
        view
        returns (uint256)
    {
        return IBlast(BLAST_CONTRACT).readClaimableYield(contractAddress);
    }

    function readYieldConfiguration(address contractAddress)
        external
        view
        returns (uint8)
    {
        return IBlast(BLAST_CONTRACT).readYieldConfiguration(contractAddress);
    }

    function Mint(
        string memory name,
        string memory description,
        uint256 damage,
        uint256 attackSpeed,
        uint256 durability,
        uint256 maxDurability,
        uint256 durabilityPerUse,
        string memory weaponType,
        string memory imageUrl,
        uint256 price,
        uint256 quantity
    ) external onlyCreator {
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = tokenIdCounter;
            tokenIdCounter++;
            items[tokenId] = Item(
                name,
                description,
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
        Item storage item = items[tokenId];
        item.imageUrl = newTokenURI;
        emit ItemUpdated(tokenId, ownerOf(tokenId));
    }

    function updateTokenDescription(uint256 tokenId, string memory description)
        external
        onlyOwner
    {
        require(balanceOf(ownerOf(tokenId)) > 0, "Token ID does not exist");
        items[tokenId].description = description;
        emit ItemUpdatedDescription(tokenId, description);
    }

    function updateItemDurability(uint256 tokenId, uint256 newDurability)
        external
        onlyOwner
    {
        require(balanceOf(ownerOf(tokenId)) > 0, "Token ID does not exist");
        Item storage item = items[tokenId];
        item.durability = newDurability;
        emit ItemUpdatedDurability(tokenId, newDurability);
    }

    function getItem(uint256 tokenId)
        external
        view
        returns (
            string memory name,
            string memory description,
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
            item.description,
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
                '"description":items[tokenId].description, ',
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

    function addCreator(address _creator) external onlyOwner {
        creators[_creator] = true;
    }

    function removeCreator(address _creator) external onlyOwner {
        creators[_creator] = false;
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

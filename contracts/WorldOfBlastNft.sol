// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWorldOfBlastCrafting {
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
            uint256 weightProbability,
            string memory rarity
        );

    function drawCraftableItem(uint256 x)
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
            uint256 weightProbability,
            string memory rarity
        );
}

contract WorldOfBlastNft is ERC721Enumerable, ERC721URIStorage, Ownable {
    using SafeMath for uint256;

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
        bool isStaked;
        string rarity;
    }

    IERC20 public WOB;

    IWorldOfBlastCrafting public craftingContract;

    address payable public _owner;
    address public _addressSendWOB;
    address public _addressRestore;

    uint256 public priceToCreateNftWOB;
    uint256 public tokenIdCounter;
    string public _contractURI;

    mapping(uint256 => Item) private items;
    mapping(address => bool) public creators;
    mapping(address => mapping(uint256 => bool))
        public authorizedContractsByItem;

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

    modifier onlyCreator() {
        require(creators[msg.sender], "Only owner or creator");
        _;
    }

    modifier notStaked(uint256 tokenId) {
        require(!items[tokenId].isStaked, "Item is currently staked");
        _;
    }

    modifier onlyAuthorizedContract(uint256 tokenId) {
        require(
            authorizedContractsByItem[msg.sender][tokenId],
            "Not authorized to edit this item"
        );
        _;
    }

    modifier onlyRestore() {
        require(msg.sender == _addressRestore, "Only restorer");
        _;
    }

    constructor() ERC721("World Of Blast", "WOBNFTs") Ownable(msg.sender) {
        WOB = IERC20(0x0BCAEec9dF553b0E59a0928FCCd9dcf8C0b42601);

        craftingContract = IWorldOfBlastCrafting(
            0x231513051614d27203d7f58F11e4BeDa40F8d9aB
        );

        _owner = payable(msg.sender);
        _contractURI = "https://worldofblast.com/assets/contract.json";
        creators[msg.sender] = true;
        _addressRestore = msg.sender;
        _addressSendWOB = address(this);
    }

    function withdrawERC20(
        address _contract,
        address to,
        uint256 amount
    ) external onlyOwner {
        require(IERC20(_contract).transfer(to, amount), "Failed to transfer");
    }

    function updateWOBAddress(address _newWobAddress) external onlyOwner {
        WOB = IERC20(_newWobAddress);
    }

    function updateCraftingContractAddress(address _newCraftingAddress)
        external
        onlyOwner
    {
        require(_newCraftingAddress != address(0), "Invalid address");
        craftingContract = IWorldOfBlastCrafting(_newCraftingAddress);
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function updateAddressSendWOB(address _address) external onlyOwner {
        _addressSendWOB = _address;
    }

    function updateContractRestore(address _address) external onlyOwner {
        _addressRestore = _address;
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

    function mint(uint256 craftableItemId, uint256 quantity)
        external
        onlyCreator
    {
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = tokenIdCounter++;

            (
                string memory name,
                string memory description,
                uint256 damage,
                uint256 attackSpeed,
                uint256 durability,
                uint256 durabilityPerUse,
                string memory weaponType,
                string memory imageUrl,
                ,
                string memory rarity
            ) = craftingContract.getCraftableItem(craftableItemId);
            items[tokenId] = Item(
                name,
                description,
                damage,
                attackSpeed,
                durability,
                durability,
                durabilityPerUse,
                weaponType,
                imageUrl,
                false,
                rarity
            );
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, imageUrl);
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
            WOB.transferFrom(msg.sender, _addressSendWOB, priceWOB),
            "Failed to transfer WOB"
        );

        uint256[] memory itemIds = new uint256[](quantity);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = tokenIdCounter++;

            (
                string memory name,
                string memory description,
                uint256 damage,
                uint256 attackSpeed,
                uint256 durability,
                uint256 durabilityPerUse,
                string memory weaponType,
                string memory imageUrl,
                ,
                string memory rarity
            ) = craftingContract.drawCraftableItem(tokenId);

            items[tokenId] = Item(
                name,
                description,
                damage,
                attackSpeed,
                durability,
                durability,
                durabilityPerUse,
                weaponType,
                imageUrl,
                false,
                rarity
            );
            itemIds[i] = tokenId;
            _safeMint(msg.sender, tokenId);
            _setTokenURI(tokenId, imageUrl);
            emit ItemCreated(tokenId, msg.sender);
        }
        return itemIds;
    }

    function updateImage(uint256 tokenId, string memory imageUrl)
        external
        onlyCreator
    {
        _setTokenURI(tokenId, imageUrl);
        items[tokenId].imageUrl = imageUrl;
    }

    function authorizeContract(
        address contractAddress,
        uint256 tokenId,
        bool authorized
    ) external notStaked(tokenId) {
        require(
            ownerOf(tokenId) == msg.sender,
            "Only the owner can authorize a contract"
        );

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

    function restoreNFT(uint256 tokenId) external onlyRestore {
        items[tokenId].durability = items[tokenId].maxDurability;
        emit ItemUpdated(tokenId, items[tokenId].maxDurability);
    }

    function setStakedStatus(uint256 tokenId, bool status)
        external
        onlyAuthorizedContract(tokenId)
    {
        items[tokenId].isStaked = status;
    }

    function transferItem(address to, uint256 tokenId)
        external
        onlyTokenOwner(tokenId)
        notStaked(tokenId)
    {
        _transfer(msg.sender, to, tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
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
                '", ',
                '"rarity": "',
                items[tokenId].rarity,
                '"',
                "}, ",
                '"external_link": "https://worldofblast.com"'
                "}"
            )
        );

        return string(abi.encodePacked(baseURI, json));
    }

    function getItemDetails(uint256 tokenId)
        external
        view
        returns (
            string memory name,
            string memory description,
            uint256 damage,
            uint256 attackSpeed,
            uint256 durability,
            uint256 durabilityPerUse,
            uint256 maxDurability,
            string memory weaponType,
            string memory imageUrl,
            string memory rarity
        )
    {
        Item storage item = items[tokenId];
        return (
            item.name,
            item.description,
            item.damage,
            item.attackSpeed,
            item.durability,
            item.durabilityPerUse,
            item.maxDurability,
            item.weaponType,
            item.imageUrl,
            item.rarity
        );
    }

    function tokensOfOwner(address owner)
        external
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(owner);
        uint256[] memory result = new uint256[](tokenCount);
        uint256 resultIndex = 0;
        for (uint256 tokenId = 0; tokenId < tokenIdCounter; tokenId++) {
            if (ownerOf(tokenId) == owner) {
                result[resultIndex] = tokenId;
                resultIndex++;
            }
        }
        return result;
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

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Enumerable, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

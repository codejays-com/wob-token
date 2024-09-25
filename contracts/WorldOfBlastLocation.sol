// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WorldOfBlastLocation is ERC721URIStorage, Ownable {
    using SafeMath for uint256;

    struct Monster {
        uint256 id;
        string name;
        string img;
        uint256 hp;
        uint256 weight;
        uint256 damage;
    }

    string private _contractURI;
    IERC20 private CONTRACT_ERC20;

    mapping(uint256 => Monster) public monsters;
    uint256 private monsterIdCounter = 1;

    event MonsterMinted(
        address indexed owner,
        uint256 indexed tokenId,
        string name,
        string img,
        uint256 hp,
        uint256 weight,
        uint256 damage
    );

    constructor(
        string memory _name,
        string memory _code,
        uint256 _id
    ) ERC721(_name, _code) Ownable(msg.sender) {
        _contractURI = string(
            abi.encodePacked(
                "https://worldofblast.com/assets/locations/",
                uint2str(_id),
                ".json"
            )
        );
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function mintMonster(
        string memory _name,
        string memory _img,
        uint256 _hp,
        uint256 _weight,
        uint256 _damage
    ) external onlyOwner {
        uint256 monsterId = monsterIdCounter++;
        _safeMint(msg.sender, monsterId);
        _setTokenURI(monsterId, _img);
        monsters[monsterId] = Monster(
            monsterId,
            _name,
            _img,
            _hp,
            _weight,
            _damage
        );
        emit MonsterMinted(
            msg.sender,
            monsterId,
            _name,
            _img,
            _hp,
            _weight,
            _damage
        );
    }

    function getAllMonsters() public view returns (Monster[] memory) {
        uint256 totalMonsters = monsterIdCounter - 1;
        Monster[] memory allMonsters = new Monster[](totalMonsters);
        for (uint256 i = 1; i <= totalMonsters; i++) {
            allMonsters[i - 1] = monsters[i];
        }
        return allMonsters;
    }

    function random(uint256 seed, uint256 max) internal view returns (uint256) {
        return
            uint256(keccak256(abi.encodePacked(block.timestamp, seed))) % max;
    }

    function drawMonster() public view returns (Monster memory) {
        require(monsterIdCounter > 1, "No monsters available");
        uint256 totalWeight = 0;
        for (uint256 i = 1; i < monsterIdCounter; i++) {
            totalWeight = totalWeight.add(monsters[i].weight);
        }
        uint256 randomWeight = random(block.timestamp, totalWeight);

        uint256 cumulativeWeight = 0;
        for (uint256 i = 1; i < monsterIdCounter; i++) {
            cumulativeWeight = cumulativeWeight.add(monsters[i].weight);
            if (randomWeight < cumulativeWeight) {
                return monsters[i];
            }
        }

        revert("No monster selected");
    }

    function updateImage(uint256 tokenId, string memory imageUrl)
        external
        onlyOwner
    {
        _setTokenURI(tokenId, imageUrl);
        monsters[tokenId].img = imageUrl;
    }

    function updateWeight(uint256 tokenId, uint256 weight) external onlyOwner {
        monsters[tokenId].weight = weight;
    }

    function updateHp(uint256 tokenId, uint256 hp) external onlyOwner {
        monsters[tokenId].hp = hp;
    }

    function updateDamage(uint256 tokenId, uint256 damage) external onlyOwner {
        monsters[tokenId].damage = damage;
    }

    function updateName(uint256 tokenId, string memory name)
        external
        onlyOwner
    {
        monsters[tokenId].name = name;
    }

    function getMonsterDetails(uint256 tokenId)
        public
        view
        returns (
            uint256 id,
            string memory name,
            string memory img,
            uint256 hp,
            uint256 weight,
            uint256 damage
        )
    {
        Monster memory monster = monsters[tokenId];
        return (
            monster.id,
            monster.name,
            monster.img,
            monster.hp,
            monster.weight,
            monster.damage
        );
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        string memory baseURI = _baseURI();
        Monster memory monster = monsters[tokenId];
        string memory json = string(
            abi.encodePacked(
                '{"name": "',
                monster.name,
                '", ',
                '"image": "',
                monster.img,
                '", ',
                '"attributes": {',
                '"hp": ',
                uint2str(monster.hp),
                ", ",
                '"weight": ',
                uint2str(monster.weight),
                ", ",
                '"damage": ',
                uint2str(monster.damage),
                "}",
                ", ",
                '"external_link": "https://worldofblast.com"'
                "}"
            )
        );
        return string(abi.encodePacked(baseURI, json));
    }

    function withdrawERC20(
        address _contract,
        address to,
        uint256 amount
    ) external onlyOwner {
        CONTRACT_ERC20 = IERC20(_contract);
        require(CONTRACT_ERC20.transfer(to, amount), "Failed to transfer");
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

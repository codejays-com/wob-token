// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract GameWob is ReentrancyGuard {
    IERC721 public nftContract;

    struct Monster {
        uint256 id;
        string name;
        string img;
        uint256 weight;
    }

    struct Location {
        uint256 id;
        string name;
        string img;
        uint256[] monsters;
    }

    mapping(uint256 => Location) public locations;
    mapping(uint256 => Monster) public monsters;

    uint256 private locationIdCounter = 1;
    uint256 private monsterIdCounter = 1;

    mapping(address => bool) public creators;

    modifier onlyCreators() {
        require(creators[msg.sender], "Only owner or creator");
        _;
    }

    constructor(address _nftContractAddress) {
        nftContract = IERC721(_nftContractAddress);
    }

    function addLocation(string memory _locationName, string memory _img)
        external
        onlyCreators
    {
        locationIdCounter++;
        locations[locationIdCounter] = Location(
            locationIdCounter,
            _locationName,
            _img,
            new uint256[](0)
        );
    }

    function addMonster(
        string memory _monsterName,
        uint256 _weight,
        string memory _img
    ) external onlyCreators {
        monsterIdCounter++;
        monsters[monsterIdCounter] = Monster(
            monsterIdCounter,
            _monsterName,
            _img,
            _weight
        );
    }

    function addMonsterToLocation(uint256 _locationId, uint256 _monsterId)
        external
        onlyCreators
    {
        require(locations[_locationId].id != 0, "Location does not exist");
        require(monsters[_monsterId].id != 0, "Monster does not exist");
        locations[_locationId].monsters.push(_monsterId);
    }

    function getLocation(uint256 _locationId)
        external
        view
        returns (
            uint256 id,
            string memory name,
            string memory img
        )
    {
        Location storage location = locations[_locationId];
        return (location.id, location.name, location.img);
    }

    function getMonster(uint256 _monsterId)
        external
        view
        returns (
            uint256 id,
            string memory name,
            string memory img,
            uint256 weight
        )
    {
        Monster storage monster = monsters[_monsterId];
        return (monster.id, monster.name, monster.img, monster.weight);
    }

    function getMonstersInLocation(uint256 _locationId)
        external
        view
        returns (uint256[] memory)
    {
        return locations[_locationId].monsters;
    }

    

    function hunt(uint256 _locationId) external nonReentrant {
        require(locations[_locationId].id != 0, "Location does not exist");
        require(
            locations[_locationId].monsters.length > 0,
            "No monsters in this location"
        );
    }
}

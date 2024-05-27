// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IMonsterContract {
    struct Monster {
        uint256 id;
        string name;
        uint256 weight;
    }

    function drawMonster() external view returns (Monster memory);
}

interface IExtendedERC721 is IERC721 {
    function authorizeContract(
        address contractAddress,
        uint256 tokenId,
        bool authorized
    ) external;
}

contract WorldOfBlastGame {
    using SafeMath for uint256;

    address[] public locations;
    IExtendedERC721 public nftContract;

    struct Hunt {
        uint256 id;
        address hunter;
        address location;
        uint256 weapon;
        uint256 startTime;
        uint256 endTime;
        IMonsterContract.Monster monster;
    }

    uint256 public huntCount;

    mapping(address => uint256) public huntStartTimes;

    mapping(uint256 => Hunt) public hunts;

    event HuntHasBegun(address hunter, address location, uint256 weapon);

    constructor() {}

    function addLocation(address _monsterContractAddress) public {
        locations.push(_monsterContractAddress);
    }

    function removeLocation(uint256 index) public {
        require(index < locations.length, "Invalid index");
        locations[index] = locations[locations.length - 1];
        locations.pop();
    }

    function setNFTContract(address _nftContractAddress) public {
        nftContract = IExtendedERC721(_nftContractAddress);
    }

    function startHunt(uint256 locationId, uint256 nftId)
        public
        returns (uint256)
    {
        require(locationId < locations.length, "Invalid location ID");
        require(
            nftContract.ownerOf(nftId) == msg.sender,
            "Not the owner of the NFT"
        );

        require(huntStartTimes[msg.sender] == 0, "Hunt already started");

        address _location = locations[locationId];

        IMonsterContract monsterContract = IMonsterContract(_location);

        IMonsterContract.Monster memory monster = monsterContract.drawMonster();

        Hunt memory newHunt = Hunt({
            id: huntCount,
            hunter: msg.sender,
            location: _location,
            weapon: nftId,
            startTime: block.timestamp,
            endTime: 0,
            monster: monster
        });

        hunts[huntCount] = newHunt;

        huntStartTimes[msg.sender] = block.timestamp;

        huntCount++;

        emit HuntHasBegun(msg.sender, _location, nftId);

        return huntCount - 1;
    }

    function endHunt(uint256 huntId) public {
        require(huntId < huntCount, "Invalid hunt ID");
        require(
            hunts[huntId].hunter == msg.sender,
            "Not the hunter of this hunt"
        );
        require(hunts[huntId].endTime == 0, "Hunt already ended");
        hunts[huntId].endTime = block.timestamp;
        huntStartTimes[msg.sender] = 0;
    }
}

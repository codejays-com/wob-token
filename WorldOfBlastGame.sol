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
    function authorizeContract( address contractAddress, uint256 tokenId, bool authorized) external;
    function getItemDetails(uint256 tokenId) external view returns (
            string memory name,
            string memory description,
            uint256 damage,
            uint256 attackSpeed,
            uint256 durability,
            uint256 durabilityPerUse,
            string memory weaponType,
            string memory imageUrl
        );
    function updateDurability(uint256 tokenId, uint256 newDurability) external;
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


    function handleGameTotalHits(uint256 attackSpeed, uint256 startTime, uint256 endTime) internal pure returns (uint256) {
        require(startTime < endTime, "Start time must be before end time");
        uint256 duration = endTime - startTime;
        uint256 totalHits = duration / (60 * attackSpeed); // 600 seconds = 10 minutes
        return totalHits;
    }

    function handleCharacterBattle(uint256 attackSpeed, uint256 durability, uint256 startTime, uint256 endTime, uint256 monsterWeight) view internal returns (uint) {
        uint256 totalHitsQuantity = handleGameTotalHits(attackSpeed, startTime, endTime);
        uint256 monsterAttack = monsterWeight;
        uint128 baseCharacterDesense = 5;

        for (uint128 index = 0; index < totalHitsQuantity; index++) {
            uint256 atackCalculation = monsterAttack - baseCharacterDesense;
            uint256 randomHash = uint256(
                keccak256(
                    abi.encodePacked(block.timestamp, index, block.difficulty, msg.sender)
                )
            );

            uint128 currentDamage = uint128(randomHash % atackCalculation);
            if (durability - currentDamage < 0) {
                durability = 0;
                break;
            } else {
                durability -= currentDamage;
            }     
        }

        return durability;
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

        ( 
            /* string memory name */,
            /* string memory description */,
            /* uint256 damage */,
            uint256 attackSpeed,
            uint256 durability,
            /* uint256 durabilityPerUse */,
            /* string memory weaponType */,
            /* string memory imageUrl */
        ) = nftContract.getItemDetails(hunts[huntId].weapon); // parse tehe data to take the durability

        uint256 currentDurability = handleCharacterBattle(attackSpeed, durability, hunts[huntId].startTime, hunts[huntId].endTime, hunts[huntId].monster.weight);
        nftContract.updateDurability(hunts[huntId].weapon, currentDurability);
    }
}

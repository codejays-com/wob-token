// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

enum YieldMode {
    AUTOMATIC,
    VOID,
    CLAIMABLE
}
enum GasMode {
    VOID,
    CLAIMABLE
}

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
            string memory imageUrl
        );

    function updateDurability(uint256 tokenId, uint256 newDurability) external;

    function setStakedStatus(uint256 tokenId, bool status) external;
}

interface WorldOfBlastDrop {
    function handleTokenEarnings(address to, uint256 total)
        external
        returns (uint256);

    function handleNFTEarnings(address to) external;
}

contract WorldOfBlastGame is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IExtendedERC721 public NFTContract;

    struct Hunt {
        uint256 id;
        address hunter;
        address location;
        uint256 weapon;
        uint256 startTime;
        uint256 endTime;
        IMonsterContract.Monster monster;
    }

    struct WeaponToken {
        uint256 damage;
        uint256 attackSpeed;
        uint256 durability;
        uint256 durabilityPerUse;
    }

    address[] public locations;
    uint256 public huntCount = 0;
    address public _operator;

    mapping(address => uint256) public huntStartTimes;
    mapping(address => uint256) public activeHuntId;

    mapping(uint256 => Hunt) public hunts;

    event HuntHasBegun(
        uint256 indexed huntId,
        uint256 startTime,
        uint256 weapon,
        address hunter,
        address location,
        string monster
    );

    event HuntEnd(
        uint256 indexed huntId,
        uint256 startTime,
        uint256 endTime,
        uint256 hitCounter,
        uint256 durability
    );

    event updateNFTContract(address _contract);
    event updateDropContract(address _contract);

    address public contractDropAddress;

    constructor() Ownable(msg.sender) {
        _operator = msg.sender;

        NFTContract = IExtendedERC721(
            0x0B854b221858F4269ae04704a891e12265BBa13C
        );
    }

    function getActiveHuntDetails(address userAddress)
        public
        view
        returns (
            uint256 huntId,
            address location,
            uint256 weapon,
            uint256 startTime,
            uint256 endTime,
            string memory monsterName,
            uint256 monsterWeight
        )
    {
        for (uint256 i = 1; i <= huntCount; i++) {
            if (hunts[i].hunter == userAddress && hunts[i].endTime == 0) {
                Hunt memory activeHunt = hunts[i];
                return (
                    activeHunt.id,
                    activeHunt.location,
                    activeHunt.weapon,
                    activeHunt.startTime,
                    activeHunt.endTime,
                    activeHunt.monster.name,
                    activeHunt.monster.weight
                );
            }
        }

        revert("No active hunt found for this user");
    }

    function setNFTContract(address _nftContractAddress) public onlyOwner {
        NFTContract = IExtendedERC721(_nftContractAddress);
        emit updateNFTContract(_nftContractAddress);
    }

    function setContractDropAddress(address _contractDropAddress)
        external
        onlyOwner
    {
        contractDropAddress = _contractDropAddress;
        emit updateDropContract(_contractDropAddress);
    }

    function startHunt(address _location, uint256 nftId)
        public
        returns (uint256)
    {
        require(
            NFTContract.ownerOf(nftId) == msg.sender,
            "Not the owner of the NFT"
        );

        require(huntStartTimes[msg.sender] == 0, "Hunt already started");

        NFTContract.setStakedStatus(nftId, true);

        IMonsterContract monsterContract = IMonsterContract(_location);

        IMonsterContract.Monster memory monster = monsterContract.drawMonster();

        huntCount++;

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

        activeHuntId[msg.sender] = huntCount;

        huntStartTimes[msg.sender] = block.timestamp;

        emit HuntHasBegun(
            huntCount,
            newHunt.startTime,
            nftId,
            msg.sender,
            _location,
            monster.name
        );

        return huntCount;
    }

    function handleGameTotalHits(
        uint256 attackSpeed,
        uint256 startTime,
        uint256 endTime
    ) public pure returns (uint256) {
        require(startTime < endTime, "Start time must be before end time");
        uint256 duration = (endTime - startTime);
        uint256 totalHits = (duration * attackSpeed);
        return totalHits;
    }

    function getWeaponToken(uint256 huntId)
        public
        view
        returns (WeaponToken memory)
    {
        uint256 weaponTokenId = hunts[huntId].weapon;

        (
            ,
            ,
            uint256 damage,
            uint256 attackSpeed,
            uint256 durability,
            uint256 durabilityPerUse,
            ,
            ,

        ) = NFTContract.getItemDetails(weaponTokenId);

        WeaponToken memory weaponToken = WeaponToken({
            damage: damage,
            attackSpeed: attackSpeed,
            durability: durability,
            durabilityPerUse: durabilityPerUse
        });

        return weaponToken;
    }

    function handleCharacterBattle(
        uint256 attackSpeed,
        uint256 durability,
        uint256 durabilityPerUse,
        uint256 startTime,
        uint256 endTime
    ) internal pure returns (uint256, uint256) {
        uint256 totalHitsQuantity = handleGameTotalHits(
            attackSpeed,
            startTime,
            endTime
        );

        uint256 maxHitsBeforeBroke = durability / durabilityPerUse;

        uint256 hitsBeforeBroke = totalHitsQuantity > maxHitsBeforeBroke
            ? maxHitsBeforeBroke
            : totalHitsQuantity;

        durability -= hitsBeforeBroke * durabilityPerUse;

        return (durability, hitsBeforeBroke);
    }

    function endHunt(uint256 huntId) public {
        require(
            hunts[huntId].hunter == msg.sender,
            "Not the hunter of this hunt"
        );
        require(hunts[huntId].endTime == 0, "Hunt already ended");

        hunts[huntId].endTime = block.timestamp;
        huntStartTimes[msg.sender] = 0;
        activeHuntId[msg.sender] = 0;

        WeaponToken memory weaponToken = getWeaponToken(huntId);

        uint256 attackSpeed = weaponToken.attackSpeed;
        uint256 durability = weaponToken.durability;
        uint256 durabilityPerUse = weaponToken.durabilityPerUse;
        uint256 damage = weaponToken.damage;

        (uint256 currentDurability, uint256 hitCounter) = handleCharacterBattle(
            attackSpeed,
            durability,
            durabilityPerUse,
            hunts[huntId].startTime,
            hunts[huntId].endTime
        );

        emit HuntEnd(
            huntId,
            hunts[huntId].startTime,
            hunts[huntId].endTime,
            hitCounter,
            currentDurability
        );

        NFTContract.updateDurability(hunts[huntId].weapon, currentDurability);
        NFTContract.setStakedStatus(hunts[huntId].weapon, false);

        WorldOfBlastDrop worldOfBlastDrop = WorldOfBlastDrop(
            contractDropAddress
        );

        uint256 timeSg = (hunts[huntId].endTime - hunts[huntId].startTime);
        uint256 totalDamage = (timeSg * attackSpeed * damage);
        worldOfBlastDrop.handleTokenEarnings(msg.sender, totalDamage);
        
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IBlast.sol";

/**
    Game contract will get Drop Contract Address from the location instead of only 1 drop contract
**/

interface IMonsterContract {
    struct Monster {
        uint256 id;
        string name;
        uint256 weight;
    }

    function drawMonster() external view returns (Monster memory);
}

interface WorldOfBlastLocation {
    function getDropContractAddress() external view returns (address);
}

interface IExtendedERC721 is IERC721 {
    function authorizeContract(
        address contractAddress,
        uint256 tokenId,
        bool authorized
    ) external;

    function getItemDetails(
        uint256 tokenId
    )
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
    function handleEarnings(
        address _address,
        uint256 damage,
        bytes32 randomBytes
    ) external returns (bytes memory);
}

contract WorldOfBlastGame is Ownable, ReentrancyGuard {
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
        address nftContract;
    }

    struct WeaponToken {
        uint256 damage;
        uint256 attackSpeed;
        uint256 durability;
        uint256 durabilityPerUse;
    }

    IBlast public constant BLAST =
        IBlast(0x4300000000000000000000000000000000000002);

    address[] public locations;
    uint256 public huntCount = 0;

    mapping(address => uint256) public huntStartTimes;
    mapping(address => uint256) public activeHuntId;
    mapping(address => bool) public authorizedNFTContracts;
    mapping(address => mapping(uint256 => bool)) public nftInHunt;
    mapping(uint256 => bytes32) private huntEntropy;
    mapping(uint256 => bool) private huntResolved;

    mapping(uint256 => Hunt) public hunts;

    event HuntHasBegun(
        uint256 indexed huntId,
        uint256 startTime,
        address indexed nftContract,
        uint256 indexed weapon,
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

    event EntropyRequested(uint256 sequenceNumber);
    event EntropyResult(uint256 sequenceNumber, bytes32 randomNumber);

    bool public paused;

    address private rngAdmin;

    modifier onlyRngAdmin() {
        require(msg.sender == rngAdmin, "Only the rngAdmin can call this");
        _;
    }

    constructor() Ownable(msg.sender) {
        paused = false;
        BLAST.configureClaimableGas();
    }

    // Blast functions
    function claimAllGas() external onlyOwner {
        BLAST.claimAllGas(address(this), msg.sender);
    }
    function claimGasAtMinClaimRate(
        address recipientOfGas,
        uint256 minClaimRateBips
    ) external onlyOwner {
        BLAST.claimGasAtMinClaimRate(
            address(this),
            recipientOfGas,
            minClaimRateBips
        );
    }
    function claimGas(
        address recipientOfGas,
        uint256 gasToClaim,
        uint256 gasSecondsToConsume
    ) external onlyOwner {
        BLAST.claimGas(
            address(this),
            recipientOfGas,
            gasToClaim,
            gasSecondsToConsume
        );
    }
    function readGasParams()
        external
        view
        returns (
            uint256 etherSeconds,
            uint256 etherBalance,
            uint256 lastUpdated,
            GasMode
        )
    {
        return BLAST.readGasParams(address(this));
    }
    function configureClaimableGasOnBehalf() external onlyOwner {
        BLAST.configureClaimableGasOnBehalf(address(this));
    }

    function pauseGame() external onlyOwner {
        paused = true;
    }

    function unpauseGame() external onlyOwner {
        paused = false;
    }

    function getActiveHuntDetails(
        address userAddress
    )
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

    function setAuthorizedNFTContract(
        address nftContract,
        bool authorized
    ) public onlyOwner {
        authorizedNFTContracts[nftContract] = authorized;
    }

    function getWeaponToken(
        uint256 huntId
    ) public view returns (WeaponToken memory) {
        uint256 weaponTokenId = hunts[huntId].weapon;
        IExtendedERC721 nft = IExtendedERC721(hunts[huntId].nftContract);
        (
            ,
            ,
            uint256 damage,
            uint256 attackSpeed,
            uint256 durability,
            uint256 durabilityPerUse,
            ,
            ,

        ) = nft.getItemDetails(weaponTokenId);

        WeaponToken memory weaponToken = WeaponToken({
            damage: damage,
            attackSpeed: attackSpeed,
            durability: durability,
            durabilityPerUse: durabilityPerUse
        });

        return weaponToken;
    }

    // Calculates effective number of hits.
    function handleCharacterBattleHits(
        uint256 attackSpeed,
        uint256 durability,
        uint256 durabilityPerUse,
        uint256 startTime,
        uint256 endTime
    ) internal pure returns (uint256) {
        require(startTime < endTime, "Start time must be before end time");

        uint256 maxHitsBeforeBroke = durability / durabilityPerUse;
        uint256 duration = (endTime - startTime);
        uint256 totalPotentialHits = (duration * attackSpeed);

        // Calculate effective hits to reward
        uint256 totalEffectiveHits = totalPotentialHits > maxHitsBeforeBroke
            ? maxHitsBeforeBroke
            : totalPotentialHits;

        return (totalEffectiveHits);
    }

    // Reduces Item durability based on hits.
    function handleCharacterBattleDurability(
        uint256 durability,
        uint256 durabilityPerUse,
        uint256 totalEffectiveHits
    ) internal pure returns (uint256) {
        durability -= totalEffectiveHits * durabilityPerUse;
        return (durability);
    }

    function isEOA(address _address) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_address)
        }
        return size == 0;
    }

    function startHunt(
        address _location,
        address nftContract,
        uint256 nftId
    ) public nonReentrant returns (uint256) {
        require(!paused, "Game is paused");
        require(
            authorizedNFTContracts[nftContract],
            "NFT contract not authorized"
        );

        IExtendedERC721 nft = IExtendedERC721(nftContract);

        require(nft.ownerOf(nftId) == msg.sender, "Not the owner of the NFT");

        require(huntStartTimes[msg.sender] == 0, "Hunt already started");

        require(
            isEOA(msg.sender),
            "Only externally owned accounts can call this function"
        );

        require(!nftInHunt[nftContract][nftId], "NFT is already in a hunt");

        nft.setStakedStatus(nftId, true);

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
            monster: monster,
            nftContract: nftContract
        });

        hunts[huntCount] = newHunt;
        activeHuntId[msg.sender] = huntCount;
        huntStartTimes[msg.sender] = block.timestamp;

        nftInHunt[nftContract][nftId] = true;
        huntResolved[huntCount] = false;

        emit HuntHasBegun(
            huntCount,
            newHunt.startTime,
            nftContract,
            nftId,
            msg.sender,
            _location,
            monster.name
        );

        return huntCount;
    }

    function endHunt(uint256 huntId) public nonReentrant {
        require(
            hunts[huntId].hunter == msg.sender,
            "Not the hunter of this hunt"
        );
        require(hunts[huntId].endTime == 0, "Hunt already ended");
        require(!huntResolved[huntId], "Hunt already ended");

        emit EntropyRequested(huntId);
    }

    function finalizeHunt(
        uint256 huntId,
        bytes32 randomNumber
    ) public onlyRngAdmin {
        require(!huntResolved[huntId], "Hunt already ended");
        huntResolved[huntId] = true;

        emit EntropyResult(huntId, randomNumber);

        address hunter = hunts[huntId].hunter;

        hunts[huntId].endTime = block.timestamp;
        huntStartTimes[hunter] = 0;
        activeHuntId[hunter] = 0;

        address _nftContract = hunts[huntId].nftContract;

        IExtendedERC721 nft = IExtendedERC721(_nftContract);

        WeaponToken memory weaponToken = getWeaponToken(huntId);

        uint256 effectiveHitCounter = handleCharacterBattleHits(
            weaponToken.attackSpeed,
            weaponToken.durability,
            weaponToken.durabilityPerUse,
            hunts[huntId].startTime,
            hunts[huntId].endTime
        );

        uint256 currentDurability = handleCharacterBattleDurability(
            weaponToken.durability,
            weaponToken.durabilityPerUse,
            effectiveHitCounter
        );

        emit HuntEnd(
            huntId,
            hunts[huntId].startTime,
            hunts[huntId].endTime,
            effectiveHitCounter,
            currentDurability
        );

        nft.updateDurability(hunts[huntId].weapon, currentDurability);

        nft.setStakedStatus(hunts[huntId].weapon, false);

        nftInHunt[_nftContract][hunts[huntId].weapon] = false;

        address dropContractAddress = WorldOfBlastLocation(
            hunts[huntId].location
        ).getDropContractAddress();

        WorldOfBlastDrop worldOfBlastDrop = WorldOfBlastDrop(
            dropContractAddress
        );

        worldOfBlastDrop.handleEarnings(
            hunter,
            effectiveHitCounter * weaponToken.damage,
            randomNumber
        );
    }

    function setRngAdmin(address _rngAdmin) public onlyOwner {
        require(_rngAdmin != address(0), "Invalid address for rngAdmin");
        rngAdmin = _rngAdmin;
    }
}

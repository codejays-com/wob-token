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

interface IBlastPoints {
    function configurePointsOperator(address operator) external;

    function configurePointsOperatorOnBehalf(
        address contractAddress,
        address operator
    ) external;
}

interface IBlast {
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

interface WorldOfBlastDrop {
    function handleTokenEarnings(
        address to,
        uint256 hit,
        uint256 damage,
        uint256 attackSpeed,
        uint256 durability,
        uint256 durabilityPerUse
    ) external returns (uint256);

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

    address[] public locations;
    uint256 public huntCount = 1;
    address public _operator;

    IBlast public constant BLAST =
        IBlast(0x4300000000000000000000000000000000000002);

    /** BLAST MAINNET
    address public constant BLAST_POINTS = 0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800;
    IERC20Rebasing public constant USDB = IERC20Rebasing(0x4300000000000000000000000000000000000003);
    IERC20Rebasing public constant WETH = IERC20Rebasing(0x4300000000000000000000000000000000000004);
    **/

    /*********************** BLAST TESTNET ***********************/
    address public constant BLAST_POINTS =
        0x2fc95838c71e76ec69ff817983BFf17c710F34E0;

    IERC20Rebasing public constant USDB =
        IERC20Rebasing(0x4200000000000000000000000000000000000022);

    IERC20Rebasing public constant WETH =
        IERC20Rebasing(0x4200000000000000000000000000000000000023);

    mapping(address => uint256) public huntStartTimes;
    mapping(address => uint256) public activeHuntId;

    mapping(uint256 => Hunt) public hunts;

    modifier onlyOperator() {
        require(msg.sender == _operator, "Only the operator");
        _;
    }

    event OperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );

    event HuntHasBegun(
        uint256 indexed id,
        uint256 startTime,
        uint256 weapon,
        address hunter,
        address location,
        string monster
    );

    event HuntEnd(
        uint256 indexed id,
        uint256 startTime,
        uint256 endTime,
        uint256 hitCounter,
        uint256 durability
    );

    event updateNFTContract(address _contract);

    event updateDropContract(address _contract);

    // handle drop
    address public contractDropAddress;

    constructor() Ownable(msg.sender) {
        _operator = msg.sender;

        BLAST.configureAutomaticYield();
        BLAST.configureClaimableYield();
        BLAST.configureClaimableGas();

        BLAST.configureGovernor(msg.sender);

        USDB.configure(YieldMode.CLAIMABLE);
        WETH.configure(YieldMode.CLAIMABLE);

        IBlastPoints(BLAST_POINTS).configurePointsOperator(_operator);

        emit OperatorTransferred(address(0), _operator);
    }

    /*********************** BLAST START ***********************/

    function configureContract(
        address contractAddress,
        YieldMode _yield,
        GasMode gasMode,
        address governor
    ) external onlyOwner {
        BLAST.configureContract(contractAddress, _yield, gasMode, governor);
    }

    function configure(
        YieldMode _yield,
        GasMode gasMode,
        address governor
    ) external onlyOwner {
        BLAST.configure(_yield, gasMode, governor);
    }

    function configureClaimableYieldOnBehalf(address contractAddress)
        external
        onlyOwner
    {
        BLAST.configureClaimableYieldOnBehalf(contractAddress);
    }

    function configureAutomaticYieldOnBehalf(address contractAddress)
        external
        onlyOwner
    {
        BLAST.configureAutomaticYieldOnBehalf(contractAddress);
    }

    function configureVoidYield() external onlyOwner {
        BLAST.configureVoidYield();
    }

    function configureVoidYieldOnBehalf(address contractAddress)
        external
        onlyOwner
    {
        BLAST.configureVoidYieldOnBehalf(contractAddress);
    }

    function configureVoidGas() external onlyOwner {
        BLAST.configureVoidGas();
    }

    function configureVoidGasOnBehalf(address contractAddress)
        external
        onlyOwner
    {
        BLAST.configureVoidGasOnBehalf(contractAddress);
    }

    function configureGovernorOnBehalf(address _newGovernor) public onlyOwner {
        _operator = _newGovernor;
        BLAST.configureGovernorOnBehalf(_newGovernor, address(this));
        emit OperatorTransferred(_operator, _newGovernor);
    }

    function configurePointsOperatorOnBehalf(address newOperator)
        external
        onlyOwner
    {
        _operator = newOperator;
        IBlastPoints(_operator).configurePointsOperatorOnBehalf(
            address(this),
            newOperator
        );
    }

    function configureYieldModeTokens(YieldMode _weth, YieldMode _usdb)
        external
        onlyOperator
    {
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

    function configureClaimableGasOnBehalf(address contractAddress)
        external
        onlyOperator
    {
        BLAST.configureClaimableGasOnBehalf(contractAddress);
    }

    // claim yield

    function claimYield(address recipient, uint256 amount)
        external
        onlyOperator
    {
        BLAST.claimYield(address(this), recipient, amount);
    }

    function claimAllYield(address recipient) external onlyOperator {
        BLAST.claimAllYield(address(this), recipient);
    }

    // claim gas
    function claimAllGas(address recipientOfGas)
        external
        onlyOperator
        returns (uint256)
    {
        return BLAST.claimAllGas(address(this), recipientOfGas);
    }

    function claimGasAtMinClaimRate(
        address recipientOfGas,
        uint256 minClaimRateBips
    ) external onlyOperator returns (uint256) {
        return
            BLAST.claimGasAtMinClaimRate(
                address(this),
                recipientOfGas,
                minClaimRateBips
            );
    }

    function claimMaxGas(address recipientOfGas)
        external
        onlyOperator
        returns (uint256)
    {
        return BLAST.claimMaxGas(address(this), recipientOfGas);
    }

    function claimGas(
        address recipientOfGas,
        uint256 gasToClaim,
        uint256 gasSecondsToConsume
    ) external onlyOperator returns (uint256) {
        return
            BLAST.claimGas(
                address(this),
                recipientOfGas,
                gasToClaim,
                gasSecondsToConsume
            );
    }

    // read functions
    function readClaimableYield() external view returns (uint256) {
        return BLAST.readClaimableYield(address(this));
    }

    function readYieldConfiguration() external view returns (uint8) {
        return BLAST.readYieldConfiguration(address(this));
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

    /*********************** BLAST END  ***********************/

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
        uint256 duration = endTime - startTime;
        
        // Blockchain Start/end time is calculated in seconds
        // Duration * 2 = number of seconds passed x2, which translates to double the hits
        // Which translates to an "effective base hit tick rate" at 0.5 seconds
        uint256 totalHits = (duration * 2) * attackSpeed; // hit every 0.5 seconds
        return totalHits;
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

        uint256 hitsBeforeBroke = 0;
        
        for (uint256 index = 0; index < totalHitsQuantity; index++) {
            if (durability <= 0) {
                durability = 0;
                break;
            } else {
                durability -= durabilityPerUse;
                hitsBeforeBroke++;
            }
        }
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
        (
            ,
            ,
            /* string memory name */
            /* string memory description */
            uint256 damage,
            uint256 attackSpeed,
            uint256 durability, /* string memory max */
            uint256 durabilityPerUse, /* string memory weaponType */
            ,
            ,
        ) = /* string memory imageUrl */
            NFTContract.getItemDetails(hunts[huntId].weapon);

        activeHuntId[msg.sender] = 0;

        // handle nft durability
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

        worldOfBlastDrop.handleTokenEarnings(
            msg.sender,
            hitCounter,
            damage,
            attackSpeed,
            durability,
            durabilityPerUse
        );

        worldOfBlastDrop.handleNFTEarnings(msg.sender);
    }
}

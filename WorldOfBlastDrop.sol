// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

enum YieldMode {
    AUTOMATIC,
    VOID,
    CLAIMABLE
}
enum GasMode {
    VOID,
    CLAIMABLE
}

interface IERC20Rebasing {
    function configure(YieldMode _mode) external returns (uint256);

    function claim(address recipient, uint256 amount)
        external
        returns (uint256);

    function getClaimableAmount(address account)
        external
        view
        returns (uint256);
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

interface WorldOfBlastNft {
    function restoreNFT(uint256 tokenId) external;
}

interface IERC721Enumerable is IERC721, WorldOfBlastNft {
    function tokenOfOwnerByIndex(address owner, uint256 index)
        external
        view
        returns (uint256);
}

contract WorldOfBlastDrop is Ownable {
    mapping(address => bool) public authorizedToUseContract;

    // Blast
    IBlast constant BLAST = IBlast(0x4300000000000000000000000000000000000002);

    IERC20Rebasing public USDB;
    IERC20Rebasing public WETH;

    address public USDB_ADDRESS = 0x4300000000000000000000000000000000000003;
    address public WETH_ADDDRES = 0x4300000000000000000000000000000000000004;
    address public CONTRACT_NFT = 0xFB7acDaE5B59e9C3337203830aEC1563316679E6;

    uint256 private RATE = 54697070639;
    uint256[] private weights = [
        1500,
        2500,
        3500,
        3500,
        2500,
        2500,
        6500,
        1500,
        2500,
        8000,
        1500,
        1500,
        1500,
        2500,
        1250,
        1000,
        1000,
        600,
        500,
        300,
        80,
        40,
        30,
        25,
        10,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0
    ];
    uint256[] private multipliers = [
        75,
        78,
        80,
        82,
        85,
        88,
        90,
        92,
        95,
        100,
        105,
        110,
        115,
        120,
        125,
        130,
        135,
        140,
        145,
        150,
        175,
        190,
        200,
        225,
        250,
        300,
        500,
        1000,
        2000,
        5000,
        10000,
        20000,
        50000
    ];
    uint256 private totalWeight;

    constructor() Ownable(msg.sender) {
        authorizedToUseContract[msg.sender] = true;

        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800)
            .configurePointsOperator(
                0x4225d96C1d59D935c2b004823C184C4D9caF159e
            );

        USDB = IERC20Rebasing(USDB_ADDRESS);
        WETH = IERC20Rebasing(WETH_ADDDRES);

        USDB.configure(YieldMode.CLAIMABLE);
        WETH.configure(YieldMode.CLAIMABLE);

        BLAST.configureGovernor(msg.sender);
        BLAST.configureAutomaticYield();
        BLAST.configureClaimableYield();
        BLAST.configureClaimableGas();

        for (uint256 i = 0; i < weights.length; i++) {
            totalWeight += weights[i];
        }
    }

    modifier onlyAuthorizedContract() {
        require(
            authorizedToUseContract[msg.sender],
            "Not authorized to use this contract"
        );
        _;
    }

    event tokenDrop(address to, uint256 multiplier, uint256 earns);

    function authorizeContract(address contractAddress, bool authorized)
        external
        onlyAuthorizedContract
    {
        authorizedToUseContract[contractAddress] = authorized;
    }

    function setContractNFTAddress(address _address)
        external
        onlyAuthorizedContract
    {
        CONTRACT_NFT = _address;
    }

    function updateRate(uint256 _rate) external onlyAuthorizedContract {
        RATE = _rate;
    }

    function updateWeightsPosition(uint256 position, uint256 value)
        external
        onlyAuthorizedContract
    {
        weights[position] = value;
    }

    function updateMultipliersPosition(uint256 position, uint256 value)
        external
        onlyAuthorizedContract
    {
        multipliers[position] = value;
    }

    function getMultiplier(uint256 _random) private view returns (uint256) {
        uint256 randomValue = uint256(
            keccak256(abi.encodePacked(block.timestamp, _random, msg.sender))
        );

        uint256 weightedRandom = randomValue % totalWeight;
        uint256 cumulativeWeight = 0;
        for (uint256 i = 0; i < weights.length; i++) {
            cumulativeWeight += weights[i];
            if (weightedRandom < cumulativeWeight) {
                return multipliers[i];
            }
        }

        revert("No multipliers found.");
    }

    function handleTokenEarnings(address _address, uint256 damage)
        external
        onlyAuthorizedContract
        returns (uint256)
    {
        IERC20 currentToken = IERC20(WETH_ADDDRES);

        uint256 currentAmount = currentToken.balanceOf(address(this));

        uint256 totalDamage = RATE * damage;
        uint256 multiplier = getMultiplier(totalDamage + currentAmount + 1);
        uint256 deliveryEarns = ((totalDamage * multiplier) / 100);
        emit tokenDrop(_address, multiplier, deliveryEarns);

        if (deliveryEarns > currentAmount) {
            deliveryEarns = currentAmount;
        }

        if (deliveryEarns > 0) {
            currentToken.transfer(_address, deliveryEarns);
        }

        return deliveryEarns;
    }

    function handleNFTEarnings(address to) external onlyAuthorizedContract {
        IERC721Enumerable currentToken = IERC721Enumerable(CONTRACT_NFT);
        uint256 randomNumber = uint256(
            keccak256(abi.encodePacked(block.timestamp))
        );
        uint256 randomInRange = randomNumber % 100;
        uint256 balance = currentToken.balanceOf(address(this));
        if (balance > 0 && randomInRange == 0) {
            uint256 randomIndex = uint256(
                keccak256(abi.encodePacked(block.timestamp, to))
            ) % balance;
            uint256 tokenId = currentToken.tokenOfOwnerByIndex(
                address(this),
                randomIndex
            );
            WorldOfBlastNft worldOfBlastNft = WorldOfBlastNft(CONTRACT_NFT);
            worldOfBlastNft.restoreNFT(tokenId);
            currentToken.safeTransferFrom(address(this), to, tokenId);
        }
    }

    function withdrawBalance(address _contract, uint256 amount)
        external
        onlyAuthorizedContract
        returns (bool)
    {
        IERC20 currentToken = IERC20(_contract);
        return
            currentToken.transfer(
                0x875b9a0C81c505b3f06D0669ac7ba4798aC8Ef09,
                amount
            );
    }

    function withdrawNFT(address _nftContractAddress, address to)
        external
        onlyAuthorizedContract
        returns (bool)
    {
        IERC721Enumerable currentToken = IERC721Enumerable(_nftContractAddress);
        uint256 balance = currentToken.balanceOf(address(this));

        while (balance > 0) {
            uint256 tokenId = currentToken.tokenOfOwnerByIndex(
                address(this),
                balance - 1
            );
            currentToken.safeTransferFrom(address(this), to, tokenId);
            balance--;
        }

        return true;
    }

    // Blast functions

    function claimAllGas() external onlyAuthorizedContract {
        BLAST.claimAllGas(address(this), msg.sender);
    }

    function claimYieldTokens(address _recipient, uint256 _amount)
        external
        onlyAuthorizedContract
        returns (uint256, uint256)
    {
        return (
            USDB.claim(_recipient, _amount),
            WETH.claim(_recipient, _amount)
        );
    }

    function getClaimableAmount(address _account)
        external
        view
        returns (uint256, uint256)
    {
        return (
            USDB.getClaimableAmount(_account),
            WETH.getClaimableAmount(_account)
        );
    }

    function updatePointsOperator(address _newOperator)
        external
        onlyAuthorizedContract
    {
        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800)
            .configurePointsOperatorOnBehalf(address(this), _newOperator);
    }

    function configureContract(
        YieldMode _yield,
        GasMode gasMode,
        address governor
    ) external onlyAuthorizedContract {
        BLAST.configureContract(address(this), _yield, gasMode, governor);
    }

    function configure(
        YieldMode _yield,
        GasMode gasMode,
        address governor
    ) external onlyAuthorizedContract {
        BLAST.configure(_yield, gasMode, governor);
    }

    function configureClaimableYieldOnBehalf() external onlyAuthorizedContract {
        BLAST.configureClaimableYieldOnBehalf(address(this));
    }

    function configureAutomaticYieldOnBehalf() external onlyAuthorizedContract {
        BLAST.configureAutomaticYieldOnBehalf(address(this));
    }

    function configureVoidYield() external onlyAuthorizedContract {
        BLAST.configureVoidYield();
    }

    function configureVoidYieldOnBehalf() external onlyAuthorizedContract {
        BLAST.configureVoidYieldOnBehalf(address(this));
    }

    function configureClaimableGasOnBehalf() external onlyAuthorizedContract {
        BLAST.configureClaimableGasOnBehalf(address(this));
    }

    function configureVoidGas() external onlyAuthorizedContract {
        BLAST.configureVoidGas();
    }

    function configureVoidGasOnBehalf() external onlyAuthorizedContract {
        BLAST.configureVoidGasOnBehalf(address(this));
    }

    function configureGovernor(address _governor)
        external
        onlyAuthorizedContract
    {
        BLAST.configureGovernor(_governor);
    }

    function configureGovernorOnBehalf(address _newGovernor)
        external
        onlyAuthorizedContract
    {
        BLAST.configureGovernorOnBehalf(_newGovernor, address(this));
    }

    function claimYield(address recipient, uint256 amount)
        external
        onlyAuthorizedContract
    {
        BLAST.claimYield(address(this), recipient, amount);
    }

    function claimAllYield(address recipient) external onlyAuthorizedContract {
        BLAST.claimAllYield(address(this), recipient);
    }

    function claimGasAtMinClaimRate(
        address recipientOfGas,
        uint256 minClaimRateBips
    ) external onlyAuthorizedContract {
        BLAST.claimGasAtMinClaimRate(
            address(this),
            recipientOfGas,
            minClaimRateBips
        );
    }

    function claimMaxGas(address recipientOfGas)
        external
        onlyAuthorizedContract
    {
        BLAST.claimMaxGas(address(this), recipientOfGas);
    }

    function claimGas(
        address recipientOfGas,
        uint256 gasToClaim,
        uint256 gasSecondsToConsume
    ) external onlyAuthorizedContract {
        BLAST.claimGas(
            address(this),
            recipientOfGas,
            gasToClaim,
            gasSecondsToConsume
        );
    }

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
}

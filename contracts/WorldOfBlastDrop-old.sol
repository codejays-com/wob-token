// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBlast.sol";
import "./interfaces/IBlastPoints.sol";

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

    IBlast public constant BLAST =
        IBlast(0x4300000000000000000000000000000000000002);

    address public USDB_ADDRESS = 0x4300000000000000000000000000000000000003;
    address public WETH_ADDRESS = 0x4300000000000000000000000000000000000004;
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

    event tokenDrop(address to, uint256 multiplier, uint256 earns);

    constructor() Ownable(msg.sender) {
        authorizedToUseContract[msg.sender] = true;

        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800)
            .configurePointsOperator(
                0x4225d96C1d59D935c2b004823C184C4D9caF159e
            );

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

    function authorizeContract(address contractAddress, bool authorized)
        external
        onlyAuthorizedContract
    {
        authorizedToUseContract[contractAddress] = authorized;
    }

    function setContractNFTAddress(address _address) external onlyOwner {
        CONTRACT_NFT = _address;
    }

    function updateRate(uint256 _rate) external onlyOwner {
        RATE = _rate;
    }

    function updateWeightsPosition(uint256 position, uint256 value)
        external
        onlyOwner
    {
        weights[position] = value;
    }

    function updateMultipliersPosition(uint256 position, uint256 value)
        external
        onlyOwner
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
        IERC20 currentToken = IERC20(WETH_ADDRESS);

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
        onlyOwner
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
        onlyOwner
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
    function updatePointsOperator(address _newOperator) external onlyOwner {
        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800)
            .configurePointsOperatorOnBehalf(address(this), _newOperator);
    }

    function claimYield(address recipient, uint256 amount) external onlyOwner {
        BLAST.claimYield(address(this), recipient, amount);
    }

    function claimAllYield(address recipient) external onlyOwner {
        BLAST.claimAllYield(address(this), recipient);
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

    function claimMaxGas(address recipientOfGas) external onlyOwner {
        BLAST.claimMaxGas(address(this), recipientOfGas);
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
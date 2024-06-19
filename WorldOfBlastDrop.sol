// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum Environment { TESTNET, MAINNET }
enum YieldMode { AUTOMATIC, VOID, CLAIMABLE }
enum GasMode { VOID, CLAIMABLE }

interface IERC20Rebasing {
  function configure(YieldMode) external returns (uint256);
  function claim(address recipient, uint256 amount) external returns (uint256);
  function getClaimableAmount(address account) external view returns (uint256);
}

interface IBlastPoints {
  function configurePointsOperator(address operator) external;
  function configurePointsOperatorOnBehalf(address contractAddress, address operator) external;
}

interface IBlast {
    // configure
    function configureContract(address contractAddress, YieldMode _yield, GasMode gasMode, address governor) external;
    function configure(YieldMode _yield, GasMode gasMode, address governor) external;

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
    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external;

    // claim yield
    function claimYield(address contractAddress, address recipientOfYield, uint256 amount) external returns (uint256);
    function claimAllYield(address contractAddress, address recipientOfYield) external returns (uint256);

    // claim gas
    function claimAllGas(address contractAddress, address recipientOfGas) external returns (uint256);
    function claimGasAtMinClaimRate(address contractAddress, address recipientOfGas, uint256 minClaimRateBips) external returns (uint256);
    function claimMaxGas(address contractAddress, address recipientOfGas) external returns (uint256);
    function claimGas(address contractAddress, address recipientOfGas, uint256 gasToClaim, uint256 gasSecondsToConsume) external returns (uint256);

    // read functions
    function readClaimableYield(address contractAddress) external view returns (uint256);
    function readYieldConfiguration(address contractAddress) external view returns (uint8);
    function readGasParams(address contractAddress) external view returns (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode);
}

interface WorldOfBlastNft {
    function restoreNFT(uint256 tokenId) external;
}

interface IERC721Enumerable is IERC721, WorldOfBlastNft {
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract WorldOfBlastDrop {
    address public contractTokenAddress;
    address public contractNFTAddress;
    uint256 public defaultTokenEarnsPercent = 3381000000000; // 0.00003381 percent
    uint256 public targetAveragePercent = 98;

    mapping(address => bool) public authorizedToUseContract;

    // Blast
    IERC20Rebasing private USDB;
    IERC20Rebasing private WETH;
    IBlastPoints private blastPointsInstance;
    IBlast private blastInstance;

    constructor(address _contractTokenAddress, address _contractNFTAddress) {
        contractTokenAddress = _contractTokenAddress;
        contractNFTAddress = _contractNFTAddress;
        authorizedToUseContract[msg.sender] = true;

        // Blast
        address BLAST_CONTRACT = 0x4300000000000000000000000000000000000002;
        address BLAST_POINTS_ADDRESS = 0x2fc95838c71e76ec69ff817983BFf17c710F34E0;
        address USDB_ADDRESS = 0x4200000000000000000000000000000000000022;
        address WETH_ADDDRES = 0x4200000000000000000000000000000000000023;

        Environment _environment = Environment.TESTNET;

        if (_environment == Environment.MAINNET) {
            BLAST_POINTS_ADDRESS = 0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800;
            USDB_ADDRESS = 0x4300000000000000000000000000000000000003;
            WETH_ADDDRES = 0x4300000000000000000000000000000000000004;
        }

        blastPointsInstance = IBlastPoints(BLAST_POINTS_ADDRESS);
        blastPointsInstance.configurePointsOperator(msg.sender);

        USDB = IERC20Rebasing(USDB_ADDRESS);
        WETH = IERC20Rebasing(WETH_ADDDRES);

        USDB.configure(YieldMode.CLAIMABLE);
        WETH.configure(YieldMode.CLAIMABLE);

        // Blast configure
        blastInstance = IBlast(BLAST_CONTRACT);
        blastInstance.configureAutomaticYield();
        blastInstance.configureClaimableYield();
        blastInstance.configureClaimableGas();
        blastInstance.configureGovernor(msg.sender);
    }


    modifier onlyAuthorizedContract() {
        require(authorizedToUseContract[msg.sender], "Not authorized to use this contract");
        _;
    }

    event TokenDrop(uint256 hit, uint256 totalDamage, uint256 additionalDamage, uint256 earns, uint256 percent, uint256 deliveryEarns);

    function authorizeContract(address contractAddress, bool authorized) external onlyAuthorizedContract {
        authorizedToUseContract[contractAddress] = authorized;
    }

    function setContractTokenAddress(address _contractAddress) external onlyAuthorizedContract {
        contractTokenAddress = _contractAddress;
    }

    function setContractNFTAddress(address _contractAddress) external onlyAuthorizedContract {
        contractNFTAddress = _contractAddress;
    }

    function setDefaultTokenEarnsPercent(uint256 _defaultTokenEarnsPercent) external onlyAuthorizedContract {
        defaultTokenEarnsPercent = _defaultTokenEarnsPercent;
    }

    function setTargetAveragePercent(uint256 _targetAveragePercent) external onlyAuthorizedContract {
        targetAveragePercent = _targetAveragePercent;
    }

    function handleRandomNumber() internal view returns (uint256) {
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp)));
        if (randomNumber % 100 < targetAveragePercent) {
            return handleRandomInRange(30, 180);
        } else {
            return handleRandomInRange(181, 500);
        }
    }

    function handleRandomInRange(uint256 min, uint256 max) internal view returns (uint256) {
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp)));
        return (randomNumber % (max - min + 1)) + min;
    }

    function handleTokenEarnings(address to, uint256 hit, uint256 damage, uint256 attackSpeed, uint256 durability, uint256 durabilityPerUse) external onlyAuthorizedContract returns (uint256) {
        uint256 totalDamage = damage * attackSpeed * (durability / durabilityPerUse);
        uint256 additionalDamage = totalDamage * defaultTokenEarnsPercent;
        uint256 earns = additionalDamage * hit;
        uint256 percent = handleRandomNumber();
        uint256 deliveryEarns = (earns * handleRandomNumber() / 100);
        
        IERC20 currentToken = IERC20(contractTokenAddress);
        uint256 currentAmount = currentToken.balanceOf(address(this));
        if (deliveryEarns > currentAmount) {
            deliveryEarns = currentAmount;
        }
        currentToken.transfer(to, deliveryEarns);
        emit TokenDrop(hit, totalDamage, additionalDamage, earns, percent, deliveryEarns);
        return deliveryEarns;
    }

    function handleNFTEarnings(address to) external onlyAuthorizedContract {
        IERC721Enumerable currentToken = IERC721Enumerable(contractNFTAddress);
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp)));
        uint256 randomInRange = randomNumber % 100;
        uint256 balance = currentToken.balanceOf(address(this));
        if (balance > 0 && randomInRange == 0) {
            uint256 randomIndex = uint256(keccak256(abi.encodePacked(block.timestamp, to))) % balance;
            uint256 tokenId = currentToken.tokenOfOwnerByIndex(address(this), randomIndex);
            WorldOfBlastNft worldOfBlastNft = WorldOfBlastNft(contractNFTAddress);
            worldOfBlastNft.restoreNFT(tokenId);
            currentToken.safeTransferFrom(address(this), to, tokenId);
        }
    }

    function transferFromERC20(uint256 amount, address to) external onlyAuthorizedContract { 
        IERC20 currentToken = IERC20(contractTokenAddress);
        uint256 currentAmount = currentToken.balanceOf(address(this));
        if (amount > currentAmount) {
            amount = currentAmount;
        }
        currentToken.transfer(to, amount);
    }

    function transferFromERC721(address to, uint256 tokenId) external onlyAuthorizedContract {
        IERC721Enumerable currentToken = IERC721Enumerable(contractNFTAddress);
        currentToken.safeTransferFrom(address(this), to, tokenId);
    }

    function withdrawBalance(address _tokenContractAddress, address to) external onlyAuthorizedContract returns (bool) {
        IERC20 currentToken = IERC20(_tokenContractAddress);
        return currentToken.transfer(to, currentToken.balanceOf(address(this)));
    }

    function withdrawNFT(address _nftContractAddress, address to) external onlyAuthorizedContract returns (bool) {
        IERC721Enumerable currentToken = IERC721Enumerable(_nftContractAddress);
        uint256 balance = currentToken.balanceOf(address(this));
        
        while (balance > 0) {
            uint256 tokenId = currentToken.tokenOfOwnerByIndex(address(this), balance - 1);
            currentToken.safeTransferFrom(address(this), to, tokenId);
            balance--;
        }
        
        return true;
    }

    // Blast functions

    function configureYieldModeTokens(address _usdAddress, address _wethAddress, YieldMode _usdbMode, YieldMode _wethMode) external onlyAuthorizedContract {
        USDB = IERC20Rebasing(_usdAddress);
        WETH = IERC20Rebasing(_wethAddress);
        USDB.configure(_usdbMode);
        WETH.configure(_wethMode);
    }

    function claimYieldTokens(address _recipient, uint256 _amount) external onlyAuthorizedContract returns (uint256, uint256) {
        return (USDB.claim(_recipient, _amount), WETH.claim(_recipient, _amount));
    }

    function getClaimableAmount(address _account) external view returns (uint256, uint256) { 
        return (USDB.getClaimableAmount(_account), WETH.getClaimableAmount(_account));
    }

    function updateConfigurePointsOperator(address _blastPointsAddress, address _pointsOperator) external onlyAuthorizedContract {
        blastPointsInstance = IBlastPoints(_blastPointsAddress);
        blastPointsInstance.configurePointsOperator(_pointsOperator);
    }

    function updatePointsOperator(address _blastPointsAddress, address _contractAddress, address _newOperator) external onlyAuthorizedContract {
        blastPointsInstance = IBlastPoints(_blastPointsAddress);
        blastPointsInstance.configurePointsOperatorOnBehalf(_contractAddress, _newOperator);
    }

    // blast interface
    function updateBlastInstance(address blastContractAddress) external onlyAuthorizedContract {
        blastInstance = IBlast(blastContractAddress);
    }

    function configure() external onlyAuthorizedContract {
       blastInstance.configureClaimableYield();
       blastInstance.configureAutomaticYield();
       blastInstance.configureClaimableGas();
    }

    function configureContract(address contractAddress, YieldMode _yield, GasMode gasMode, address governor) external onlyAuthorizedContract {
        blastInstance.configureContract(contractAddress, _yield, gasMode, governor);
    }

    function configure(YieldMode _yield, GasMode gasMode, address governor) external onlyAuthorizedContract {
        blastInstance.configure(_yield, gasMode, governor);
    }

    function configureClaimableYieldOnBehalf(address contractAddress) external onlyAuthorizedContract {
        blastInstance.configureClaimableYieldOnBehalf(contractAddress);
    }

    function configureAutomaticYieldOnBehalf(address contractAddress) external onlyAuthorizedContract {
        blastInstance.configureAutomaticYieldOnBehalf(contractAddress);
    }

    function configureVoidYield() external onlyAuthorizedContract {
        blastInstance.configureVoidYield();
    }

    function configureVoidYieldOnBehalf(address contractAddress) external onlyAuthorizedContract {
        blastInstance.configureVoidYieldOnBehalf(contractAddress);
    }
    
    function configureClaimableGasOnBehalf(address contractAddress) external onlyAuthorizedContract {
        blastInstance.configureClaimableGasOnBehalf(contractAddress);
    }

    function configureVoidGas() external onlyAuthorizedContract {
        blastInstance.configureVoidGas();
    }

    function configureVoidGasOnBehalf(address contractAddress) external onlyAuthorizedContract {
        blastInstance.configureVoidGasOnBehalf(contractAddress);
    }

    function configureGovernor(address _governor) external onlyAuthorizedContract {
        blastInstance.configureGovernor(_governor);
    }

    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) external onlyAuthorizedContract {
        blastInstance.configureGovernorOnBehalf(_newGovernor, contractAddress);
    }

    function claimYield(address contractAddress, address recipientOfYield, uint256 amount) external onlyAuthorizedContract returns (uint256) {
        return blastInstance.claimYield(contractAddress, recipientOfYield, amount);
    }

    function claimAllYield(address contractAddress, address recipientOfYield) external onlyAuthorizedContract returns (uint256) {
        return blastInstance.claimAllYield(contractAddress, recipientOfYield);
    }

    function claimAllGas(address contractAddress, address recipientOfGas) external onlyAuthorizedContract returns (uint256) {
        return blastInstance.claimAllGas(contractAddress, recipientOfGas);
    }
    
    function claimGasAtMinClaimRate(address contractAddress, address recipientOfGas, uint256 minClaimRateBips) external onlyAuthorizedContract returns (uint256) {
        return blastInstance.claimGasAtMinClaimRate(contractAddress, recipientOfGas, minClaimRateBips);
    }
    
    function claimMaxGas(address contractAddress, address recipientOfGas) external onlyAuthorizedContract returns (uint256) {
        return blastInstance.claimMaxGas(contractAddress, recipientOfGas);
    }
    
    function claimGas(address contractAddress, address recipientOfGas, uint256 gasToClaim, uint256 gasSecondsToConsume) external onlyAuthorizedContract returns (uint256) {
        return blastInstance.claimGas(contractAddress, recipientOfGas, gasToClaim, gasSecondsToConsume);
    }

    function readClaimableYield(address contractAddress) external view returns (uint256) {
        return blastInstance.readClaimableYield(contractAddress);
    }

    function readYieldConfiguration(address contractAddress) external view returns (uint8) {
        return blastInstance.readYieldConfiguration(contractAddress);
    }
    
    function readGasParams(address contractAddress) external view returns (uint256 etherSeconds, uint256 etherBalance, uint256 lastUpdated, GasMode) {
        return blastInstance.readGasParams(contractAddress);
    }
}

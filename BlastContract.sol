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

contract BlastContract {

    mapping(address => bool) public authorizedToUseContract;

    // Blast
    IERC20Rebasing private USDB;
    IERC20Rebasing private WETH;
    IBlastPoints private blastPointsInstance;
    IBlast private blastInstance;

    constructor() {
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

    function withdrawBalance(address _tokenContractAddress, address to) external onlyAuthorizedContract returns (bool) {
        IERC20 currentToken = IERC20(_tokenContractAddress);
        return currentToken.transfer(to, currentToken.balanceOf(address(this)));
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

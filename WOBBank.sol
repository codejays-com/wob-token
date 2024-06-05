// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

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

contract WOBBank is ERC20, ERC20Permit, Ownable {
    // internal
    uint256 private _totalSupply;

    // private
    IERC20Rebasing private USDB;
    IERC20Rebasing private WETH;

    // instances
    IBlastPoints private blastPointsInstance;

    constructor() ERC20("WOB Bank", "WOBB") ERC20Permit("WOB Bank") Ownable(msg.sender) {
        uint256 _initialSupply = 1000000000 * 10 ** decimals();
        _totalSupply = _initialSupply;
        _mint(address(this), _initialSupply);

        Environment _environment = Environment.TESTNET; // development

        address BLAST_POINTS_ADDRESS = 0x2fc95838c71e76ec69ff817983BFf17c710F34E0;
        address USDB_ADDRESS = 0x4200000000000000000000000000000000000022;
        address WETH_ADDDRES = 0x4200000000000000000000000000000000000023;

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
    }

    function configureYieldModeTokens(address _usdAddress, address _wethAddress, YieldMode _usdbMode, YieldMode _wethMode) external onlyOwner {
        USDB = IERC20Rebasing(_usdAddress);
        WETH = IERC20Rebasing(_wethAddress);
        USDB.configure(_usdbMode);
        WETH.configure(_wethMode);
    }

    function claimYieldTokens(address _recipient, uint256 _amount) external onlyOwner returns (uint256[] memory) {
        uint256[] memory claimTokens = new uint256[](2);
        claimTokens[0] = USDB.claim(_recipient, _amount);
        claimTokens[1] = WETH.claim(_recipient, _amount);
        return claimTokens;
    }

    function getClaimableAmount(address _account) external view onlyOwner returns (uint256[] memory) { 
        uint256[] memory claimableAmounts = new uint256[](2);
        claimableAmounts[0] = USDB.getClaimableAmount(_account);
        claimableAmounts[1] = WETH.getClaimableAmount(_account);
        return claimableAmounts;
    }

    function updateConfigurePointsOperator(address _blastPointsAddress, address _pointsOperator) external onlyOwner {
        blastPointsInstance = IBlastPoints(_blastPointsAddress);
        blastPointsInstance.configurePointsOperator(_pointsOperator);
    }

    function updatePointsOperator(address _blastPointsAddress, address _contractAddress, address _newOperator) external onlyOwner {
        blastPointsInstance = IBlastPoints(_blastPointsAddress);
        blastPointsInstance.configurePointsOperatorOnBehalf(_contractAddress, _newOperator);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function withdrawBalance(address _tokenContractAddress) external onlyOwner {
        IERC20 currentToken = IERC20(_tokenContractAddress);
        currentToken.transfer(owner(), currentToken.balanceOf(address(this)));
    }
}

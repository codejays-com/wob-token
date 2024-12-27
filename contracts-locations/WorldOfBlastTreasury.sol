// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IBlast.sol";
import "./interfaces/IBlastPoints.sol";

/**
   Contract Handls fund & NFT transactions
**/

interface IERC721 {
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

contract WorldOfBlastTreasury is Ownable {
    using SafeERC20 for IERC20;
    address private whitelistAdmin;
    address[] private pendingAuthorizeContracts;
    mapping(address => bool) public authorizedContracts;

    // Blast Contract
    IBlast public constant BLAST =
        IBlast(0x4300000000000000000000000000000000000002);

    constructor(address _whitelistAdmin) Ownable(msg.sender) {
        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800)
            .configurePointsOperator(
                0x4225d96C1d59D935c2b004823C184C4D9caF159e
            );

        BLAST.configureClaimableYield();
        BLAST.configureClaimableGas();
        whitelistAdmin = _whitelistAdmin;
    }

    function queuePendingContract(
        address contractAddress
    ) public whitelistAdminOnly {
        require(
            contractAddress != address(0),
            "Contract address cannot be the zero address"
        );
        require(
            !authorizedContracts[contractAddress],
            "Contract is already authorized"
        );

        pendingAuthorizeContracts.push(contractAddress);
    }

    function authorizePendingContracts() public onlyOwner {
        for (uint256 i = 0; i < pendingAuthorizeContracts.length; i++) {
            address contractAddress = pendingAuthorizeContracts[i];
            authorizedContracts[contractAddress] = true;
        }
        delete pendingAuthorizeContracts;
    }

    function removeAuthorizeContract(
        address contractAddress
    ) public whitelistAdminOnly {
        require(
            authorizedContracts[contractAddress],
            "Contract is not authorized"
        );
        authorizedContracts[contractAddress] = false;
    }

    function isAuthorized(address contractAddress) public view returns (bool) {
        return authorizedContracts[contractAddress];
    }

    function transferToken(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public authorizedOnly {
        require(recipient != address(0), "Recipient address cannot be zero");
        IERC20 token = IERC20(tokenAddress);
        SafeERC20.safeTransfer(token, recipient, amount);
        emit FundsTransferred(tokenAddress, recipient, amount);
    }

    function withdrawBalance(
        address _contract,
        uint256 amount
    ) external onlyOwner returns (bool) {
        IERC20 currentToken = IERC20(_contract);
        return currentToken.transfer(whitelistAdmin, amount);
    }

    function withdrawNFT(
        address nftContract,
        uint256 tokenId
    ) external onlyOwner {
        require(nftContract != address(0), "Invalid contract address");

        IERC721(nftContract).safeTransferFrom(
            address(this),
            whitelistAdmin,
            tokenId
        );
    }

    event AuthorizedContract(address indexed contractAddress, bool authorized);
    event FundsTransferred(
        address indexed tokenAddress,
        address indexed recipient,
        uint256 amount
    );

    //Modifiers
    modifier whitelistAdminOnly() {
        require(msg.sender == whitelistAdmin, "Not authorized: Whitelist only");
        _;
    }

    modifier authorizedOnly() {
        require(
            authorizedContracts[msg.sender],
            "Contract is not authorized to withdraw funds"
        );
        _;
    }

    // Blast functions
    function claimAllGas() external onlyOwner {
        BLAST.claimAllGas(address(this), msg.sender);
    }

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

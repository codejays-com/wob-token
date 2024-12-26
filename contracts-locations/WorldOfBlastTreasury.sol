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
    mapping(address => bool) public authorizedContracts;

    // Blast Contract
    IBlast public constant BLAST =
        IBlast(0x4300000000000000000000000000000000000002);

    constructor() Ownable(msg.sender) {

        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800)
            .configurePointsOperator(
                0x4225d96C1d59D935c2b004823C184C4D9caF159e
            );

        BLAST.configureClaimableYield();
        BLAST.configureClaimableGas();
    }

    function authorizeContract(
        address contractAddress,
        bool authorized
    ) public onlyOwner {
        authorizedContracts[contractAddress] = authorized;
        emit AuthorizedContract(contractAddress, authorized);
    }

    function withdrawFunds(
        address tokenAddress,
        uint256 amount
    ) public authorizedOnly {
        IERC20 token = IERC20(tokenAddress);
        SafeERC20.safeTransfer(token, msg.sender, amount);
    }

    function transferFunds(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) public authorizedOnly {
        require(recipient != address(0), "Recipient address cannot be zero");
        IERC20 token = IERC20(tokenAddress);
        SafeERC20.safeTransfer(token, recipient, amount);
        emit FundsTransferred(tokenAddress, recipient, amount);
    }

    modifier authorizedOnly() {
        require(
            authorizedContracts[msg.sender],
            "Contract is not authorized to withdraw funds"
        );
        _;
    }

    function withdrawBalance(
        address _contract,
        uint256 amount
    ) external onlyOwner returns (bool) {
        IERC20 currentToken = IERC20(_contract);
        return
            currentToken.transfer(
                0x875b9a0C81c505b3f06D0669ac7ba4798aC8Ef09,
                amount
            );
    }

    function withdrawAllNFTs(
        address _nftContractAddress,
        address to
    ) external onlyOwner returns (bool) {
        IERC721Enumerable nftContract = IERC721Enumerable(_nftContractAddress);
        uint256 balance = nftContract.balanceOf(address(this));

        require(balance > 0, "No NFTs to withdraw");

        for (uint256 i = 0; i < balance; i++) {
            uint256 tokenId = nftContract.tokenOfOwnerByIndex(address(this), 0);
            nftContract.safeTransferFrom(address(this), to, tokenId);
        }

        return true;
    }

    event AuthorizedContract(address indexed contractAddress, bool authorized);
    event FundsTransferred(
        address indexed tokenAddress,
        address indexed recipient,
        uint256 amount
    );

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

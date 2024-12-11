// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBlast.sol";
import "./interfaces/IBlastPoints.sol";

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

    // handle custom tokens
    struct tokenObject {
        string name; // contract Name
        address addr; // contract address
        uint256 totalWeight;
        uint256 rate;
        uint256[8] weights;
        uint256[8] multipliers;
    }

    // handle custom nfts
    struct nftObject {
        string name; // contract Name
        address addr; // contract address
        uint256 prob; // 10^18 = 1
    }

    struct lootObject {
        string name;
        address addr;
        uint256 amount;
        string contractType; // "nft" or "token"
    }

    uint256 public nftContracts;
    uint256 public tokenContracts;

    tokenObject[] private tokenObjectsArray;
    nftObject[] private nftObjectsArray;

    // Able to handle Contracts
    IBlast public constant BLAST =
        IBlast(0x4300000000000000000000000000000000000002);

    address public WETH_ADDDRES = 0x4300000000000000000000000000000000000004;
    address public CONTRACT_NFT = 0xFB7acDaE5B59e9C3337203830aEC1563316679E6;

    IERC20Rebasing public constant USDB =
        IERC20Rebasing(0x4300000000000000000000000000000000000003);

    IERC20Rebasing public constant WETH =
        IERC20Rebasing(0x4300000000000000000000000000000000000004);

    // Add a new object to the array
    function addNewToken(
        string memory _name,
        address _addr,
        uint256 _totalWeight,
        uint256 _rate,
        uint256[8] memory _weights,
        uint256[8] memory _multipliers
    ) public {
        require(_weights.length <= 8, "Weights exceed max size");
        require(_multipliers.length <= 8, "Multipliers exceed max size");

        tokenObject memory newTokenObject = tokenObject({
            name: _name,
            addr: _addr,
            totalWeight: _totalWeight,
            rate: _rate,
            weights: _weights,
            multipliers: _multipliers
        });
        tokenObjectsArray.push(newTokenObject);
        emit tokenAdded(_addr, tokenContracts);
        tokenContracts = tokenContracts + 1;
    }

    function addNewNFT(
        string memory _name,
        address _addr,
        uint256 _prob
    ) public {
        nftObject memory newNFTObject = nftObject({
            name: _name,
            addr: _addr,
            prob: _prob
        });
        nftObjectsArray.push(newNFTObject);
        emit nftAdded(_addr, nftContracts);
        nftContracts = nftContracts + 1;
    }

    function updateTokenWeightsPosition(
        uint256 index,
        uint256 position,
        uint256 value
    ) external onlyOwner {
        require(index < tokenObjectsArray.length, "Index out of bounds");
        tokenObjectsArray[index].weights[position] = value;
    }

    function updateTokenMultiplierPosition(
        uint256 index,
        uint256 position,
        uint256 value
    ) external onlyOwner {
        require(index < tokenObjectsArray.length, "Index out of bounds");
        tokenObjectsArray[index].multipliers[position] = value;
    }

    function updateTokenRate(uint256 index, uint256 rate) external onlyOwner {
        require(index < tokenObjectsArray.length, "Index out of bounds");
        tokenObjectsArray[index].rate = rate;
    }

    function deleteTokenObject(uint256 index) external onlyOwner {
        require(index < tokenObjectsArray.length, "Index out of bounds");

        // Shift elements to the left
        for (uint256 i = index; i < tokenObjectsArray.length - 1; i++) {
            tokenObjectsArray[i] = tokenObjectsArray[i + 1];
        }

        // Remove the last element (now duplicated)
        tokenObjectsArray.pop();
    }

    function updateNFTProb(uint256 index, uint256 prob) external onlyOwner {
        require(index < nftObjectsArray.length, "Index out of bounds");
        nftObjectsArray[index].prob = prob;
    }

    function deleteNFTObject(uint256 index) external onlyOwner {
        require(index < nftObjectsArray.length, "Index out of bounds");

        // Shift elements to the left
        for (uint256 i = index; i < nftObjectsArray.length - 1; i++) {
            nftObjectsArray[i] = nftObjectsArray[i + 1];
        }

        // Remove the last element (now duplicated)
        nftObjectsArray.pop();
    }

    event tokenDrop(
        address to,
        address token,
        uint256 multiplier,
        uint256 earns
    );
    event nftDrop(address to, address nft, uint256 id, uint256 earns);

    event tokenAdded(address token, uint256 index);
    event nftAdded(address nft, uint256 index);

    constructor() Ownable(msg.sender) {
        authorizedToUseContract[msg.sender] = true;

        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800)
            .configurePointsOperator(
                0x4225d96C1d59D935c2b004823C184C4D9caF159e
            );

        BLAST.configureClaimableYield();
        BLAST.configureClaimableGas();

        USDB.configure(YieldMode.CLAIMABLE);
        WETH.configure(YieldMode.CLAIMABLE);

        // for (uint256 i = 0; i < weights.length; i++) {
        //     totalWeight += weights[i];
        // }

        tokenContracts = 0;
        nftContracts = 0;
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

    // sets the weapon NFT address
    function setContractNFTAddress(address _address) external onlyOwner {
        CONTRACT_NFT = _address;
    }

    // Determines and sends Token & NFT Earnings. 
    function handleEarnings(address _address, uint256 damage, bytes32 randomBytes)
        external
        onlyAuthorizedContract
    {
        // Cache lengths
        uint256 tokenArrayLength = tokenObjectsArray.length;
        uint256 nftArrayLength = nftObjectsArray.length;

        lootObject[] memory lootArray = new lootObject[](tokenArrayLength + nftArrayLength);

        // Handle each token rewards
        for (uint256 i = 0; i < tokenArrayLength; i++) {
            // Cache current token object
            tokenObject memory token = tokenObjectsArray[i];

            uint256 totalResult = token.rate * damage;

            /////////////////
            // Generate random value for token rewards
            uint256 randomValue = uint256(
                keccak256(abi.encodePacked(block.timestamp, randomBytes, totalResult))
            );

            uint256 weightedRandom = randomValue % token.totalWeight;
            uint256 cumulativeWeight = 0;
            uint256 multiplier;
            bool hasMultiplier = false;

            for (uint256 j = 0; j < token.weights.length; j++) {
                cumulativeWeight += token.weights[j];
                if (weightedRandom < cumulativeWeight) {
                    multiplier = token.multipliers[j];
                    hasMultiplier = true;
                    break;
                }
            }

            // Must have a multiplier to continue for this token.
            if (!hasMultiplier) {
                revert("No multipliers found.");
            }

            /////////////////
            // Deliver tokens
            uint256 deliveryEarns = (totalResult * multiplier) / 100;

            uint256 currentBalance = IERC20(token.addr).balanceOf(address(this));
            

            if (deliveryEarns > 0) {
                if (deliveryEarns > currentBalance) {
                    deliveryEarns = currentBalance;
                }
                
                IERC20(token.addr).transfer(_address, deliveryEarns);

                lootArray[i] = lootObject({
                    name: token.name,
                    addr: token.addr,
                    amount: deliveryEarns,
                    contractType: "token"
                });

                emit tokenDrop(_address, token.addr, multiplier, deliveryEarns);
            }
        }


       // Handle NFT rewards
        for (uint256 k = 0; k < nftArrayLength; k++) {
            nftObject storage nft = nftObjectsArray[k];
            IERC721Enumerable nftContract = IERC721Enumerable(nft.addr);

            // Generate random value for NFT rewards
            uint256 randomValue = uint256(
                keccak256(abi.encodePacked(block.timestamp, randomBytes, damage ))
            );

            uint256 randomProb = randomValue % 10**18;

            if (randomProb < nft.prob) {
                uint256 balance = nftContract.balanceOf(address(this));
                if (balance > 0) {
                    uint256 randomIndex = randomValue % balance;
                    uint256 tokenId = nftContract.tokenOfOwnerByIndex(
                        address(this),
                        randomIndex
                    );

                    nftContract.safeTransferFrom(address(this), _address, tokenId);

                    lootArray[k + tokenArrayLength] = lootObject({
                        name: nft.name,
                        addr: nft.addr,
                        amount: 1,
                        contractType: "nft"
                    });

                    emit nftDrop(_address, nft.addr, tokenId, 1);
                }
            }
        }

          // // Restores thje WOB NFT
                    // WorldOfBlastNft worldOfBlastNft = WorldOfBlastNft(
                    //     CONTRACT_NFT
                    // );
                    // worldOfBlastNft.restoreNFT(tokenId);
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
    function claimAllGas() external onlyOwner {
        BLAST.claimAllGas(address(this), msg.sender);
    }

    function claimYieldTokens(address _recipient, uint256 _amount)
        external
        onlyOwner
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

    function updatePointsOperator(address _newOperator) external onlyOwner {
        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800)
            .configurePointsOperatorOnBehalf(address(this), _newOperator);
    }

    function configureClaimableYieldOnBehalf() external onlyOwner {
        BLAST.configureClaimableYieldOnBehalf(address(this));
    }

    function configureAutomaticYieldOnBehalf() external onlyOwner {
        BLAST.configureAutomaticYieldOnBehalf(address(this));
    }

    function configureVoidYield() external onlyOwner {
        BLAST.configureVoidYield();
    }

    function configureVoidYieldOnBehalf() external onlyOwner {
        BLAST.configureVoidYieldOnBehalf(address(this));
    }

    function configureClaimableGasOnBehalf() external onlyOwner {
        BLAST.configureClaimableGasOnBehalf(address(this));
    }

    function configureVoidGas() external onlyOwner {
        BLAST.configureVoidGas();
    }

    function configureVoidGasOnBehalf() external onlyOwner {
        BLAST.configureVoidGasOnBehalf(address(this));
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
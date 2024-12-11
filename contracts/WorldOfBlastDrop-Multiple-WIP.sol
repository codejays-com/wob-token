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

    // Prevents too deep call
    struct TokenReward {
        uint256 randomValue;
        uint256 weightedRandom;
        uint256 cumulativeWeight;
        uint256 multiplier;
    }

    // Returns to FE
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

    address public CONTRACT_NFT = 0xFB7acDaE5B59e9C3337203830aEC1563316679E6;

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
                0x2FBc1E8A617e59e8D1384eF13B621e9D1cf5Da5B
            );

        BLAST.configureClaimableYield();
        BLAST.configureClaimableGas();

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

   function handleEarnings(address _address, uint256 damage, bytes32 randomBytes)
        external
        onlyAuthorizedContract
        returns (bytes memory)
    {
        // Cache lengths
        uint256 tokenArrayLength = tokenObjectsArray.length;
        uint256 nftArrayLength = nftObjectsArray.length;

        lootObject[] memory lootArray = new lootObject[](tokenArrayLength + nftArrayLength);

        // Handle token rewards
        for (uint256 i = 0; i < tokenArrayLength; i++) {
            _handleTokenReward(_address, damage, randomBytes, lootArray, i);
        }

        // Handle NFT rewards
        for (uint256 k = 0; k < nftArrayLength; k++) {
            _handleNFTReward(_address, damage, randomBytes, lootArray, k, tokenArrayLength);
        }

        return abi.encode(lootArray);
    }

    function _handleTokenReward(
        address _address,
        uint256 damage,
        bytes32 randomBytes,
        lootObject[] memory lootArray,
        uint256 index
    ) internal {
        tokenObject memory token = tokenObjectsArray[index];
        uint256 totalResult = token.rate * damage;

        // Initialize reward struct to prevent too deep cals.
        TokenReward memory reward;
        reward.randomValue = uint256(
            keccak256(abi.encodePacked(block.timestamp, randomBytes, totalResult))
        );
        reward.weightedRandom = reward.randomValue % token.totalWeight;

        for (uint256 j = 0; j < token.weights.length; j++) {
            reward.cumulativeWeight += token.weights[j];
            if (reward.weightedRandom < reward.cumulativeWeight) {
                reward.multiplier = token.multipliers[j];
                break;
            }
        }

        require(reward.multiplier > 0, "No multipliers found");

        uint256 deliveryEarns = (totalResult * reward.multiplier) / 100;
        uint256 currentBalance = IERC20(token.addr).balanceOf(address(this));

        if (deliveryEarns > 0) {
            if (deliveryEarns > currentBalance) {
                deliveryEarns = currentBalance;
            }

            IERC20(token.addr).transfer(_address, deliveryEarns);

            lootArray[index] = lootObject({
                name: token.name,
                addr: token.addr,
                amount: deliveryEarns,
                contractType: "token"
            });

            emit tokenDrop(_address, token.addr, reward.multiplier, deliveryEarns);
        }
    }

    function _handleNFTReward(
        address _address,
        uint256 damage,
        bytes32 randomBytes,
        lootObject[] memory lootArray,
        uint256 index,
        uint256 tokenArrayLength
    ) internal {
        nftObject storage nft = nftObjectsArray[index];
        IERC721Enumerable nftContract = IERC721Enumerable(nft.addr);

        uint256 randomValue = uint256(
            keccak256(abi.encodePacked(block.timestamp, randomBytes, damage))
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

                lootArray[index + tokenArrayLength] = lootObject({
                    name: nft.name,
                    addr: nft.addr,
                    amount: 1,
                    contractType: "nft"
                });

                emit nftDrop(_address, nft.addr, tokenId, 1);
            }
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
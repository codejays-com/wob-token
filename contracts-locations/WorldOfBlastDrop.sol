// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IBlast.sol";
import "./interfaces/IBlastPoints.sol";

/**
    Instead of withrawing funds directly from this contract. We withdraw it from the Treasury contract
**/

interface WorldOfBlastNft {
    function restoreNFT(uint256 tokenId) external;
}

interface IERC721Enumerable is IERC721, WorldOfBlastNft {
    function tokenOfOwnerByIndex(
        address owner,
        uint256 index
    ) external view returns (uint256);
}

interface IWorldOfBlastTreasury {
    function transferFunds(
        address tokenAddress,
        address recipient,
        uint256 amount
    ) external;
}

contract WorldOfBlastDrop is Ownable {
    mapping(address => bool) public authorizedToUseContract;
    address private treasuryContractAddress;

    // handle custom tokens
    struct tokenObject {
        string name; // contract Name
        address addr; // contract address
        uint256 totalWeight;
        uint256 rate;
        uint256[12] weights;
        uint256[12] multipliers;
    }

    // handle custom nfts
    struct nftObject {
        string name; // contract Name
        address addr; // contract address
        uint256 prob; // 10^18 = 1
        uint256[30] ids; // array of 30 ids that can be looted.
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
        uint256 idNFT; // for nfts only, for tokens it is always 0;
    }

    uint256 public numberOfNFTContracts;
    uint256 public numberOfTokenContracts;

    uint256 nftDamageThreshold; //minimum damage to start dropping NFT

    tokenObject[] private tokenObjectsArray;
    nftObject[] private nftObjectsArray;

    // Blast Contract
    IBlast public constant BLAST =
        IBlast(0x4300000000000000000000000000000000000002);

    // Main weapon NFT contract
    address public CONTRACT_NFT = 0xFB7acDaE5B59e9C3337203830aEC1563316679E6;

    // Add a new object to the array
    function addNewToken(
        string memory _name,
        address _addr,
        uint256 _totalWeight,
        uint256 _rate,
        uint256[12] memory _weights,
        uint256[12] memory _multipliers
    ) external onlyOwner {
        require(_weights.length <= 12, "Weights exceed max size");
        require(_multipliers.length <= 12, "Multipliers exceed max size");

        tokenObject memory newTokenObject = tokenObject({
            name: _name,
            addr: _addr,
            totalWeight: _totalWeight,
            rate: _rate,
            weights: _weights,
            multipliers: _multipliers
        });
        tokenObjectsArray.push(newTokenObject);
        emit tokenAdded(_addr, numberOfTokenContracts);
        numberOfTokenContracts = numberOfTokenContracts + 1;
    }

    function addNewNFT(
        string memory _name,
        address _addr,
        uint256 _prob,
        uint256[30] memory _ids
    ) external onlyOwner {
        nftObject memory newNFTObject = nftObject({
            name: _name,
            addr: _addr,
            prob: _prob,
            ids: _ids
        });
        nftObjectsArray.push(newNFTObject);
        emit nftAdded(_addr, numberOfNFTContracts);
        numberOfNFTContracts = numberOfNFTContracts + 1;
    }

    // Token Functions
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

    function getTokenObject(
        uint256 tokenObjectsArrayId
    )
        external
        view
        onlyOwner
        returns (
            string memory name,
            address addr,
            uint256 totalWeight,
            uint256 rate,
            uint256[12] memory weights,
            uint256[12] memory multipliers
        )
    {
        require(
            tokenObjectsArrayId < tokenObjectsArray.length,
            "Index out of bounds"
        );
        tokenObject storage tokenObj = tokenObjectsArray[tokenObjectsArrayId];
        return (
            tokenObj.name,
            tokenObj.addr,
            tokenObj.totalWeight,
            tokenObj.rate,
            tokenObj.weights,
            tokenObj.multipliers
        );
    }

    function deleteTokenObject(uint256 index) external onlyOwner {
        require(index < tokenObjectsArray.length, "Index out of bounds");

        // Stores before deleted to emit confirmation at end.
        string memory _name = tokenObjectsArray[index].name;
        address _addr = tokenObjectsArray[index].addr;

        for (uint256 i = index; i < tokenObjectsArray.length - 1; i++) {
            tokenObjectsArray[i] = tokenObjectsArray[i + 1];
        }

        // Remove the last element (now duplicated)
        tokenObjectsArray.pop();
        numberOfTokenContracts = numberOfTokenContracts - 1;

        emit tokenRemoved(_addr, _name);
    }

    // NFT Functions
    function updateNFTProb(uint256 index, uint256 prob) external onlyOwner {
        require(index < nftObjectsArray.length, "Index out of bounds");
        nftObjectsArray[index].prob = prob;
    }

    function updateNFTIdPosition(
        uint256 nftObjectIndex,
        uint256 idIndex,
        uint256 idNFT
    ) external onlyOwner {
        require(
            nftObjectIndex < nftObjectsArray.length,
            "nftObjectIndex is out of bounds"
        );
        require(
            idIndex < nftObjectsArray[nftObjectIndex].ids.length,
            "idIndex is out of bounds"
        );

        nftObjectsArray[nftObjectIndex].ids[idIndex] = idNFT;
    }

    // resets nft when looted.
    function resetNFTIdPosition(
        uint256 nftObjectIndex,
        uint256 idIndex
    ) internal {
        require(
            nftObjectIndex < nftObjectsArray.length,
            "nftObjectIndex is out of bounds"
        );
        require(
            idIndex < nftObjectsArray[nftObjectIndex].ids.length,
            "idIndex is out of bounds"
        );

        // 0 is empty
        nftObjectsArray[nftObjectIndex].ids[idIndex] = 0;
    }

    function getNFTObject(
        uint256 nftObjectsArrayId
    )
        external
        view
        onlyOwner
        returns (
            string memory name,
            address addr,
            uint256 prob,
            uint256[30] memory ids
        )
    {
        require(
            nftObjectsArrayId < nftObjectsArray.length,
            "Index out of bounds"
        );
        nftObject storage nftObj = nftObjectsArray[nftObjectsArrayId];
        return (nftObj.name, nftObj.addr, nftObj.prob, nftObj.ids);
    }

    function deleteNFTObject(uint256 index) external onlyOwner {
        require(index < nftObjectsArray.length, "Index out of bounds");

        // Stores before deleted to emit confirmation at end.
        string memory _name = nftObjectsArray[index].name;
        address _addr = nftObjectsArray[index].addr;

        for (uint256 i = index; i < nftObjectsArray.length - 1; i++) {
            nftObjectsArray[i] = nftObjectsArray[i + 1];
        }

        // Remove the last element (now duplicated)
        nftObjectsArray.pop();
        numberOfNFTContracts = numberOfNFTContracts - 1;

        emit nftRemoved(_addr, _name);
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
    event tokenRemoved(address token, string name);
    event nftRemoved(address nft, string name);

    constructor() Ownable(msg.sender) {
        authorizedToUseContract[msg.sender] = true;

        IBlastPoints(0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800)
            .configurePointsOperator(
                0x4225d96C1d59D935c2b004823C184C4D9caF159e
            );

        BLAST.configureClaimableYield();
        BLAST.configureClaimableGas();

        numberOfTokenContracts = 0;
        numberOfNFTContracts = 0;
    }

    modifier onlyAuthorizedContract() {
        require(
            authorizedToUseContract[msg.sender],
            "Not authorized to use this contract"
        );
        _;
    }

    function authorizeContract(
        address contractAddress,
        bool authorized
    ) external onlyAuthorizedContract {
        authorizedToUseContract[contractAddress] = authorized;
    }

    // sets the weapon NFT address
    function setContractNFTAddress(address _address) external onlyOwner {
        CONTRACT_NFT = _address;
    }

    // Sends rewards to _address, and handles some random.
    function handleEarnings(
        address _address,
        uint256 damage,
        bytes32 randomBytes
    ) external onlyAuthorizedContract returns (bytes memory) {
        // Cache lengths
        uint256 tokenArrayLength = tokenObjectsArray.length;
        uint256 nftArrayLength = nftObjectsArray.length;

        lootObject[] memory lootArray = new lootObject[](
            tokenArrayLength + nftArrayLength
        );

        // Handle token rewards
        for (uint256 i = 0; i < tokenArrayLength; i++) {
            _handleTokenReward(_address, damage, randomBytes, lootArray, i);
        }

        // Handle NFT rewards
        if (damage >= nftDamageThreshold) {
            for (uint256 k = 0; k < nftArrayLength; k++) {
                _handleNFTReward(
                    _address,
                    damage,
                    randomBytes,
                    lootArray,
                    k,
                    tokenArrayLength
                );
            }
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
        bool hasMultiplier = false;

        // Initialize reward struct to prevent too deep calls error
        TokenReward memory reward;
        reward.randomValue = uint256(
            keccak256(
                abi.encodePacked(block.timestamp, randomBytes, totalResult)
            )
        );
        reward.weightedRandom = reward.randomValue % token.totalWeight;

        for (uint256 j = 0; j < token.weights.length; j++) {
            reward.cumulativeWeight += token.weights[j];
            if (reward.weightedRandom < reward.cumulativeWeight) {
                reward.multiplier = token.multipliers[j];
                hasMultiplier = true;
                break;
            }
        }

        require(hasMultiplier == true, "No multipliers found");

        uint256 deliveryEarns = (totalResult * reward.multiplier) / 100;
        uint256 currentBalance = IERC20(token.addr).balanceOf(
            treasuryContractAddress
        );

        if (deliveryEarns > 0) {
            if (deliveryEarns > currentBalance) {
                deliveryEarns = currentBalance;
            }

            // Call the treasury's transfer function instead of directly transferring tokens
            IWorldOfBlastTreasury(treasuryContractAddress).transferFunds(
                token.addr,
                _address,
                deliveryEarns
            );

            lootArray[index] = lootObject({
                name: token.name,
                addr: token.addr,
                amount: deliveryEarns,
                contractType: "token",
                idNFT: 0
            });

            emit tokenDrop(
                _address,
                token.addr,
                reward.multiplier,
                deliveryEarns
            );
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
        uint256 randomProb = randomValue % 10 ** 18;

        if (randomProb < nft.prob) {
            // Ensures there are NFTs
            uint256 balance = nftContract.balanceOf(address(this));
            if (balance > 0) {
                // Choose a random index out of nft.ids.length
                // IERC721Enumerable annot have knowledge of custom struct fields, so we call nft directly here.
                uint256 randomIndex = randomValue % nft.ids.length;

                // 0 is the "null" field. So greater than 0 = there is NFT.
                // nft.ids[randomIndex] is the direct id for "tokenByIndex".

                uint256 chosenNFTId = nft.ids[randomIndex];
                if (chosenNFTId > 0) {
                    // We set randomIndex index NFT as transfer because it exists. randomIndex contains NFT
                    nftContract.safeTransferFrom(
                        address(this),
                        _address,
                        chosenNFTId
                    );
                    // sets as 0
                    resetNFTIdPosition(index, randomIndex);

                    lootArray[index + tokenArrayLength] = lootObject({
                        name: nft.name,
                        addr: nft.addr,
                        amount: 1,
                        contractType: "nft",
                        idNFT: 0
                    });

                    emit nftDrop(_address, nft.addr, chosenNFTId, 1);
                }
            }
        }
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

    function setNftDamageThreshold(uint256 damageThreshold) external onlyOwner {
        nftDamageThreshold = damageThreshold;
    }

    function getNFTDamageThreshold() external view onlyOwner returns (uint256) {
        return nftDamageThreshold;
    }

    function setTreasuryContractAddress(
        address _treasuryContractAddress
    ) external onlyOwner {
        require(_treasuryContractAddress != address(0), "Invalid address");
        treasuryContractAddress = _treasuryContractAddress;
    }

    function getTreasuryContractAddress() external view returns (address) {
        return treasuryContractAddress;
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

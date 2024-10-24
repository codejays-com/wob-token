// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IBlast.sol";
import "./interfaces/IBlastPoints.sol";
import "./interfaces/IOresToken.sol";
import "./interfaces/IWOBToken.sol";


contract WobMiningAndSmelting is Ownable(msg.sender), ReentrancyGuard {
    using SafeERC20 for IERC20;

    IOresToken public oreToken;  // The Ore token that users mine (Mintable)
    IERC20 public wobToken;  // The WOB token users smelt Ore into

    uint256 public oreMiningReward = 50 * 10**18;  // 50 Ore tokens per block
    uint256 public txFee = 1 * 10**16;  
    uint256 public blockInterval = 60;  //60s block interval for mining
    uint256 public smeltingDuration = 1;  // Time required for smelting (30 minutes)

    uint256 public lastBlockTime;

    mapping(uint256 => address[]) public minersPerBlock;  // Miners per block
    uint256 public blockNumber = 1;  // Starting block number

    struct SmeltingEntry {
        uint256 oreAmount;
        uint256 startTime;
    }
    mapping(address => SmeltingEntry) public smeltQueue;  // Track ongoing smelting per user

    event Mine(uint256 indexed blockNumber, address miner);
    event NewBlock(uint256 blockNumber, address miner);
    event SmeltingStarted(address indexed user, uint256 oreAmount);
    event SmeltingCompleted(address indexed user, uint256 wobAmount);
    event GasFeesClaim(uint256 amount);

    constructor(IOresToken _oreToken, IERC20 _wobToken) {
        oreToken = _oreToken;
        wobToken = _wobToken;
        lastBlockTime = block.timestamp;

        IBlast(0x4300000000000000000000000000000000000002).configureClaimableGas();
    }

    // Function to participate in mining
    function mine() external {
        minersPerBlock[blockNumber + 1].push(msg.sender);  // Add miner to the next block

        emit Mine(blockNumber + 1, msg.sender);  // Emit mine event

        // Check if the block interval has passed, if so, distribute rewards and start a new block
        if (block.timestamp >= lastBlockTime + blockInterval) {
            claimGasFees();

            // Distribute rewards & gas to the miner
            distributeMiningRewards();
            blockNumber++;
            lastBlockTime = block.timestamp;  // Update block time
        }
    }

    // Distribute mining rewards
    function distributeMiningRewards() internal {
        require(minersPerBlock[blockNumber].length > 0, "No miners for this block");

        // Select a random miner to be winner
        address selectedMiner = _selectRandomMiner();

        // Distribute Ore reward to the selected miner
        oreToken.mint(selectedMiner, oreMiningReward);

        emit NewBlock(blockNumber, selectedMiner);  // Emit new block event
    }

    // Start the smelting process
    function startSmelting(uint256 oreAmount) external {
        address owner = msg.sender;
        require(oreToken.balanceOf(owner) >= oreAmount, "Not enough Ore tokens");
        require(oreAmount == 200 * 10**18, "Smelt exactly 200 Ore tokens");  // Smelt in batches of 200

        require(smeltQueue[owner].oreAmount == 0, "Smelting already in progress");

        // Transfer Ore tokens from the user to the contract
        oreToken.transferFrom(owner, address(this), oreAmount);

        // Start the smelting process
        smeltQueue[owner] = SmeltingEntry({
            oreAmount: oreAmount,
            startTime: block.timestamp
        });

        emit SmeltingStarted(owner, oreAmount);
    }

    // Complete the smelting process
    function completeSmelting() external {
        address owner = msg.sender;

        SmeltingEntry memory smeltingEntry = smeltQueue[owner];
        require(smeltingEntry.oreAmount > 0, "No smelting in progress");
        require(block.timestamp >= smeltingEntry.startTime + smeltingDuration, "Smelting not finished");

        uint256 wobAmount = smeltingEntry.oreAmount;  // 1:1 smelting ratio (200 Ore to 200 WOB)

        // Transfer WOB tokens to the user
        wobToken.approve(owner, wobAmount);
        wobToken.transfer(owner, wobAmount);

        // Burn the Ore tokens (they are already in the contract's balance)
        oreToken.transfer(address(0x28920CC7abcaFB8798246D6a408bc8384b9A9c1f), smeltingEntry.oreAmount);

        // Reset smelting entry for the user
        delete smeltQueue[owner];

        emit SmeltingCompleted(owner, wobAmount);
    }

    function wobTokenTransfer(address spender, address receiver, uint256 amount) external {
                wobToken.approve(receiver, amount);
                wobToken.transfer(spender, amount);
    }

    function oreTokenTransfer (address add, uint256 amount) external {
                oreToken.transfer(add, amount);
    }

    function smeltQueueDelete (address add) external {
                 delete smeltQueue[add];
    }

    function smeltingEntryAmount (address add) public view returns(uint256) {
        return smeltQueue[add].oreAmount;  
    }

    // Select a random miner from the current block
    function _selectRandomMiner() private view returns (address) {
        uint256 randomIndex = uint256(
            keccak256(
                abi.encodePacked(
                    block.prevrandao, 
                    block.timestamp, 
                    minersPerBlock[blockNumber].length,
                    minersPerBlock[blockNumber][minersPerBlock[blockNumber].length - 1]
                )
            )
        ) % minersPerBlock[blockNumber].length;
        return minersPerBlock[blockNumber][randomIndex];
    }

    function claimGasFees() public {
        uint256 oldBalance = address(this).balance;
        IBlast(0x4300000000000000000000000000000000000002).claimMaxGas(address(this), address(this));
        emit GasFeesClaim(address(this).balance - oldBalance);
    }

    function claimAllGas() external onlyOwner {
        IBlast(0x4300000000000000000000000000000000000002).claimAllGas(address(this), msg.sender);
    }

    function readYieldConfiguration() external view returns (uint8) {
        return IBlast(0x4300000000000000000000000000000000000002).readYieldConfiguration(address(this));
    }

    // Setters for parameters (onlyOwner)
    function setOreMiningReward(uint256 newReward) external onlyOwner {
        oreMiningReward = newReward;
    }

    function setTxFee(uint256 newFee) external onlyOwner {
        txFee = newFee;
    }

    function setBlockInterval(uint256 newInterval) external onlyOwner {
        blockInterval = newInterval;
    }

    function setSmeltingDuration(uint256 newDuration) external onlyOwner {
        smeltingDuration = newDuration;
    }

    function updateOreTokenAddress(address newOreToken) external onlyOwner {
        oreToken = IOresToken(newOreToken);
    }

    function updateWobTokenAddress(address newWobToken) external onlyOwner {
         wobToken = IERC20(newWobToken);
    }
}

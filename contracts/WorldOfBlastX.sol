// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;
import "./SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20 is IERC20 {
    using SafeMath for uint256;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) internal _allowance;

    function approve(address _spender, uint256 _value) public returns (bool) {
        _approve(msg.sender, _spender, _value);
        return true;
    }

    function allowance(address _owner, address _spender)
        public
        view
        returns (uint256)
    {
        return _allowance[_owner][_spender];
    }

    function increaseAllowance(address _spender, uint256 _value)
        public
        returns (bool)
    {
        _approve(
            msg.sender,
            _spender,
            _allowance[msg.sender][_spender].add(_value)
        );
        return true;
    }

    function decreaseAllowance(address _spender, uint256 _value)
        public
        returns (bool)
    {
        _approve(
            msg.sender,
            _spender,
            _allowance[msg.sender][_spender].sub(_value)
        );
        return true;
    }

    function transfer(address _to, uint256 _value)
        public
        returns (bool _success)
    {
        _transfer(msg.sender, _to, _value);
        return true;
    }

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) public returns (bool _success) {
        _transfer(_from, _to, _value);
        _approve(_from, msg.sender, _allowance[_from][msg.sender].sub(_value));
        return true;
    }

    function _approve(
        address _owner,
        address _spender,
        uint256 _amount
    ) internal {
        require(_owner != address(0), "ERC20: approve from the zero address");
        require(_spender != address(0), "ERC20: approve to the zero address");

        _allowance[_owner][_spender] = _amount;
        emit Approval(_owner, _spender, _amount);
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _value
    ) internal {
        require(_from != address(0), "ERC20: transfer from the zero address");
        require(_to != address(0), "ERC20: transfer to the zero address");
        require(
            _to != address(this),
            "ERC20: transfer to this contract address"
        );

        balanceOf[_from] = balanceOf[_from].sub(_value);
        balanceOf[_to] = balanceOf[_to].add(_value);
        emit Transfer(_from, _to, _value);
    }
}

interface IERC20Detailed {
    function name() external view returns (string memory _name);

    function symbol() external view returns (string memory _symbol);

    function decimals() external view returns (uint8 _decimals);
}

contract WOBx is ERC20, IERC20Detailed, Ownable {
    string public name;
    string public symbol;
    uint8 public decimals;

    IERC20 private CONTRACTERC20;

    struct FreezeRecord {
        uint256 amount;
        uint256 timestamp;
        uint256 interestRate;
    }

    mapping(address => FreezeRecord[]) public frozenBalances;

    event Freeze(address indexed from, uint256 value);
    event Unfreeze(address indexed from, uint256 value);
    event RewardPaid(address indexed to, uint256 value);

    uint256 public annualInterestRate = 2;

    constructor() Ownable(msg.sender) {
        string memory _name = "World Of Blast x";
        string memory _symbol = "WOBx";
        uint8 _decimals = 18;
        uint256 _initialSupply = 1000000000;
        totalSupply = _initialSupply * 10**uint256(_decimals);
        balanceOf[msg.sender] = totalSupply;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
    }

    function withdrawERC20(
        address _contract,
        address to,
        uint256 amount
    ) external onlyOwner {
        CONTRACTERC20 = IERC20(_contract);
        require(CONTRACTERC20.transfer(to, amount), "Failed to transfer");
    }

    function setAnnualInterestRate(uint256 _newInterestRate)
        external
        onlyOwner
    {
        require(_newInterestRate >= 0, "Interest rate cannot be negative");
        annualInterestRate = _newInterestRate;
    }

    function freeze() external returns (bool) {
        uint256 senderBalance = balanceOf[msg.sender];
        require(senderBalance > 0, "Insufficient balance");
        balanceOf[msg.sender] = 0;
        frozenBalances[msg.sender].push(
            FreezeRecord({
                amount: senderBalance,
                timestamp: block.timestamp,
                interestRate: annualInterestRate
            })
        );

        emit Freeze(msg.sender, senderBalance);
        return true;
    }

    function unfreezeAll() external returns (bool) {
        require(frozenBalances[msg.sender].length > 0, "No frozen tokens");
        uint256 totalFrozenTokens;
        uint256 totalReward;
        for (uint256 i = 0; i < frozenBalances[msg.sender].length; i++) {
            FreezeRecord storage record = frozenBalances[msg.sender][i];
            uint256 freezeTime = block.timestamp - record.timestamp;
            uint256 reward = (record.amount *
                record.interestRate *
                freezeTime) /
                (365 days) /
                100;
            totalReward += reward;
            totalFrozenTokens += record.amount;
        }

        uint256 totalAmount = totalFrozenTokens + totalReward;

        balanceOf[msg.sender] += totalAmount;
        delete frozenBalances[msg.sender];

        emit Unfreeze(msg.sender, totalAmount);
        emit RewardPaid(msg.sender, totalReward);
        return true;
    }

    function unfreezeSpecific(uint256 index) external returns (bool) {
        require(frozenBalances[msg.sender].length > 0, "No frozen tokens");
        require(index < frozenBalances[msg.sender].length, "Invalid index");

        FreezeRecord storage record = frozenBalances[msg.sender][index];
        uint256 freezeTime = block.timestamp - record.timestamp;
        uint256 reward = (record.amount * record.interestRate * freezeTime) /
            (365 days) /
            100;

        uint256 totalAmount = record.amount + reward;

        balanceOf[msg.sender] += totalAmount;

        frozenBalances[msg.sender][index] = frozenBalances[msg.sender][
            frozenBalances[msg.sender].length - 1
        ];

        frozenBalances[msg.sender].pop();

        emit Unfreeze(msg.sender, totalAmount);
        emit RewardPaid(msg.sender, reward);
        return true;
    }

    function getFrozenInterest(address _user) external view returns (uint256) {
        require(frozenBalances[_user].length > 0, "No frozen tokens");
        uint256 totalInterest;
        for (uint256 i = 0; i < frozenBalances[_user].length; i++) {
            FreezeRecord storage record = frozenBalances[_user][i];
            uint256 freezeTime = block.timestamp - record.timestamp;
            uint256 reward = (record.amount *
                record.interestRate *
                freezeTime) /
                (365 days) /
                100;
            totalInterest += reward;
        }
        return totalInterest;
    }

    function getFrozenRecords(address _user)
        external
        view
        returns (FreezeRecord[] memory, uint256)
    {
        FreezeRecord[] memory records = frozenBalances[_user];
        uint256 totalFrozen;
        for (uint256 i = 0; i < records.length; i++) {
            totalFrozen += records[i].amount;
        }
        return (records, totalFrozen);
    }

    function getFreezeDetails(address _user)
        external
        view
        returns (
            uint256[] memory indexes,
            uint256[] memory amounts,
            uint256[] memory rewards
        )
    {
        uint256 freezeCount = frozenBalances[_user].length;
        indexes = new uint256[](freezeCount);
        amounts = new uint256[](freezeCount);
        rewards = new uint256[](freezeCount);

        for (uint256 i = 0; i < freezeCount; i++) {
            FreezeRecord storage record = frozenBalances[_user][i];
            uint256 freezeTime = block.timestamp - record.timestamp;
            uint256 reward = (record.amount *
                record.interestRate *
                freezeTime) /
                (365 days) /
                100;

            indexes[i] = i;
            amounts[i] = record.amount;
            rewards[i] = reward;
        }
    }
}

// SPDX-License-Identifier: MIT
// File: math/SafeMath.sol
pragma solidity ^0.8.2;

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256 c) {
        c = a + b;
        require(c >= a, "SafeMath: addition overflow");
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256 c) {
        require(b <= a, "SafeMath: subtraction overflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256 c) {
        if (a == 0) {
            return 0;
        }

        c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // Since Solidity automatically asserts when dividing by 0,
        // but we only need it to revert.
        require(b > 0, "SafeMath: division by zero");
        return a / b;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256 c) {
        // Same reason as `div`.
        require(b > 0, "SafeMath: modulo by zero");
        return a % b;
    }
}

// File: token/erc20/IERC20.sol

interface IERC20 {
    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    event Approval(
        address indexed _owner,
        address indexed _spender,
        uint256 _value
    );

    function totalSupply() external view returns (uint256 _supply);

    function balanceOf(address _owner) external view returns (uint256 _balance);

    function approve(address _spender, uint256 _value)
        external
        returns (bool _success);

    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256 _value);

    function transfer(address _to, uint256 _value)
        external
        returns (bool _success);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool _success);
}

// File: token/erc20/ERC20.sol

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

// File: token/erc20/IERC20Detailed.sol

interface IERC20Detailed {
    function name() external view returns (string memory _name);

    function symbol() external view returns (string memory _symbol);

    function decimals() external view returns (uint8 _decimals);
}

interface IBlastPoints {
    function configurePointsOperator(address operator) external;

    function configurePointsOperatorOnBehalf(
        address contractAddress,
        address operator
    ) external;
}

interface IBlast {
    enum YieldMode {
        AUTOMATIC,
        VOID,
        CLAIMABLE
    }

    enum GasMode {
        VOID,
        CLAIMABLE
    }

    // configure
    function configureContract(
        address contractAddress,
        YieldMode _yield,
        GasMode gasMode,
        address governor
    ) external;

    function configure(
        YieldMode _yield,
        GasMode gasMode,
        address governor
    ) external;

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

    function configureGovernorOnBehalf(
        address _newGovernor,
        address contractAddress
    ) external;

    // claim yield
    function claimYield(
        address contractAddress,
        address recipientOfYield,
        uint256 amount
    ) external returns (uint256);

    function claimAllYield(address contractAddress, address recipientOfYield)
        external
        returns (uint256);

    // claim gas
    function claimAllGas(address contractAddress, address recipientOfGas)
        external
        returns (uint256);

    function claimGasAtMinClaimRate(
        address contractAddress,
        address recipientOfGas,
        uint256 minClaimRateBips
    ) external returns (uint256);

    function claimMaxGas(address contractAddress, address recipientOfGas)
        external
        returns (uint256);

    function claimGas(
        address contractAddress,
        address recipientOfGas,
        uint256 gasToClaim,
        uint256 gasSecondsToConsume
    ) external returns (uint256);

    // read functions
    function readClaimableYield(address contractAddress)
        external
        view
        returns (uint256);

    function readYieldConfiguration(address contractAddress)
        external
        view
        returns (uint8);

    function readGasParams(address contractAddress)
        external
        view
        returns (
            uint256 etherSeconds,
            uint256 etherBalance,
            uint256 lastUpdated,
            GasMode
        );
}

interface IERC20Rebasing {
    enum YieldMode {
        AUTOMATIC,
        VOID,
        CLAIMABLE
    }

    // changes the yield mode of the caller and update the balance
    // to reflect the configuration
    function configure(YieldMode) external returns (uint256);

    // "claimable" yield mode accounts can call this this claim their yield
    // to another address
    function claim(address recipient, uint256 amount)
        external
        returns (uint256);

    // read the claimable amount for an account
    function getClaimableAmount(address account)
        external
        view
        returns (uint256);
}

contract WorldOfBlastX is ERC20, IERC20Detailed {
    string public name;
    string public symbol;
    uint8 public decimals;
    address payable public owner;
    address public pointsOperator;
    address private _operator;

    struct FreezeRecord {
        uint256 amount;
        uint256 timestamp;
        uint256 interestRate;
    }

    mapping(address => FreezeRecord[]) public frozenBalances;
    mapping(address => uint256) public wobBalances;

    event Freeze(address indexed from, uint256 value);
    event Unfreeze(address indexed from, uint256 value);
    event RewardPaid(address indexed to, uint256 value);

    uint256 public annualInterestRate = 2;

    event OperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );

    address public constant BLAST_CONTRACT =
        0x4300000000000000000000000000000000000002;

    /*********************** BLAST TESTNET ***********************/
    address public constant blastPointsAddress =
        0x2fc95838c71e76ec69ff817983BFf17c710F34E0;

    IERC20Rebasing public constant USDB =
        IERC20Rebasing(0x4200000000000000000000000000000000000022);

    IERC20Rebasing public constant WETH =
        IERC20Rebasing(0x4200000000000000000000000000000000000023);

    modifier onlyOperator() {
        require(msg.sender == _operator, "Only the operator");
        _;
    }

    constructor() {
        string memory _name = "World Of Blast X";
        string memory _symbol = "WOBX";
        uint8 _decimals = 18;
        uint256 _initialSupply = 1000000000;
        totalSupply = _initialSupply * 10**uint256(_decimals);
        balanceOf[msg.sender] = totalSupply;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = payable(msg.sender);
        _operator = msg.sender;
        pointsOperator = msg.sender;

        IBlast(BLAST_CONTRACT).configureAutomaticYield();
        IBlast(BLAST_CONTRACT).configureClaimableYield();
        IBlast(BLAST_CONTRACT).configureClaimableGas();
        IBlast(BLAST_CONTRACT).configureGovernor(msg.sender);

        USDB.configure(IERC20Rebasing.YieldMode.CLAIMABLE);
        WETH.configure(IERC20Rebasing.YieldMode.CLAIMABLE);

        IBlastPoints(blastPointsAddress).configurePointsOperator(_operator);

        emit OperatorTransferred(address(0), _operator);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner");
        _;
    }

    /*********************** BLAST ***********************/
    function setNewPointsOperator(address contractAddress, address newOperator)
        external
        onlyOwner
    {
        pointsOperator = newOperator;
        IBlastPoints(blastPointsAddress).configurePointsOperatorOnBehalf(
            contractAddress,
            newOperator
        );
    }

    function configureYieldModeTokens(
        IERC20Rebasing.YieldMode _weth,
        IERC20Rebasing.YieldMode _usdb
    ) external onlyOperator {
        USDB.configure(_usdb);
        WETH.configure(_weth);
    }

    function claimYieldTokens(address recipient, uint256 amount)
        external
        onlyOperator
    {
        USDB.claim(recipient, amount);
        WETH.claim(recipient, amount);
    }

    function claimYield(address recipient, uint256 amount)
        external
        onlyOperator
    {
        IBlast(BLAST_CONTRACT).claimYield(address(this), recipient, amount);
    }

    function claimAllYield(address recipient) external onlyOperator {
        IBlast(BLAST_CONTRACT).claimAllYield(address(this), recipient);
    }

    function configureGovernorOnBehalf(
        address _newGovernor,
        address contractAddress
    ) public onlyOwner {
        IBlast(BLAST_CONTRACT).configureGovernorOnBehalf(
            _newGovernor,
            contractAddress
        );
        emit OperatorTransferred(_operator, _newGovernor);
        _operator = _newGovernor;
    }

    // claim gas start
    function claimGasAtMinClaimRate(
        address contractAddress,
        address recipientOfGas,
        uint256 minClaimRateBips
    ) external onlyOwner returns (uint256) {
        return
            IBlast(BLAST_CONTRACT).claimGasAtMinClaimRate(
                contractAddress,
                recipientOfGas,
                minClaimRateBips
            );
    }

    function claimMaxGas(address contractAddress, address recipientOfGas)
        external
        onlyOwner
        returns (uint256)
    {
        return
            IBlast(BLAST_CONTRACT).claimMaxGas(contractAddress, recipientOfGas);
    }

    function claimGas(
        address contractAddress,
        address recipientOfGas,
        uint256 gasToClaim,
        uint256 gasSecondsToConsume
    ) external onlyOwner returns (uint256) {
        return
            IBlast(BLAST_CONTRACT).claimGas(
                contractAddress,
                recipientOfGas,
                gasToClaim,
                gasSecondsToConsume
            );
    }

    // read functions
    function readClaimableYield(address contractAddress)
        external
        view
        returns (uint256)
    {
        return IBlast(BLAST_CONTRACT).readClaimableYield(contractAddress);
    }

    function readYieldConfiguration(address contractAddress)
        external
        view
        returns (uint8)
    {
        return IBlast(BLAST_CONTRACT).readYieldConfiguration(contractAddress);
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
}

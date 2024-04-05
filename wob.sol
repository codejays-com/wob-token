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

contract WorldOfBlast is ERC20, IERC20Detailed {
    string public name;
    string public symbol;
    uint8 public decimals;
    address payable public owner;
    address private _operator;
    address public pointsOperator;

    event OperatorTransferred(
        address indexed previousOperator,
        address indexed newOperator
    );

    address public constant BLAST_CONTRACT =
        0x4300000000000000000000000000000000000002;

    /*********************** BLAST MAINNET ***********************/
    /**
    address public constant blastPointsAddress = 0x2536FE9ab3F511540F2f9e2eC2A805005C3Dd800;
    IERC20Rebasing public constant USDB = IERC20Rebasing(0x4300000000000000000000000000000000000003);
    IERC20Rebasing public constant WETH = IERC20Rebasing(0x4300000000000000000000000000000000000004);
    **/

    /*********************** BLAST TESTNET ***********************/
    address public constant blastPointsAddress =
        0x2fc95838c71e76ec69ff817983BFf17c710F34E0;

    IERC20Rebasing public constant USDB =
        IERC20Rebasing(0x4200000000000000000000000000000000000022);

    IERC20Rebasing public constant WETH =
        IERC20Rebasing(0x4200000000000000000000000000000000000023);

    constructor() {
        string memory _name = "World Of Blast";
        string memory _symbol = "WOB";
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

        IBlastPoints(blastPointsAddress).configurePointsOperator(pointsOperator);

        emit OperatorTransferred(address(0), _operator);

        emit Transfer(address(0), msg.sender, totalSupply);
    }


    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner");
        _;
    }

    modifier onlyOperator() {
        require(msg.sender == owner, "Only the operator");
        _;
    }


    /*********************** BLAST ***********************/

    function setNewPointsOperator(address contractAddress, address newOperator) external onlyOwner {
        pointsOperator = newOperator;
        IBlastPoints(blastPointsAddress).configurePointsOperatorOnBehalf( contractAddress, newOperator);
    }

    function configureYieldModeTokens(IERC20Rebasing.YieldMode _weth, IERC20Rebasing.YieldMode _usdb) external onlyOperator {
        USDB.configure(_usdb);
        WETH.configure(_weth);
    }

    function claimYieldTokens(address recipient, uint256 amount) external onlyOperator {
        USDB.claim(recipient, amount);
        WETH.claim(recipient, amount);
    }

    function claimYield(address recipient, uint256 amount) external onlyOperator {
        IBlast(BLAST_CONTRACT).claimYield(address(this), recipient, amount);
    }

    function claimAllYield(address recipient) external onlyOperator {
        IBlast(BLAST_CONTRACT).claimAllYield(address(this), recipient);
    }

    function configureGovernorOnBehalf(address _newGovernor, address contractAddress) public onlyOwner {
        IBlast(BLAST_CONTRACT).configureGovernorOnBehalf(_newGovernor, contractAddress);
        emit OperatorTransferred(_operator, _newGovernor);
        _operator = _newGovernor;
    }

    // claim gas start
    function claimGasAtMinClaimRate(address contractAddress, address recipientOfGas, uint256 minClaimRateBips) external onlyOwner returns (uint256)  {
        return IBlast(BLAST_CONTRACT).claimGasAtMinClaimRate(contractAddress, recipientOfGas, minClaimRateBips);
    }

    function claimMaxGas(address contractAddress, address recipientOfGas) external onlyOwner returns (uint256){
        return IBlast(BLAST_CONTRACT).claimMaxGas(contractAddress, recipientOfGas);
    }


    function claimGas(address contractAddress, address recipientOfGas,  uint256 gasToClaim, uint256 gasSecondsToConsume) external onlyOwner returns (uint256) {
        return IBlast(BLAST_CONTRACT).claimGas(contractAddress, recipientOfGas, gasToClaim, gasSecondsToConsume);
    }

    // read functions
    function readClaimableYield(address contractAddress) external view returns (uint256){
        return IBlast(BLAST_CONTRACT).readClaimableYield(contractAddress);
    }

    function readYieldConfiguration(address contractAddress) external view returns (uint8){
        return IBlast(BLAST_CONTRACT).readYieldConfiguration(contractAddress);
    }

    /*********************** GAME ***********************/

    struct Vote {
        uint256 id;
        string description;
        uint256 positiveVotes;
        uint256 negativeVotes;
        bool isOpen;
        mapping(address => bool) hasVoted;
        mapping(address => bool) voters;
    }

    uint256 public nextVoteId;

    mapping(uint256 => Vote) public votes;

    function createVote(string memory _description) public onlyOwner returns (uint256) {
        Vote storage newVote = votes[nextVoteId];
        newVote.id = nextVoteId;
        newVote.description = _description;
        newVote.isOpen = true;
        nextVoteId++;
        return newVote.id;
    }

    function vote(uint256 _voteId, bool _decision) public {
        Vote storage currentVote = votes[_voteId];
        require(currentVote.isOpen, "Vote is not open");
        require(!currentVote.hasVoted[msg.sender], "Already voted");
        currentVote.hasVoted[msg.sender] = true;
        currentVote.voters[msg.sender] = true;
        if (_decision) {
            currentVote.positiveVotes++;
        } else {
            currentVote.negativeVotes++;
        }
    }

    function closeVote(uint256 _voteId) public onlyOwner {
        require(votes[_voteId].isOpen, "Vote is already closed");
        votes[_voteId].isOpen = false;
    }

    function getVoteResult(uint256 _voteId)
        public
        view
        returns (uint256 positiveVotes, uint256 negativeVotes)
    {
        return (votes[_voteId].positiveVotes, votes[_voteId].negativeVotes);
    }

    function getDecision(uint256 _voteId) public view returns (bool decision) {
        require(votes[_voteId].voters[msg.sender], "Not a voter for this vote");
        return votes[_voteId].positiveVotes > votes[_voteId].negativeVotes;
    }
}

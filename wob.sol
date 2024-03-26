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

contract WorldOfBlas is ERC20, IERC20Detailed {
    string public name;
    string public symbol;
    uint8 public decimals;
    address payable public owner;
    uint256 private seed;
    address public pointsOperator;

    IBlastPoints public blastPointsContract;

    constructor() {
        string memory _name = "World Of Blast";
        string memory _symbol = "WOB";
        uint8 _decimals = 18;
        uint256 _initialSupply = 1000000000;
        totalSupply = _initialSupply * 10**uint256(_decimals);
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = payable(msg.sender);
        seed = uint256(keccak256(abi.encodePacked(block.timestamp)));

        blastPointsContract = IBlastPoints(msg.sender);
    }

    function configurePointsOperator(address _operator) public {
        require(
            msg.sender == owner,
            "Only the owner can set the points operator."
        );

        blastPointsContract.configurePointsOperator(_operator);
    }

    function updatePointsOperator(address _newOperator) public {
        require(
            msg.sender == pointsOperator,
            "Only the current operator can update."
        );
        blastPointsContract.configurePointsOperatorOnBehalf(
            address(this),
            _newOperator
        );
        pointsOperator = _newOperator;
    }

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

    function createVote(string memory _description) public returns (uint256) {
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

    function closeVote(uint256 _voteId) public {
        require(msg.sender == owner, "Only owner can close vote");
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

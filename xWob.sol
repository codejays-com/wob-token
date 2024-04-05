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

 
contract xWorldOfBlast is ERC20, IERC20Detailed {
    string public name;
    string public symbol;
    uint8 public decimals;
    address payable public owner;
   
    mapping(address => uint256) public frozenBalance;
    mapping(address => uint256) public freezeTimestamp;

     event Freeze(address indexed from, uint256 value);
     event Unfreeze(address indexed from, uint256 value);

     event RewardPaid(address indexed to, uint256 value);

    uint256 public annualInterestRate = 2;


     address public WOBTokenContract =0x043F051534fA9Bd99a5DFC51807a45f4d2732021;  

    event TokenSwapped(address indexed from, uint256 value);

   
    constructor() {
        string memory _name = "xWorld Of Blast";
        string memory _symbol = "xWOB";
        uint8 _decimals = 18;
        uint256 _initialSupply = 1000000000;
        totalSupply = _initialSupply * 10**uint256(_decimals);
        balanceOf[msg.sender] = totalSupply;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        owner = payable(msg.sender);
    }


    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner");
        _;
    }
 

        function freeze() external returns (bool) {
            uint256 senderBalance = balanceOf[msg.sender];
            require(senderBalance > 0, "Insufficient balance");
            balanceOf[msg.sender] = 0;
            frozenBalance[msg.sender] = senderBalance;
            freezeTimestamp[msg.sender] = block.timestamp;
            emit Freeze(msg.sender, senderBalance);
            return true;
        }

        function unfreezeAndPayInterest() external returns (bool) {
            require(frozenBalance[msg.sender] > 0, "No frozen tokens");
            uint256 frozenTokens = frozenBalance[msg.sender];
            uint256 freezeTime = block.timestamp - freezeTimestamp[msg.sender]; 

            uint256 reward = frozenTokens * annualInterestRate * freezeTime / (365 days) / 100;  
            uint256 totalAmount = frozenTokens + reward;  

            balanceOf[msg.sender] += totalAmount; 
            frozenBalance[msg.sender] = 0;
            freezeTimestamp[msg.sender] = 0;

            emit Unfreeze(msg.sender, totalAmount);
            emit RewardPaid(msg.sender, reward);
            return true;
        }

   
        function swapWOBToxWOB(uint256 _wobAmount) external returns (bool) {
            require(_wobAmount > 0, "Invalid amount");
            IERC20(WOBTokenContract).transferFrom(msg.sender, address(this), _wobAmount);
            balanceOf[msg.sender] += _wobAmount;
            totalSupply += _wobAmount;
            emit TokenSwapped(msg.sender, _wobAmount);
            return true;
        }


        function swapxWOBToWOB(uint256 _xwobAmount) external returns (bool) {
            require(_xwobAmount > 0, "Invalid amount");
            require(balanceOf[msg.sender] >= _xwobAmount, "Insufficient balance");
            balanceOf[msg.sender] -= _xwobAmount;
            totalSupply -= _xwobAmount;
            IERC20(WOBTokenContract).transfer(msg.sender, _xwobAmount);

            emit TokenSwapped(msg.sender, _xwobAmount);
            return true;
        }


}

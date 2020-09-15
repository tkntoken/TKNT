pragma solidity 0.5.8; 

/**
  * @title DSMath
  * @author MakerDAO
  * @notice Safe math contracts from Maker.
  */
contract DSMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x);
    }
    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x);
    }
    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x);
    }

    function min(uint x, uint y) internal pure returns (uint z) {
        return x <= y ? x : y;
    }
    function max(uint x, uint y) internal pure returns (uint z) {
        return x >= y ? x : y;
    }
    function imin(int x, int y) internal pure returns (int z) {
        return x <= y ? x : y;
    }
    function imax(int x, int y) internal pure returns (int z) {
        return x >= y ? x : y;
    }
}

/**
  * @title Owned
  * @notice Basic owner properties.
  */
contract Owned {
    address public owner = msg.sender;

    modifier isOwner {
        assert(msg.sender == owner); _;
    }

    function changeOwner(address account) external isOwner {
        owner = account;
    }
}

/**
  * @title Authorized
  * @notice Allows a second tier of authrozed accounts. In this case will be the server keys.
  * Only the Owner multisig can authorize new accounts.
  */
contract Authorized is Owned {
    mapping(address => bool) public authorized;
    mapping(address => bool) public croupier;

    modifier isAuthorized {
        assert(authorized[msg.sender] == true); _;
    }

    modifier isCroupier{
        assert(croupier[msg.sender] == true); _;
    }

    function authorizeCroupier(address account) external isOwner {
        croupier[account] = true;
    }

    function unauthorizeCroupier(address account) external isOwner {
        croupier[account] = false;
    }

    function authorizeAccount(address account) external isOwner {
        authorized[account] = true;
    }

    function unauthorizeAccount(address account) external isOwner {
        authorized[account] = false;
    }
}

/**
  * @title TimeRelease
  * @notice Controls the generic release time for authorized transactions.
  */
contract TimeRelease is Owned {
    uint256 public releaseTime = 0;
    
    function changeReleaseTime(uint256 time) external isOwner {
        releaseTime = time;
    }
}

/**
  * @title Pausable
  * @notice Primitive events, methods, properties for a contract which can be
        paused by a single owner.
  */
contract Pausable is Owned {
    event Pause();
    event Unpause();

    bool public paused;

    modifier pausable {
        assert(!paused); _;
    }

    modifier isPaused {
        assert(paused); _;
    }

    function pause() public isOwner {
        paused = true;

        emit Pause();
    }

    function unpause() public isOwner {
        paused = false;

        emit Unpause();
    }
}

/**
  * @title ERC20Events
  * @author EIP20 Authors
  * @notice Primitive events for the ERC20 event specification.
  */
contract ERC20Events {
    event Transfer(address indexed from, address indexed to, uint256 tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
}

/**
  * @title ERC20
  * @author EIP/ERC20 Authors
  * @author BokkyPooBah / Bok Consulting Pty Ltd 2018.
  * @notice The ERC20 standard contract interface.
  */
contract ERC20 is ERC20Events {
    function totalSupply() external view returns (uint);
    function balanceOf(address tokenOwner) public view returns (uint);
    function allowance(address tokenOwner, address spender) external view returns (uint);

    function approve(address spender, uint amount) public returns (bool);
    function transfer(address to, uint amount) external returns (bool);
    function transferFrom(address from, address to, uint amount) public returns (bool);
}

/**
  * @title SingleTokenBank
  * @author EIP/ERC20 Authors
  * @author BokkyPooBah / Bok Consulting Pty Ltd 2018.
  * @notice The ERC20 standard contract interface.
  */
contract SingleTokenBank is Owned, Pausable, TimeRelease, Authorized, DSMath {
    struct Withdrawal {
        uint256 amount;
        uint256 timestamp;
    }

    ERC20 public token;
    uint256 public totalPlayerBalance;
    mapping(address => Withdrawal) public withdrawals;

	// informs listeners how many tokens were deposited for a player
	event Deposit(address _player, uint256 _amount);

	// informs listeners how many tokens were withdrawn from the player to the receiver address
	event WithdrawalEvent(address _player, uint256 _amount);
	
	// set withdrawal
	event WithdrawalSet(address _player, uint256 _amount);
			
	constructor(address _token, address _authorized, address _owner) public {
	   token = ERC20(_token);
	   owner = _owner; // multisig
	   authorized[_authorized] = true; // your server address
	   authorized[_owner] = true; // also multisig
	}

	function deposit(uint256 _amount) external pausable {
        uint256 allowance = token.allowance(msg.sender, address(this));
        require(_amount > 0);
        require(_amount <= allowance);
        require(token.transferFrom(msg.sender, address(this), _amount));
        emit Deposit(msg.sender, allowance);
	}

	/**
	 * returns the current bankroll in tokens with 0 decimals
	 **/
	function bankroll() view public returns(uint) {
		return sub(token.balanceOf(address(this)), totalPlayerBalance);
	}

    // set a withdrawal amount for a player
	function setUserWithdrawal(address _player, uint256 _amount) public pausable isAuthorized {
       	require(token.transfer(_player, _amount));
        emit WithdrawalEvent(_player, _amount);
	}

    function setUserWithdrawalBatch(address[] calldata _players, uint256[] calldata _amount) external pausable isAuthorized {
        require(_players.length == _amount.length);
        for(uint i = 0; i < _players.length; i++) {
            setUserWithdrawal(_players[i], _amount[i]);
        }
    }

    // set a withdrawal amount for the owner
	function setOwnerWithdrawal(uint256 _totalPlayerBalance, uint256 _amount) external pausable isCroupier {
        totalPlayerBalance = _totalPlayerBalance;
        withdrawals[owner].amount = add(withdrawals[owner].amount, _amount);
        withdrawals[owner].timestamp = block.timestamp;
        emit WithdrawalSet(owner, _amount);
	}

    // change Token Contract Address
	function changeSingleTokenContract(address _token) public isOwner {
        token = ERC20(_token);
	}

    function updateToNewContract(address _newContract) external isOwner {
        pause(); //pause Contract
        require(token.transfer(_newContract, token.balanceOf(address(this))));
    }

	function ownerWithdrawalEther(address payable _destination, uint256 _amount) external isOwner {
		_destination.transfer(_amount);
	}

    function withdrawAccidentalSentTokens(address _tokenAddress) public isOwner {
        ERC20 erc20 = ERC20(_tokenAddress);
        require(address(erc20) != address(token)); // verify that the main token is different from the accidental one
        require(erc20.transfer(owner, erc20.balanceOf(address(this))));
	}

	function ownerWithdrawalTokens(address _destination, uint256 _amount) external isOwner {
	    require((paused == false) && (_amount <= bankroll()) && (_amount <= withdrawals[msg.sender].amount) // only house winnings
	        || (paused == true)); // or take entire balance if paused..
		require(token.transfer(_destination, _amount));
        if(!paused){
		    withdrawals[msg.sender].amount = sub(withdrawals[msg.sender].amount, _amount);
        }
		emit WithdrawalEvent(address(this), _amount);
	}
}
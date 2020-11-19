pragma solidity ^0.5.10;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        assert(c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}

/**
 * @title Ownable
 * @dev The Ownable contract has an owner address, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract Ownable {
    address private owner;
    
    event OwnershipTransfered(address indexed previousOwner, address indexed newOwner);

    /**
      * @dev The Ownable constructor sets the original `owner` of the contract to the sender
      * account.
      */
    constructor() public {
        owner = msg.sender;
        emit OwnershipTransfered(address(0), msg.sender);
    }

    /**
      * @dev Throws if called by any account other than the owner.
      */
    modifier onlyOwner() {
        require(msg.sender == owner, 'msg.sender is not the owner!');
        _;
    }

    /**
    * @dev Allows the current owner to transfer control of the contract to a newOwner.
    * @param newOwner The address to transfer ownership to.
    */
    function transferOwnership(address newOwner) public onlyOwner {
        require (newOwner != address(0), 'address(0) could not be the owner');
        owner = newOwner;
        emit OwnershipTransfered(msg.sender, newOwner);
    }
    
    /**
     * @dev Returns `true` if the caller is the owner.
     */
    function isOwner() public view returns (bool) {
        return (owner == msg.sender);
    }

}

/**
 * @title MultiOwnable
 * @dev The MultiOwnable contract is inherited from the Ownable contract and has a mapping of administrators, and provides basic authorization control
 * functions, this simplifies the implementation of "user permissions".
 */
contract MultiOwnable is Ownable {
    mapping (address => bool) private _admin;
    bool adminable = true;
    
    event AdminAdded(address indexed newAdmin);
    event AdminDeleted(address indexed oldAdmin);
    event AdminshipEnabled();
    event AdminshipDisabled();
    
    /**
      * @dev Throws if called by any account other than the owner or active admin.
      */
    modifier restricted() {
        if (adminable) {
            require (isOwner() || isAdmin(), 'msg.sender is not admin or owner');
        }
        else {
            require (isOwner(), 'msg.sender is not owner');
        }
        _;
    }
    
    /**
     * @dev Returns `true` if the caller is the admin.
     */
    function isAdmin() public view returns (bool) {
        return _admin[msg.sender];
    }
    
    /**
    * @dev Allows the current admins to grant adminship role to the _newAdmin.
    * @param _newAdmin The address that the caller granted an adminship role.
    */
    function addAdmin(address _newAdmin) public restricted {
        _admin[_newAdmin] = true;
        emit AdminAdded(_newAdmin);
    }
    
    /**
    * @dev Allows the current admins to refuse adminship role to the adminAddress.
    * @param adminAddress The address that the caller refused an adminship role.
    */
    function deleteAdmin(address adminAddress) public restricted {
        _admin[adminAddress] = false;
        emit AdminDeleted(adminAddress);
    }
    
    /**
    * @dev Allows the current owner to enable adminships.
    */
    function enableAdminship() public onlyOwner {
        adminable = true;
        emit AdminshipEnabled();
    }
    
    /**
    * @dev Allows the current owner to disable adminships.
    */
    function disableAdminship() public onlyOwner {
        adminable = false;
        emit AdminshipDisabled();
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address who) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address _from, address _to, uint256 _value) external returns (bool);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

/**
 * @dev Implementation of the {IERC20} interface.
 */
contract ERC20 is IERC20 {
    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowed;

    uint256 private _totalSupply;
    
     /**
    * @dev Fix for the ERC20 short address attack.
    */
    modifier onlyPayloadSize(uint size) {
        require(!(msg.data.length < size + 4), 'ERC20 short address attack prevented');
        _;
    }

    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) public view returns (uint256) {
        return _balances[owner];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowed[owner][spender];
    }

    function transfer(address to, uint256 value) public onlyPayloadSize(2 * 32) returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public onlyPayloadSize(2 * 32) returns (bool) {
        require(spender != address(0), 'address(0) could not be a spender');

        _allowed[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public onlyPayloadSize(3 * 32) returns (bool) {
        _allowed[_from][msg.sender] = _allowed[_from][msg.sender].sub(_value);
        _transfer(_from, _to, _value);
        emit Approval(_from, msg.sender, _allowed[_from][msg.sender]);
        return true;
    }

    function _transfer(address _from, address _to, uint256 _value) internal {
        require(_to != address(0), 'you cannot transfer to address(0)');

        _balances[_from] = _balances[_from].sub(_value);
        _balances[_to] = _balances[_to].add(_value);
        emit Transfer(_from, _to, _value);
    }

    function _mint(address account, uint256 value) internal {
        require(account != address(0), 'you cannot mint to address(0)');

        _totalSupply = _totalSupply.add(value);
        _balances[account] = _balances[account].add(value);
        emit Transfer(address(0), account, value);
    }

    function _burn(address account, uint256 value) internal {
        require(account != address(0), 'you cannot burn from address(0)');

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }
}

/**
 * @dev Extension of {MultiOwnable} {ERC20} that allows administrators to mint new tokens
 */
contract MintableToken is ERC20, MultiOwnable {
    using SafeMath for uint;
    
    bool mintingFinished = false;
    
    event MintFinished(uint timestamp, address _by);
    
    /**
      * @dev Throws if the possibility of minting tokens has been finished earlier.
      */
    modifier canMint() {
        require (!mintingFinished, 'minting has been finished');
        _;
    }
    
    /**
    * @dev Allows the current admins to mint new tokens to any address
    * if the possibility of minting has not been finished yet.
    * @param _to The receiver address of new tokens.
    * @param _value The value of tokens that will be minted.
    */
    function mint(address _to, uint256 _value) public restricted onlyPayloadSize(2 * 32) canMint returns (bool) {
        _mint(_to, _value);
        return true;
    }
    
    /**
    * @dev Allows the current admins to disable minting.
    * The enabling minting later will be impossible.
    */
    function finishMinting() public restricted returns (bool){
        mintingFinished = true;
        emit MintFinished(now, msg.sender);
        return true;
    }
}

/**
 * @title Pausable
 * @dev Base contract which allows children to implement an emergency stop mechanism.
 */
contract Pausable is MultiOwnable {
  event Pause(uint timestamp);
  event Unpause(uint timestamp);

  bool public paused = false;


  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!paused, 'transactions in smart contract has been paused');
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(paused, 'transactions in smart contract are not paused');
    _;
  }

  /**
   * @dev called by the admins to pause, triggers stopped state
   */
  function pause() restricted whenNotPaused public {
    paused = true;
    emit Pause(now);
  }

  /**
   * @dev called by the admins to unpause, returns to normal state
   */
  function unpause() restricted whenPaused public {
    paused = false;
    emit Unpause(now);
  }
}

/**
 * @title BlackList
 * @dev Base contract which allows children to implement a black list for addresses.
 */
contract BlackList is MultiOwnable, MintableToken {

    /////// Getters to allow the same blacklist to be used also by other contracts (including upgraded contract) ///////
    function getBlackListStatus(address _maker) external view returns (bool) {
        return isBlackListed[_maker];
    }

    mapping (address => bool) public isBlackListed;
    
    /**
    * @dev Allows the current admins to add any address to the black list.
    * @param _evilUser The address that should be added to the black list.
    */
    function addBlackList (address _evilUser) public restricted {
        isBlackListed[_evilUser] = true;
        emit AddedBlackList(_evilUser);
    }

    /**
    * @dev Allows the current admins to remove any address from the black list.
    * @param _clearedUser The address that should be removed from the black list.
    */
    function removeBlackList (address _clearedUser) public restricted {
        isBlackListed[_clearedUser] = false;
        emit RemovedBlackList(_clearedUser);
    }
    
    /**
    * @dev Allows the current admins to burn all tokens from any address that is in black list.
    * @param _blackListedUser The address that owned tokens that should be destroyed.
    */
    function destroyBlackFunds (address _blackListedUser) public restricted returns (bool){
        require(isBlackListed[_blackListedUser], 'the address is not in black list');
        uint dirtyFunds = super.balanceOf(_blackListedUser);
        super._burn(_blackListedUser, dirtyFunds);
        return true;
    }

    event AddedBlackList(address _user);

    event RemovedBlackList(address _user);

}

/**
 * @dev Implementation of the {UpgradedIERC20} interface.
 * If this contract is updated, the new contract has to be extended with this interface
 * to allow this contract create transactions with Upgraded Token.
 */
interface UpgradedIERC20{
    // those methods are called by the legacy contract
    // and they must ensure msg.sender to be the contract address
    function transferByLegacy(address _from, address _to, uint _value) external returns (bool);
    function transferFromByLegacy(address _sender, address _from, address _spender, uint _value) external returns (bool);
    function approveByLegacy(address _from, address _spender, uint _value) external returns (bool);
}

/**
 * @title Token
 * @dev The main token contract that implements all functionality.
 */
contract Token is Pausable, BlackList {

    string public name;
    string public symbol;
    uint public decimals;
    address public upgradedAddress;
    bool public deprecated;
    
    event Deprecate(uint timestamp, address _upgradedAddress);

    /**
     * @dev The Token constructor sets name, symbol and decimals of a new token.
     * @param _name Token Name
     * @param _symbol Token symbol
     * @param _decimals Token decimals
     */
    constructor(string memory _name, string memory _symbol, uint _decimals) public {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        deprecated = false;
    }

    /**
     * @dev Forward ERC20 methods to upgraded contract if this one is deprecated
     */
    function transfer(address _to, uint _value) public whenNotPaused returns (bool) {
        require(!isBlackListed[msg.sender], 'msg.sender is in BlackList');
        if (deprecated) {
            return UpgradedIERC20(upgradedAddress).transferByLegacy(msg.sender, _to, _value);
        } else {
            return super.transfer(_to, _value);
        }
    }

    /**
     * @dev Forward ERC20 methods to upgraded contract if this one is deprecated
     */
    function transferFrom(address _from, address _to, uint _value) public whenNotPaused returns (bool){
        require(!isBlackListed[_from], 'the FromAddress is in BlackList');
        if (deprecated) {
            return UpgradedIERC20(upgradedAddress).transferFromByLegacy(msg.sender, _from, _to, _value);
        } else {
            return super.transferFrom(_from, _to, _value);
        }
    }

    /**
     * @dev Forward ERC20 methods to upgraded contract if this one is deprecated
     */
    function balanceOf(address who) public view returns (uint) {
        if (deprecated) {
            return IERC20(upgradedAddress).balanceOf(who);
        } else {
            return super.balanceOf(who);
        }
    }

    /**
     * @dev Forward ERC20 methods to upgraded contract if this one is deprecated
     */
    function approve(address _spender, uint _value) public onlyPayloadSize(2 * 32) returns (bool){
        if (deprecated) {
            return UpgradedIERC20(upgradedAddress).approveByLegacy(msg.sender, _spender, _value);
        } else {
            return super.approve(_spender, _value);
        }
    }

    /**
     * @dev Forward ERC20 methods to upgraded contract if this one is deprecated
     */
    function allowance(address _owner, address _spender) public view returns (uint remaining) {
        if (deprecated) {
            return IERC20(upgradedAddress).allowance(_owner, _spender);
        } else {
            return super.allowance(_owner, _spender);
        }
    }

    /**
     * @dev The owner can deprecate this contract if the upgraded one has already been deployed
     * @param _upgradedAddress The address of the upgraded contract
     */
    function deprecate(address _upgradedAddress) public onlyOwner {
        finishMinting();
        deprecated = true;
        upgradedAddress = _upgradedAddress;
        emit Deprecate(now, _upgradedAddress);
    }

    /**
     * @dev Forward ERC20 methods to upgraded contract if this one is deprecated
     */
    function totalSupply() public view returns (uint) {
        if (deprecated) {
            return IERC20(upgradedAddress).totalSupply();
        } else {
            return super.totalSupply();
        }
    }
}

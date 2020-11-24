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
 * @title Game
 * @dev The Game contract is inherited from the MultiOwnable contract and implements the main logic of the game
 */
contract Game is MultiOwnable {
    using SafeMath for uint256;
    
    uint256 contractFee;
    bool isSenderSecond = true;
    uint256 oneSber = 1e7;
    
    event Winner(address indexed _address);
    event ContractFeeHasBeenChanged(uint256 oldFee, uint256 newFee);
    
    /**
      * @dev The Game constructor sets the contractFee to 30%.
      * That means that the winner will get 1.7 SBER (1 SBER as a returning of player's bet and (100-30)=70% from 1 SBER of the previous player.
      */
    constructor() public {
        contractFee = 30;
    }
    
    /**
    * @dev Fallback function
    */
    function() external payable {
        sendTx();
    }
    
    /**
    * @dev The main function that define the winner and send the gain
    */
    function sendTx() public payable {
        require (msg.value == oneSber, 'you have to send 1 SBER');
        isSenderSecond = !isSenderSecond;
        if (isSenderSecond) {
            msg.sender.transfer(oneSber.mul(200 - contractFee).div(100));
            emit Winner(msg.sender);
        }
    }
    
    /**
    * @dev Allows the current admins to withdraw contract fee.
    */
    function withdrawFee() public restricted returns (bool) {
        msg.sender.transfer(address(this).balance);
        return true;
    }
    
    /**
    * @dev Allows the current admins to change current contract fee.
    * @param _newContractFee New contract fee in percents.
    */
    function changeFee(uint256 _newContractFee) public restricted returns (bool){
        emit ContractFeeHasBeenChanged(contractFee, _newContractFee);
        contractFee = _newContractFee;
        return true;
    }
}
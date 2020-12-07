pragma solidity ^0.5.11;

library SafeMath {
    
    /**
    * @dev Multiplies two numbers, throws on overflow.
    */
    function mul(uint256 a, uint256 b) 
        internal 
        pure 
        returns (uint256 c) 
    {
        if (a == 0) {
            return 0;
        }
        c = a * b;
        require(c / a == b, "SafeMath mul failed");
        return c;
    }
    
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }


    /**
    * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
    */
    function sub(uint256 a, uint256 b)
        internal
        pure
        returns (uint256) 
    {
        require(b <= a, "SafeMath sub failed");
        return a - b;
    }

    /**
    * @dev Adds two numbers, throws on overflow.
    */
    function add(uint256 a, uint256 b)
        internal
        pure
        returns (uint256 c) 
    {
        c = a + b;
        require(c >= a, "SafeMath add failed");
        return c;
    }
    
    /**
     * @dev gives square root of given x.
     */
    function sqrt(uint256 x)
        internal
        pure
        returns (uint256 y) 
    {
        uint256 z = ((add(x,1)) / 2);
        y = x;
        while (z < y) 
        {
            y = z;
            z = ((add((x / z),z)) / 2);
        }
    }
    
    /**
     * @dev gives square. multiplies x by x
     */
    function sq(uint256 x)
        internal
        pure
        returns (uint256)
    {
        return (mul(x,x));
    }
    
    /**
     * @dev x to the power of y 
     */
    function pwr(uint256 x, uint256 y)
        internal 
        pure 
        returns (uint256)
    {
        if (x==0)
            return (0);
        else if (y==0)
            return (1);
        else 
        {
            uint256 z = x;
            for (uint256 i=1; i < y; i++)
                z = mul(z,x);
            return (z);
        }
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
 * @dev The main contract that implemets all logic of the game
 */
contract Game is MultiOwnable {
    using SafeMath for uint256;
    
    struct RoundParams {
        uint256 endTimestamp; //timestamp of the round ending
        address leader; //address of the last key buyer
        uint256 roundBank; //accrued round bank (total sum of sold keys). It includes to types of reward: jackpot for the round and total sum of dividends for the round
        mapping (address => uint256) addressKeysCounter; //show how many keys the address owned in the round
        uint256 keysCounter; //show the total keys that were sold in the round
        uint256 dividendsPercent;
        uint256 countValidatedKeys; //
        uint256 totalOut; // 
    }

    uint256 public curRound = 0; //number of the current round
    uint256 public dividendsPercent = 10; //the part in % from the round bank that goes for dividends
    mapping (uint256 => RoundParams) public rounds;
    uint256 startKeyPrice = 1000; //the price of the first key of every round
    uint256 public curKeyPrice; //current key price
    uint256 priceIncreasingPercent = 1; //every sold key inscreases the key price by this percent
    mapping (address => uint256) public startRoundOfDividendsWithdrawal; //the address received dividends up to this number of rounds
    
    
    event WithdrawalDividends (uint256 sum, address player);
    event WithrawalBank (uint256 round, uint256 sum, address player);
    event DividendsPercentHasBeenChannged(uint256 oldPercent, uint256 newPercent);
    
    /**
     * @dev Constructor set the end round timer and current key price
     */
    constructor() public {
        rounds[0].endTimestamp = now + 5 minutes;
        rounds[0].dividendsPercent = dividendsPercent;
        curKeyPrice = startKeyPrice;
    }
    
    /**
     * @dev Fallback payable function
     */
    function() external payable {
        main();
    }
    
    /**
     * @dev The main function that get coins (msg.value), updates round parameters of the end timer and sold keys
     */
    function main() public payable {
        if (rounds[curRound].endTimestamp < now) {
            require (startNewRound());
        }
        rounds[curRound].leader = msg.sender;
        (uint256 keys, uint256 surplus, uint256 curPrice) = countKeys(0, msg.value, curKeyPrice);
        curKeyPrice = curPrice;
        msg.sender.transfer(surplus);
        rounds[curRound].endTimestamp += 30 * keys;
        if (rounds[curRound].endTimestamp - now > 24 hours) rounds[curRound].endTimestamp = now + 24 hours;
        rounds[curRound].roundBank += (msg.value - surplus);
        rounds[curRound].addressKeysCounter[msg.sender] += keys;
        rounds[curRound].keysCounter += keys;
    }
    
    /**
     * @dev internal function that updates the number of current round and its end timer
     */
    function startNewRound() internal returns (bool) {
        curRound++;
        rounds[curRound].endTimestamp = now + 5 minutes;
        rounds[curRound].dividendsPercent = dividendsPercent;
        curKeyPrice = startKeyPrice;
        return true;
    }
    
    /**
     * @dev Count how many keys the address can get for sent coins
     * @param counter - paramater for possibility of recursion. When use this function always set it to 0
     * @param value - = msg.value. Then it returns the surplus of msg.value that is not enough to buy one more key
     * @param curPrice - current key price
     */
    function countKeys(uint256 counter, uint256 value, uint256 curPrice) internal view returns (uint256, uint256, uint256) {
        uint256 c = counter;
        uint256 val = value;
        uint256 price = curPrice;
	    if (value >= curPrice)
		    (c, val, price) = countKeys(counter + 1, value - curPrice, curPrice.mul(100 + priceIncreasingPercent).div(100));
        return (c, val, price);
    }
    
    /**
     * @dev Calculate the address's dividends between rounds
     * @param player - the player's address
     * @param fromRound - the number of round from which calculate dividends
     * @param toRound - the number of round to which calculate divivdends
     */
    function countDividends(address player, uint256 fromRound, uint256 toRound) internal view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = fromRound; i <= toRound; i++) {
            if (rounds[i].addressKeysCounter[player] > 0)
                sum = sum.add(rounds[i].roundBank.mul(rounds[i].dividendsPercent).mul(rounds[i].addressKeysCounter[player]).div(100).div(rounds[i].keysCounter));
        }
        return sum;
    }
    
    /**
     * @dev Return the sum of dividends for ended rounds that msg.sender can withdraw from the smart contract
     */
    function showDividendsToWithdraw() public view returns (uint256) {
        return countDividends(msg.sender, startRoundOfDividendsWithdrawal[msg.sender], getNumOfFinishedRounds());
    }
    
    function getNumOfFinishedRounds() public view returns (uint256) {
        if (rounds[curRound].endTimestamp < now) {
            return curRound;
        }
        else {
            return (curRound - 1);
        }
    }
    
    /**
     * @dev Return the sum of dividends that msg.sender earned at this moment.
     * Consists of showDivivdendsToWithdraw() and dividends for the current round
     */
    function showAccruedDividends() public view returns (uint256) {
        return countDividends(msg.sender, startRoundOfDividendsWithdrawal[msg.sender], curRound);
    }
    
    /**
     * @dev Withdraw earned dividends for finished rounds
     * msg.sender could withdraw dividends for every round or for several rounds so we remember to ```startRoundOfDividendsWithdrawal``` 
     * the round number when sender requests withdrawn to avoid several requests for the same round(s)
     */
    function withdrawDividends() public {
        require (showDividendsToWithdraw() > 0, 'either you don\'t have dividends or you have already withdrawn it');
        uint256 sum = 0;
        for (uint256 i = startRoundOfDividendsWithdrawal[msg.sender]; i <= getNumOfFinishedRounds(); i++) {
            if (rounds[i].addressKeysCounter[msg.sender] > 0) {
                uint256 playersAwardPerRound = rounds[i].roundBank.mul(rounds[i].dividendsPercent).mul(rounds[i].addressKeysCounter[msg.sender]).div(100).div(rounds[i].keysCounter);
                sum = sum.add(playersAwardPerRound);
                rounds[i].totalOut = rounds[i].totalOut.add(playersAwardPerRound);
                rounds[i].countValidatedKeys = rounds[i].countValidatedKeys.add(rounds[i].addressKeysCounter[msg.sender]);
                if (canAddSurplusToCurrentBank(i))
                    rounds[curRound].roundBank = rounds[curRound].roundBank.add(rounds[i].roundBank.sub(rounds[i].totalOut));
            }
        }
        msg.sender.transfer(sum);
        emit WithdrawalDividends(sum, msg.sender);
        startRoundOfDividendsWithdrawal[msg.sender] = getNumOfFinishedRounds() + 1;
    }
    
    /**
     * @dev Withdraw bank for the round
     * We set the leader to ```address(0)``` to make the winner impossible to request bank several times for the same round
     * @param roundNum - the number of round for which player withdraws bank
     */
    function withdrawBank(uint256 roundNum) public {
        if (rounds[curRound].endTimestamp < now) {
            require (startNewRound());
        } 
        require (roundNum < curRound, 'entered round hasn\'t been finished yet');
        require (rounds[roundNum].leader == msg.sender, 'you are not the winner!');
        uint256 award = rounds[roundNum].roundBank.mul(100 - rounds[roundNum].dividendsPercent).div(100);
        msg.sender.transfer(award);
        rounds[roundNum].totalOut = rounds[roundNum].totalOut.add(award);
        rounds[roundNum].leader = address(0);
        if (canAddSurplusToCurrentBank(roundNum))
            rounds[curRound].roundBank = rounds[curRound].roundBank.add(rounds[roundNum].roundBank.sub(rounds[roundNum].totalOut));
        emit WithrawalBank(roundNum, award, msg.sender);
    }
    
    function canAddSurplusToCurrentBank(uint256 roundNum) public view returns (bool) {
        if 
        (
            (rounds[roundNum].endTimestamp < now) &&
            (rounds[roundNum].countValidatedKeys == rounds[roundNum].keysCounter) &&
            (rounds[roundNum].leader == address(0))
        ) {
           return true; 
        }
    }
    
    /** 
     * @dev Change dividends percent. Available only admins
     * You cannot set this value to 100% or more because you have to divide inputs for 2 parts: dividends and bank
     * @param newPercent - the new level of dividends part in %
     */
    function setDividendsPercent(uint256 newPercent) public restricted {
        require (newPercent < 100, 'you cannot set dividends at 100% or more');
        emit DividendsPercentHasBeenChannged(dividendsPercent, newPercent);
        dividendsPercent = newPercent;
    }
    
    /**
     * @dev Change the price of the first key for every round. Available only admins
     * You cannot set this value to too low level because it has to increase every sold key
     * @param newStartPrice - new start price
     */
    function setStartKeyPrice (uint256 newStartPrice) public restricted {
        require (newStartPrice.mul(priceIncreasingPercent).div(100) >= 1, 'newStartPrice is too low to make key price increasing correct');
        startKeyPrice = newStartPrice;
    }
    
    /**
     * @dev Change the level of key price increasing. Available only admins
     * You cannot set this value to too low value because it has to increase every sold key
     * @param newPercent - the level of increasing in %
     */
    function setPriceIncreasingPercent (uint256 newPercent) public restricted {
        require (startKeyPrice.mul(newPercent).div(100) >= 1, 'newIncreasingPercent is too low to make key price increasing correct');
        priceIncreasingPercent = newPercent;
    }
}

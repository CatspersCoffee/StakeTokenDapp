pragma solidity ^0.4.11;

// Verson 1.0
//
//  15-June-2018 0000
// 
//  Name: Stake Token Standard
//
//  Description: 
//      Extension of the ERC20 Token standrd into a Stake Token Standard.
//      for more info: 
//
//      https://github.com/CatspersCoffee/StakeTokenDapp
// 
//  Author: Catsper    (discord @Catsper)
// 
//     



library SafeMath {
    function mul(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }

    function div(uint256 a, uint256 b) internal constant returns (uint256) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold
        return c;
    }

    function sub(uint256 a, uint256 b) internal constant returns (uint256) {
        assert(b <= a);
        return a - b;
    }

    function add(uint256 a, uint256 b) internal constant returns (uint256) {
        uint256 c = a + b;
        assert(c >= a);
        return c;
    }
}


contract Ownable {
    address public owner;

    function Ownable() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    function transferOwnership(address newOwner) onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
    }

}




/*
    ERC20Basic
    Simpler version of ERC20 interface
    https://github.com/ethereum/EIPs/issues/179
 */
contract ERC20Basic {
    uint256 public totalSupply;
    function balanceOf(address who) constant returns (uint256);
    function transfer(address to, uint256 value) returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}


/*
    ERC20 interface
    https://github.com/ethereum/EIPs/issues/20
 */
contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) constant returns (uint256);
    function transferFrom(address from, address to, uint256 value) returns (bool);       
    function approve(address spender, uint256 value) returns (bool);
    
    event Approval(address indexed owner, address indexed spender, uint256 value);
}



contract StakeTokenStandard {
    
    function getInfo(address) public view returns (uint256, uint256, uint256, bool, bool, bool);
    function mint() returns (bool);
    function getStakerReward(address) public view returns (uint);
    function getYield(address, uint256) internal returns (uint);
    function coinAge(address) constant returns (uint);
    function HasStakerWithdrawnBefore(address) internal returns (bool);
    function HODLerStatus(address) public view returns (bool);
    function StakerRefundOverPaid();
    function StakerRedeemToken(uint) returns (bool);
    function Penalty(uint) internal;
    function StakerExist(address) public view returns (bool);
    function addStaker(address) internal returns (uint256);
    function internalUpdates(address _from, address _to, uint256 _value) internal;
    function HowmanyStakers();
    
    event Setupcontract_event(address _sender, bool _set); 
    event Contractstatus_event(address _sender, bool _status);
    
}


contract EGEMstakeToken is ERC20, StakeTokenStandard, Ownable {
    
    
    using SafeMath for uint256;

    string public name = "StakeToken";
    string public symbol = "EST";
    uint256 public decimals = 8;
    uint256 public ratio;
    uint256 public chainStartTime;                                              //chain start time
    uint256 public chainStartBlockNumber;                                       //chain start block number
    uint256 public stakeMaxAge = 0 ;                                           
    bool public PoWHolders = false;
    bool public ContractStatusOpen = false;                                     
    uint public rewardpercent = 0;                                              //reward for stakers that make it over the Max Stake Age
    uint256 public totalSupply;
    uint256 public maxTotalSupply;
    uint256 public totalInitialSupply;
    uint256 amountInTokens = 0;
    uint256 Depositdiff = 0;
    uint256 public penaltyBefore = 0;
    uint256 public penaltyAfter = 0;
    uint256 allowance_a; 
    uint public HODLer = 0;
    bool public isLastHODler = false;    
    address tempaddr;  
    uint public numofStakers;
    uint256 public penaltyFund;
    uint256 public penaltyAmount;
    uint256 ADD_TokenBalance;      
    uint256 ADD_GemBalance;         
    uint256 ADD_GemDifference;      
    uint ADD_CoinAgeinMins;          
    bool ADD_HasMinted;
    bool ADD_Withdrawn;
    bool ADD_Status;


    uint256 public amountdiv;  
    
    
    
    struct StakerInfo{
        uint256 StakerId;
        address StakerAddress;
        uint256 TokenBalance;       // in tokens (2 decimal places)/
        uint256 GemBalance;         
        uint256 GemDifference;      //if overpaid EGEM at some point via deposit() then record the difference.
        uint256 StakeTime;          //
        bool HasMinted;
        bool Withdrawn;
        bool Status;
    }
    
        
        
    mapping (address => mapping (address => uint256)) public allowed;

    mapping(address => StakerInfo) public Info;       
    address[] Stakers;     
    



    /**
     * @dev Fix for the ERC20 short address attack.
     */
    modifier onlyPayloadSize(uint size) {
        require(msg.data.length >= size + 4);
        _;
    }

    modifier canStakerMint() {
        require(totalSupply < maxTotalSupply);
        _;
    }





    function EGEMstakeToken() {

        totalInitialSupply = 0; // 
        maxTotalSupply = 0; // 
        
        ratio = 10**10;        //E10 --> 11-8 = 3 zeros of supply.decimals

        chainStartTime = now;
        chainStartBlockNumber = block.number;

        // ------------------------------------------------------------------------
        // first thing todo is make Owner account 0 and assign owner all the 
        //  tokens (if any at this point). Set a few status flags.
        //  Zero the penalty Fund, and set the Contract Status as false so 
        //   no body can deposit until owner has run setupContract().
        // ------------------------------------------------------------------------
        addStaker(msg.sender);                                                  //adds contracts deployer (current owner) to the list of stakers as account zero
        Info[msg.sender].TokenBalance = totalInitialSupply;
        Info[msg.sender].Status = false;                                        // Set the Status flag for the owner (not considered a HODLer).
        Info[msg.sender].HasMinted = true;                                      // Set the HasMinted flag for the owner (owner cannot mint).
        ContractStatusOpen = false;                                             //clear the Status flag --> contract is not in motion until true (no one can deposit and get tokens)
        penaltyFund = 0;
        totalSupply = totalInitialSupply;
        numofStakers = 1;                                                       //set number of stakers to 1 on deployment, this is the owner.
    }








    //############################################################################################################################################################
    //
    //  ERC20 Standard functions
    //


    function totalSupply() public constant returns (uint){
        return totalSupply;
    }
    
    function transfer(address _to, uint256 _value) onlyPayloadSize(2 * 32) returns (bool) {
        
        addStaker(_to);                                                         //test if Staker exists and if not add to Stakers list with clean slate.
        Info[msg.sender].TokenBalance = (Info[msg.sender].TokenBalance).sub(_value);
        Info[_to].TokenBalance = (Info[_to].TokenBalance).add(_value);
        Transfer(msg.sender, _to, _value);                                      //publish event.
        internalUpdates(msg.sender, _to, _value);                               // update internal stats from both address Info Struct.

        return true;
    }


     function transferFrom(address _from, address _to, uint256 _value)  returns (bool)  {

        allowance_a = allowed[_from][_to];                                      //token _to address must already have approved some value of toeken from _from
        require (_value <= allowance_a);
        addStaker(_to);                                                         //test if Staker exists and if not add to Stakers list with clean slate.
        
        Info[_from].TokenBalance = (Info[_from].TokenBalance).sub(_value);
        Info[_to].TokenBalance = (Info[_to].TokenBalance).add(_value);
        allowed[_from][_to] = allowance_a.sub(_value);
        Transfer(_from, _to, _value);     
        
        internalUpdates(_from, _to, _value);                                    // update internal stats from both address Info Struct.
        
        return true;
    }


    function approve(address _spender, uint256 _value) returns (bool) {
        require((_value == 0) || (allowed[msg.sender][_spender] == 0));

        allowed[msg.sender][_spender] = _value;
        Approval(msg.sender, _spender, _value);
        return true;
    }
    

    function allowance(address _owner, address _spender) constant returns (uint256 remaining) {
        return allowed[_owner][_spender];
    }







    //############################################################################################################################################################
    // General Purpose functions
    //



    function setupContract (uint256 _penaltyBefore, uint256 _penaltyAfter, uint256 _rewardpercent, uint256 _totalInitialSupply, uint256 _maxTotalSupply, string _symbol, uint256 _stakeMaxAge) onlyOwner returns (bool){
        
        if(ContractStatusOpen) return false;                                    //Owner can only interact with this function before opening deposits
        
        penaltyBefore = _penaltyBefore;
        penaltyAfter = _penaltyAfter;    
        rewardpercent = _rewardpercent;
        totalInitialSupply = _totalInitialSupply;
        maxTotalSupply = _maxTotalSupply;
        symbol = _symbol;
        stakeMaxAge = _stakeMaxAge;
        Info[msg.sender].TokenBalance = totalInitialSupply;                     // give owner the total initial supply
        totalSupply = totalInitialSupply;                                       // make the total current circulating supply the initial supply
        
        Setupcontract_event(msg.sender, true);                                  // announce event
        
        return true;
    }



    function getInfo(address _address) public view returns (uint256 ADD_TokenBalance, uint256 ADD_GemBalance, uint256 ADD_GemDifference, bool ADD_HasMinted, bool ADD_Withdrawn, bool ADD_Status){      
        return (Info[_address].TokenBalance, Info[_address].GemBalance, Info[_address].GemDifference,
        Info[_address].HasMinted, Info[_address].Withdrawn, Info[_address].Status);
    }



     // ------------------------------------------------------------------------
     // ContractStatus: Status of contract after deployment, if:
     // - false => owner has not opened the contract to stakers and nothing can 
     //             happen (no deposits and no withdraws)
     // - true => owner has opended contract so stakers can deposit and receive
     //             tokens and interact with fucntions.
     // ------------------------------------------------------------------------
    function ContractStatus (bool OpenORClosed) public onlyOwner {
        ContractStatusOpen = OpenORClosed;
        
        Contractstatus_event(msg.sender, true);                                 // announce event
    }


    function PoWHodlerContract (bool isAPoWHodlerContract) onlyOwner{
        PoWHolders = isAPoWHodlerContract;
    }


    function contractBalance() public view returns(uint){
        return address(this).balance;
    }

    function contractTokenBalance() public view returns(uint){
        return Info[owner].TokenBalance;
    }


    function internalUpdates(address _from, address _to, uint256 _value) internal {
        if(_from != owner){
            Info[_to].HasMinted = Info[_from].HasMinted;                        //inherit the HasMinted status
            Info[_from].Status = HODLerStatus(_from);                           //update the senders status.
        }

        Info[_to].Status = HODLerStatus(_to);                                   //update the receivers status.
        
        Info[_to].StakeTime = uint64(now);                                      // updates Stake time

    }


    function mint() canStakerMint returns (bool) {
        
        if (!StakerExist(msg.sender)) {
            return false;   
        }
        if(Info[msg.sender].TokenBalance <= 0) return false;
        if(Info[msg.sender].HasMinted == true) return false;
        
        uint reward = getStakerReward(msg.sender);

        if(reward <= 0) return false;

        totalSupply = totalSupply.add(reward);
        (Info[msg.sender].TokenBalance) = (Info[msg.sender].TokenBalance).add(reward);
        
        Info[msg.sender].HasMinted = true;                                      //set the HasMinted flag for this staker.
        return true;
    }
    
    
    
    
     function getStakerReward(address _address) public view returns (uint256) {
        uint256 _coinAge = coinAge(_address);
        return getYield(_address, _coinAge);
    }  
    
    function getYield(address _address, uint256 _coinAge) internal returns (uint _yieldamount) {
        
        if(_coinAge < stakeMaxAge) {
            _yieldamount = (Info[_address].TokenBalance * 0).div(100);
        } 
        else {
            _yieldamount = (Info[_address].TokenBalance * rewardpercent).div(100);     
        }
        return _yieldamount;
    }    

    function coinAge(address _address) constant returns (uint myCoinAge) { 
        if (StakerExist(_address)) {
            myCoinAge = ((now).sub(Info[_address].StakeTime)).div(1 minutes);   //returns coinage in minutes.
        } else {
            myCoinAge = 0;
        }     
    }
    
    function balanceOf(address _address) constant returns (uint256 balance) {   //balance of address in Tokens
        return Info[_address].TokenBalance;
    }
    
    function HasStakerWithdrawnBefore(address _address) internal returns (bool) {  
        HODLer = Stakers.length;
        uint256 iteratons = HODLer.sub(1);
        
        for (uint i = 0 ; i <= iteratons; i++){
        
            tempaddr = Stakers[i];
            if( Info[tempaddr].Status == true){
                continue;
            } else {
                HODLer--;
            }
        }
    } 
    
    function HODLerStatus(address _address) public view returns (bool){
        if(!Info[_address].Withdrawn && ( Info[_address].TokenBalance  >= ((totalInitialSupply * 5).div(100)))    ){
           return true;
        }
        return false;
    }
    
    function HowmanyStakers(){
        numofStakers = Stakers.length;
    }
    
    function Penalty(uint256 _percentage) internal{
        penaltyAmount = (Info[msg.sender].TokenBalance * _percentage).div(100);     
        Info[msg.sender].TokenBalance = (Info[msg.sender].TokenBalance).sub(penaltyAmount);         //adjust the weak HODLers' TokenBalance.
        penaltyFund += penaltyAmount;      
    }

    function StakerExist(address _address) public view returns (bool) {
        if (Stakers.length == 0)
            return false;

        return (Stakers[Info[_address].StakerId] == _address);
    }

    function addStaker(address _address) internal returns (uint256) {
        require( _address != address(0));

        if (!StakerExist(_address)) {
            var newStaker = StakerInfo(Stakers.length, _address, 0, 0, 0, 0, false, false, false);
            Info[_address] = newStaker ;
            Stakers.push(_address);
            return newStaker.StakerId;
        }
    }

    

    
    //############################################################################################################################################################
    // 
    //  Contract owner functions:
    //

    
    function OwnerWithdraw(uint256 _amountToDraw) onlyOwner returns (bool) {
        owner.transfer(_amountToDraw);
        return true;
    }



     // ----------------------------------------------------------------------------------
     // ReleaseALL:  Releases the contract balance to the owners wallet address
     // Note: this is a function used while testing incase things go wrong, to avoid 
     // loosing coins in a contract that cant be interacted with.
     // ----------------------------------------------------------------------------------
    function ReleaseALL() onlyOwner {
        owner.transfer(address(this).balance);
    }
    
    function ReleaseSOME(uint _some) onlyOwner {
        owner.transfer(_some);
    }
    
    function OwnerDeposit() payable onlyOwner {
    }

    //############################################################################################################################################################
    //
    //  Contract staker functions:
    //


     // ----------------------------------------------------------------------------------
     // testOverPay:
     //     tests to if the amount deposited by the msg.sender if more than the remaining
     //     tokens available for purchase. If > then places difference in "DepositDiff"
     //     and issues the available amount.
     // ----------------------------------------------------------------------------------
     function testOverPay(uint256 _amount) public view returns(uint){
        
        Depositdiff = 0;
        amountInTokens = _amount.div(ratio);
        
        if (amountInTokens >  (Info[owner].TokenBalance)){
            Depositdiff = (amountInTokens.sub(Info[owner].TokenBalance)).mul(ratio);
            _amount = (Info[owner].TokenBalance).mul(ratio);
            
        }  
        return _amount;
    }   
    

    /**
     * Fallback function
     *
     * The function without name is the default function that is called whenever anyone sends funds to a contract
     */
    
    // ----------------------------------------------------------------------------------
    // Fallback function:
    //  The function without name is the default function that is called whenever 
    //  anyone sends funds to a contract, this happens to be the funcion we use for 
    //  deposits of coins in exchange for tokens.
    // ---------------------------------------------------------------------------------- 
    function () payable {

        require(ContractStatusOpen);                                            //require that the contract be live from the owners perspective.

        addStaker(msg.sender);                                                  //test if Staker exists and if not add to Stakers list with clean slate.
        
        uint256 amount = msg.value;
        amount = testOverPay(amount);
        
        amountdiv = amount.div(ratio);
        
        Info[msg.sender].GemDifference += Depositdiff;
        
        Info[msg.sender].StakeTime = now;
        
        allowed[owner][msg.sender] = amountdiv;                                 // allows _address to transferFrom(...)  "(amount.div(ratio))" tokens from Owner to themselves.
        Approval(owner, msg.sender, amountdiv);                                 // pulish Event.

        transferFrom(owner, msg.sender, amountdiv);
        
        if(HODLerStatus(msg.sender)){
            Info[msg.sender].Status = true;
        }

        HowmanyStakers();                                                       //make the Staker pay the Gas to update the number of stakers variable.
    }
    
    
    // ----------------------------------------------------------------------------------
    // StakerRefundOverPaid:  allows the staker refund themselves the difference if 
    // they have overpaid in deposit coins.
    // ----------------------------------------------------------------------------------
    function StakerRefundOverPaid()  {
        msg.sender.transfer(Info[msg.sender].GemDifference);
        Info[msg.sender].GemDifference = 0;
    } 
    
    
    // ----------------------------------------------------------------------------------
    // StakerRedeemToken:  allows the staker to redeem their tokens for equivalent coins
    // propertional to yield amount.
    // ----------------------------------------------------------------------------------
    function StakerRedeemToken(uint _tokens) returns (bool) { 
        require(_tokens > 0);   //inout toekn value needs to be positive.

        if((Info[msg.sender].TokenBalance) == 0 ) return false;                                                 //staker has to have positive token balance.
        
        if(PoWHolders){                                                                                         //if this is a PoWHODLers contract then apply the metrics
            if(HODLerStatus(msg.sender)){
                HasStakerWithdrawnBefore(msg.sender);                                                           //work out if Staker is the last HODLer
            }else {
                HODLer == 0;                                                                                    //if the Stkaer does not meet HODLer status then they cant be the last HODLer anyway
            }           
            
            
            if(HODLer == 1){
                isLastHODler = true;
                Info[msg.sender].TokenBalance = (Info[msg.sender].TokenBalance).add(penaltyFund);
                penaltyAmount = 0;
                _tokens = _tokens.add(penaltyFund);
                penaltyFund = 0;                                                                                //penaltyFund now drained and awarded to lst HODLer
            } else {
                
                uint256 _coinAge = coinAge(msg.sender);
                
                if (_coinAge <= stakeMaxAge){
                    Penalty(penaltyBefore);
                } 
                else if (_coinAge > stakeMaxAge){
                    Penalty(penaltyAfter);
                }
                
                _tokens = _tokens.sub(penaltyAmount);
                isLastHODler = false;
            }
        }
        
        Info[msg.sender].TokenBalance = (Info[msg.sender].TokenBalance).sub(_tokens);                           //sets the balance of the staker to whatever it was minus the amount they are redeeming.
        Info[owner].TokenBalance = (Info[owner].TokenBalance).add(_tokens);                                     // adds the tokens back to the contract    
        
        msg.sender.transfer(_tokens.mul(ratio));                                                                //transfer Staker their Gems.
        
        Info[msg.sender].Withdrawn = true;  
        Info[msg.sender].Status = HODLerStatus(msg.sender);                                                     //update the msg.sender status.
        
        return true;
    }









}
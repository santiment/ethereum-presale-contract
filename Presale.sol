pragma solidity ^0.4.6;

// Presale Smart Contract
//
// this contract manages pre-sale crowdfunding

contract Presale {
   string public __VERSION = "0.1.1";

    mapping (address => uint) public balances;
    uint public presale_start;
    uint public presale_end;
    uint public withdrawal_end;

    uint public total_received_amount;

    uint public MIN_TOTAL_AMOUNT_TO_RECEIVE = 5000 ether;
    uint public MAX_TOTAL_AMOUNT_TO_RECEIVE = 15000 ether;
    uint public MIN_ACCEPTED_AMOUNT = 1 finney;

    address public owner;


    function Presale (uint _presale_start, uint _presale_end, uint _withdrawal_end, address _owner)
    inFutureOnly(_presale_start)
    validSetupOnly(_presale_start, _presale_end, _withdrawal_end, _owner)
    {
        presale_start = _presale_start;
        presale_end   = _presale_end;
        withdrawal_end = _withdrawal_end;
        owner = _owner;
    }


    function ()
    payable
    onPresaleRunningOnly
    notTooSmallAmountOnly
    {
        // no overflow is possible here: nobody have soo much money to spend.
        if (total_received_amount + msg.value > MAX_TOTAL_AMOUNT_TO_RECEIVE) {
            // accept amount only and return change
            var change_to_return = total_received_amount + msg.value - MAX_TOTAL_AMOUNT_TO_RECEIVE;
            if (!msg.sender.send(change_to_return)) throw;

            var acceptable_remainder = MAX_TOTAL_AMOUNT_TO_RECEIVE - total_received_amount;
            balances[msg.sender] += acceptable_remainder;
            total_received_amount += acceptable_remainder;
        } else {
            // accept full amount
            balances[msg.sender] += msg.value;
            total_received_amount += msg.value;
        }
    }


    function refund()
    refundConditionsAreMet
    tokenHoldersOnly
    {
        // load balance to refund
        var amount_to_refund = balances[msg.sender];

        // reset balance
        balances[msg.sender] = 0;

        // send refund back to sender
        if (!msg.sender.send(amount_to_refund)) throw;
    }


    function withdrawFunds()
    onPresaleSuccessOnly
    onlyOwner
    {
        // transfer funds to owner if any
        if (this.balance > 0) {
            if (!owner.send(this.balance)) throw;
        }
    }

    // ============ modifiers ============

    //fails if something is looking weird
    modifier validSetupOnly(uint _presale_start, uint _presale_end, uint _withdrawal_end, address _owner) {
        if (_presale_start >= _presale_end) throw;
        if (_presale_end   >= _withdrawal_end) throw;
        if (_owner == 0) throw;
        _;
    }

    //fails start block number is already passed
    modifier inFutureOnly(uint block_number) {
        if (block_number <= block.number) throw;
        _;
    }

    //accepts calls from owner only
    modifier onlyOwner(){
    	if (msg.sender != owner)  throw;
    	_;
    }

    //accepts calls from token holders only
    modifier tokenHoldersOnly(){
    	if (balances[msg.sender] == 0) throw;
    	_;
    }

    modifier refundConditionsAreMet() {
    	// no refund before presale finished
    	if (block.number < presale_end) throw;
    	// else if presale succeed, no refund before owners withdrawal finished
    	else if (total_received_amount >= MIN_TOTAL_AMOUNT_TO_RECEIVE && block.number < withdrawal_end) throw;
    	// otherwise accept refund request
    	_;
    }

    modifier onPresaleRunningOnly() {
        // fails if presale has not started yet
        if (block.number < presale_start) throw;

        // fails if presale is over
        if (block.number >= presale_end) throw;

        // fails if max goal is already reached
        if (total_received_amount >= MAX_TOTAL_AMOUNT_TO_RECEIVE) throw;
        _;
    }


    modifier onPresaleSuccessOnly() {
        // fails if min goal is not reached
        if (total_received_amount < MIN_TOTAL_AMOUNT_TO_RECEIVE) throw;

        // fails if presale is still running AND max goal is not met yet
        if (block.number < presale_end && total_received_amount < MAX_TOTAL_AMOUNT_TO_RECEIVE) throw;

        _;
    }


    modifier notTooSmallAmountOnly(){
        // don`t accept transactions with value less than allowed minimum
        if (msg.value < MIN_ACCEPTED_AMOUNT) throw;
        _;
    }


}//contract

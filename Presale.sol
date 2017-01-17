pragma solidity ^0.4.6;

// Presale Smart Contract
//
// @author ethernian

contract Presale {
    string public constant VERSION = "0.1.1";

    mapping (address => uint) public balances;
    uint public presale_start;
    uint public presale_end;
    uint public withdrawal_end;

    uint public total_received_amount;

    uint public constant MIN_TOTAL_AMOUNT_TO_RECEIVE_ETH = 5000;
    uint public constant MAX_TOTAL_AMOUNT_TO_RECEIVE_ETH = 15000;
    uint public constant MIN_ACCEPTED_AMOUNT = 1 finney;

    address public owner;

    uint private constant MIN_TOTAL_AMOUNT_TO_RECEIVE = MIN_TOTAL_AMOUNT_TO_RECEIVE_ETH * 1 ether;
    uint private constant MAX_TOTAL_AMOUNT_TO_RECEIVE = MAX_TOTAL_AMOUNT_TO_RECEIVE_ETH * 1 ether;

    string[4] private stateNames = ["BEFORE_START",  "PRESALE_RUNNING", "WITHDRAWAL_RUNNING", "REFUND_RUNNING" ];
    enum State { BEFORE_START,  PRESALE_RUNNING, WITHDRAWAL_RUNNING, REFUND_RUNNING }

    //constructor
    function Presale (uint _presale_start, uint _presale_end, uint _withdrawal_end, address _owner)
    inFutureOnly(_presale_start)
    validSetupOnly(_presale_start, _presale_end, _withdrawal_end, _owner)
    {
        presale_start = _presale_start;
        presale_end   = _presale_end;
        withdrawal_end = _withdrawal_end;
        owner = _owner;
    }

    //
    // ======= interface methods =======
    //

    //accept payments here
    function ()
    payable
    noReentrancy
    {
        State state = currentState();
        if (state == State.PRESALE_RUNNING) {
            receiveFunds();
        } else if (state == State.REFUND_RUNNING) {
            // any entring call in Refund Phase will cause full refund
            sendRefund();
        } else {
            throw;
        }
    }

    function refund() external
    inState(State.REFUND_RUNNING)
    noReentrancy
    {
        sendRefund();
    }


    function withdrawFunds() external
    inState(State.WITHDRAWAL_RUNNING)
    onlyOwner
    noReentrancy
    {
        // transfer funds to owner if any
        if (this.balance > 0) {
            if (!owner.send(this.balance)) throw;
        }
    }


    //displays current contract state in human readable form
    function state()  external constant
    returns (string)
    {
        return stateNames[ uint(currentState()) ];
    }


    //
    // ======= implementation methods =======
    //

    function sendRefund() private tokenHoldersOnly {
        // load balance to refund plus amount currently sent
        var amount_to_refund = balances[msg.sender] + msg.value;
        // reset balance
        balances[msg.sender] = 0;
        // send refund back to sender
        if (!msg.sender.send(amount_to_refund)) throw;
    }


    function receiveFunds() private notTooSmallAmountOnly {
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


    function currentState() private constant returns (State) {
        if (block.number < presale_start) {
            return State.BEFORE_START;
        } else if (block.number <= presale_end && total_received_amount < MAX_TOTAL_AMOUNT_TO_RECEIVE) {
            return State.PRESALE_RUNNING;
        } else if (block.number <= withdrawal_end && total_received_amount >= MIN_TOTAL_AMOUNT_TO_RECEIVE) {
            return State.WITHDRAWAL_RUNNING;
        } else {
            return State.REFUND_RUNNING;
        }
    }

    //
    // ============ modifiers ============
    //

    //fails if state dosn't match
    modifier inState(State state) {
        if (state != currentState()) throw;
        _;
    }


    //fails if something is looking weird
    modifier validSetupOnly(uint _presale_start, uint _presale_end, uint _withdrawal_end, address _owner) {
        if (_presale_start >= _presale_end) throw;
        if (_presale_end   >= _withdrawal_end) throw;
        if (_owner == 0) throw;
        if (MIN_TOTAL_AMOUNT_TO_RECEIVE > MAX_TOTAL_AMOUNT_TO_RECEIVE) throw;
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


    // don`t accept transactions with value less than allowed minimum
    modifier notTooSmallAmountOnly(){
        if (msg.value < MIN_ACCEPTED_AMOUNT) throw;
        _;
    }


    //prevents reentrancy attacs
    bool private locked = false;
    modifier noReentrancy() {
        if (locked) throw;
        locked = true;
        _;
        locked = false;
    }
}//contract

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {
    event Deposit(address indexed sender, uint amount);
    event SubmitTransaction(uint indexed txIndex, address indexed to, uint value, bytes data);
    event ConfirmTransaction(address indexed owner, uint indexed txIndex);
    event ExecuteTransaction(uint indexed txIndex);
    event OwnerReplaced(address indexed oldOwner, address indexed newOwner);

    address[5] public owners;
    mapping(address => bool) public isOwner;
    uint public required = 3;

    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint confirmations;
    }

    Transaction[] public transactions;
    mapping(uint => mapping(address => bool)) public confirmations;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "Transaction does not exist");
        _;
    }

    modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "Transaction already executed");
        _;
    }

    modifier notConfirmed(uint _txIndex) {
        require(!confirmations[_txIndex][msg.sender], "Transaction already confirmed");
        _;
    }

    constructor(address[5] memory _owners) {
        for (uint i = 0; i < 5; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Zero address not allowed");
            require(!isOwner[owner], "Duplicate owner");
            isOwner[owner] = true;
            owners[i] = owner;
        }
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(address _to, uint _value, bytes calldata _data) external onlyOwner {
        uint txIndex = transactions.length;
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        }));

        emit SubmitTransaction(txIndex, _to, _value, _data);
    }

    function confirmTransaction(uint _txIndex)
        external
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
        notConfirmed(_txIndex)
    {
        confirmations[_txIndex][msg.sender] = true;
        transactions[_txIndex].confirmations += 1;
        emit ConfirmTransaction(msg.sender, _txIndex);
    }

    function executeTransaction(uint _txIndex)
        external
        onlyOwner
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        Transaction storage txn = transactions[_txIndex];
        require(txn.confirmations >= required, "Not enough confirmations");

        txn.executed = true;

        (bool success, ) = txn.to.call{value: txn.value}(txn.data);
        require(success, "Transaction failed");

        emit ExecuteTransaction(_txIndex);
    }

    function replaceOwner(address _oldOwner, address _newOwner) external onlyOwner {
        require(isOwner[_oldOwner], "Old address not owner");
        require(!isOwner[_newOwner], "New address already owner");
        require(_newOwner != address(0), "Zero address not allowed");

        for (uint i = 0; i < 5; i++) {
            if (owners[i] == _oldOwner) {
                owners[i] = _newOwner;
                break;
            }
        }

        isOwner[_oldOwner] = false;
        isOwner[_newOwner] = true;

        emit OwnerReplaced(_oldOwner, _newOwner);
    }

    // View helpers
    function getTransactionCount() external view returns (uint) {
        return transactions.length;
    }

    function getTransaction(uint _txIndex)
        external
        view
        returns (
            address to,
            uint value,
            bytes memory data,
            bool executed,
            uint confirmationsCount
        )
    {
        Transaction storage txn = transactions[_txIndex];
        return (txn.to, txn.value, txn.data, txn.executed, txn.confirmations);
    }
}

pragma solidity ^0.4.18;

import './ApisTokenNoImport.sol';


contract MultiSigApis {
    
    event WithdrawalSubmission(uint indexed withdrawalId, address destination, uint256 aApis);
    event WithdrawalConfirmation(address indexed owner, uint indexed withdrawalId);
    event WithdrawalRevocation(address indexed owner, uint indexed withdrawalId);
    event WithdrawalExecution(uint indexed withdrawalId);
    event RequirementChangeSubmission(uint indexed requiredChangeId, uint require);
    event RequirementChangeConfirmation(address indexed owner, uint indexed changeId);
    event RequirementChangeRevocation(address indexed owner, uint indexed changeId);
    event RequirementChangeExecution(uint changeId);
    event OwnerChangeSubmission(uint indexed ownerChangeId, address indexed owner, string message);
    event OwnerChangeConfirmation(address indexed owner, uint indexed changeId);
    event OwnerChangeRevocation(address indexed owner, uint indexed changeId);
    event OwnerAddition(address indexed owner);
    event OwnerRemoval(address indexed owner);
    
    
    uint constant public MAX_OWNER_COUNT = 50;
    
    
    
    
    mapping(uint => Withdrawal) public withdrawals;
    mapping(uint => OwnerChange) public ownerChanges;
    mapping(uint => RequirementChange) public requirementChanges;
    mapping(uint => mapping (address => bool)) public confirmations;
    mapping(uint => mapping (address => bool)) public ownerChangeConfirmations;
    mapping(uint => mapping (address => bool)) public requirementChangeConfirmations;
    mapping(address => bool) public isOwner;
    address[] public owners;
    uint public required;
    uint public withdrawalCount;
    uint public requirementChangeCount;
    uint public ownerChangeCount;
    ApisToken apisToken;
    
    
    struct Withdrawal {
        address destination;
        uint aapis;
        bool executed;
    }
    
    struct OwnerChange {
        address owner;
        bool isAdd;
        bool executed;
    }
    
    struct RequirementChange {
        uint requirement;
        bool executed;
    }
    
    
    /**
     * @dev 함수 실행자가 owner 목록에 존재하는지 확인한다.
     */
    modifier ownerExists(address _owner) {
        require(isOwner[_owner]);
        _;
    }
    
    modifier notNull(address _address) {
        require(_address != 0);
        _;
    }
        
    modifier validRequirement (uint _ownerCount, uint _required) {
        require(_ownerCount <= MAX_OWNER_COUNT
            && _required <= _ownerCount
            && _required != 0
            && _ownerCount != 0);
        _;
    }
    
    modifier withdrawalExists(uint _withdrawalId) {
        require(withdrawals[_withdrawalId].destination != 0);
        _;
    }
    
    modifier confirmedWithdrawal(uint _withdrawalId, address _owner) {
        require(confirmations[_withdrawalId][_owner]);
        _;
    }
    
    modifier notConfirmedWithdrawal(uint _withdrawalId, address _owner) {
        require(!confirmations[_withdrawalId][_owner]);
        _;
    }
    
    modifier notExecutedWithdrawal(uint _withdrawalId) {
        require(!withdrawals[_withdrawalId].executed);
        _;
    }
    
    modifier ownerDoesNotExist(address owner) {
        require(!isOwner[owner]);
        _;
    }
    
    modifier confirmedRequirement(uint _changeId, address _owner) {
        require(requirementChangeConfirmations[_changeId][_owner]);
        _;
    }
    
    modifier notConfirmedRequirement(uint _changeId, address _owner) {
        require(!requirementChangeConfirmations[_changeId][_owner]);
        _;
    }
    
    modifier notExecutedRequirement(uint _changeId) {
        require(!requirementChanges[_changeId].executed);
        _;
    }
    
    
    modifier confirmedOwnerChange(uint _changeId, address _owner) {
        require(ownerChangeConfirmations[_changeId][_owner]);
        _;
    }
    
    modifier notConfirmedOwnerChange(uint _changeId, address _owner) {
        require(!ownerChangeConfirmations[_changeId][_owner]);
        _;
    }
    
    modifier notExecutedOwnerChange(uint _changeId) {
        require(!ownerChanges[_changeId].executed);
        _;
    }
    
    
    
    /**
     * @dev Prevent ETH deposits.
     */
    function() public payable {
        revert();
    }
    
    
    /**
     * @dev Contract constructor sets initial owners and required number of confirmations.
     * @param _owners List of initial owners.
     * @param _required Number of required confirmations.
     */
    function MultisigApis(address[] _owners, uint _required, address _apisToken) 
        public 
        validRequirement(_owners.length, _required) 
    {
        require(owners.length == 0 && required == 0);
        require(_apisToken != 0x0);
        
        for (uint i = 0; i < _owners.length; i++) {
            require(!isOwner[_owners[i]] && _owners[i] != 0);
            isOwner[_owners[i]] = true;
        }
        
        owners = _owners;
        required = _required;
        apisToken = ApisToken(_apisToken);
    }
    
    
    /**
     * @dev Allows an owner to submit and confirm a withdrawal
     */
    function registerWithdrawal(address _destination, uint256 _aapis) 
        public 
        notNull(_destination) 
        ownerExists(msg.sender) 
        returns (uint withdrawalId) 
    {
        withdrawalId = withdrawalCount;
        withdrawals[withdrawalId] = Withdrawal({
            destination : _destination,
            aapis : _aapis,
            executed : false
        });
        
        withdrawalCount += 1;
        emit WithdrawalSubmission(withdrawalId, _destination, _aapis);
        
        confirmWithdrawal(withdrawalId);
    }
    
    /**
     * @dev Allows an owner to confirm a withdrawal
     * @param _withdrawalId Withdrawal ID
     */
    function confirmWithdrawal(uint _withdrawalId) 
        public
        ownerExists(msg.sender) 
        withdrawalExists(_withdrawalId)
        notConfirmedWithdrawal(_withdrawalId, msg.sender)
    {
        confirmations[_withdrawalId][msg.sender] = true;
        emit WithdrawalConfirmation(msg.sender, _withdrawalId);
        
        executeWithdrawal(_withdrawalId);
    }
    
    
    /**
     * @dev Allows an owner to revoke a confirmation for a transaction
     * @param _withdrawalId Withdrawal ID
     */
    function revokeConfirmation(uint _withdrawalId)
        public
        ownerExists(msg.sender)
        confirmedWithdrawal(_withdrawalId, msg.sender)
        notExecutedWithdrawal(_withdrawalId)
    {
        confirmations[_withdrawalId][msg.sender] = false;
        emit WithdrawalRevocation(msg.sender, _withdrawalId);
    }
    
    
    /**
     * @dev Allows an owner to execute a confirmed withdrawal
     * @param _withdrawalId withdrawal ID
     */
    function executeWithdrawal(uint _withdrawalId)
        public
        ownerExists(msg.sender)
        confirmedWithdrawal(_withdrawalId, msg.sender)
        notExecutedWithdrawal(_withdrawalId)
    {
        if(isConfirmed(_withdrawalId)) {
            Withdrawal storage withdrawal = withdrawals[_withdrawalId];
            assert(apisToken.transfer(withdrawal.destination, withdrawal.aapis));
            withdrawal.executed = true;
            
            emit WithdrawalExecution(_withdrawalId);
        }
    }
    
    /** 
     * @dev Returns the confirmation status of a withdrawal.
     * @param _withdrawalId Withdrawal ID.
     * @return Confirmation status.
     */
    function isConfirmed(uint _withdrawalId)
        public
        constant
        returns (bool)
    {
        uint count = 0;
        for (uint i = 0; i < owners.length; i++) {
            if (confirmations[_withdrawalId][owners[i]])
                count += 1;
            if (count == required)
                return true;
        }
    }
    
    function balanceOfThisWallet() public constant returns (uint256 aApis) {
        return apisToken.balanceOf(this);
    }
    
    
    //-------------------------------------------------------------
    function registerRequirementChange(uint _requirement) 
        public
        ownerExists(msg.sender)
        validRequirement(owners.length, _requirement)
        returns (uint requirementChangeId)
    {
        requirementChangeId = requirementChangeCount;
        requirementChanges[requirementChangeId] = RequirementChange({
            requirement : _requirement,
            executed : false
        });
        
        requirementChangeCount += 1;
        emit RequirementChangeSubmission(requirementChangeId, _requirement);
        
        confirmRequirementChange(requirementChangeId);
    }
    
    
    function confirmRequirementChange(uint _changeId) 
        public
        ownerExists(msg.sender)
        notConfirmedRequirement(_changeId, msg.sender)
    {
        requirementChangeConfirmations[_changeId][msg.sender] = true;
        emit RequirementChangeConfirmation(msg.sender, _changeId);
        
        executeRequirementChange(_changeId);
    }
    
    function revokeRequirementChangeConfirmation(uint _changeId) 
        public 
        ownerExists(msg.sender)
        confirmedRequirement(_changeId, msg.sender)
    {
        requirementChangeConfirmations[_changeId][msg.sender] = false;
        emit RequirementChangeRevocation(msg.sender, _changeId);
    }
    
    
    function executeRequirementChange(uint _changeId)
        public
        ownerExists(msg.sender)
        confirmedRequirement(_changeId, msg.sender)
        notExecutedRequirement(_changeId)
    {
        if(isRequirementChangeConfirmed(_changeId)) {
            RequirementChange storage requirementChange = requirementChanges[_changeId];
            
            required = requirementChange.requirement;
            requirementChange.executed = true;
            
            emit RequirementChangeExecution(_changeId);
        }
    }
    
    
    function isRequirementChangeConfirmed(uint _changeId) 
        public
        constant
        returns (bool)
    {
        uint count = 0;
        for(uint i = 0; i < owners.length; i++) {
            if(requirementChangeConfirmations[_changeId][owners[i]])
                count += 1;
            if(count == required)
                return true;
        }
    }
    
    
    //-------------------------------------------------------------
    function registerOwnerAdd(address _owner) 
        public 
        ownerExists(msg.sender)
        notNull(_owner)
        ownerDoesNotExist(_owner)
        returns (uint ownerChangeId)
    {
        return registerChangeOwner(_owner, true);
    }
    
    function registerOwnerRemove(address _owner) 
        public 
        ownerExists(msg.sender)
        notNull(_owner)
        ownerExists(_owner)
        returns (uint ownerChangeId)
    {
        return registerChangeOwner(_owner, false);
    }
    
    function registerChangeOwner(address _owner, bool _isAdd) 
        internal 
        ownerExists(msg.sender)
        returns (uint ownerChangeId)
    {
        ownerChangeId = ownerChangeCount;
        
        ownerChanges[ownerChangeId] = OwnerChange({
            owner : _owner,
            isAdd : _isAdd,
            executed : false
        });
        
        ownerChangeCount += 1;
        if(_isAdd) {
            emit OwnerChangeSubmission(ownerChangeId, _owner, "Add");
        } else {
            emit OwnerChangeSubmission(ownerChangeId, _owner, "Remove");
        }
        
        confirmOwnerChange(ownerChangeId);
    }
    
    
    function confirmOwnerChange(uint _changeId) 
        public
        ownerExists(msg.sender)
        notConfirmedOwnerChange(_changeId, msg.sender)
    {
        ownerChangeConfirmations[_changeId][msg.sender] = true;
        emit OwnerChangeConfirmation(msg.sender, _changeId);
        
        executeOwnerChange(_changeId);
    }
    
    function revokeOwnerChangeConfirmation(uint _changeId) 
        public
        ownerExists(msg.sender)
        confirmedOwnerChange(_changeId, msg.sender)
    {
        ownerChangeConfirmations[_changeId][msg.sender] = false;
        emit OwnerChangeRevocation(msg.sender, _changeId);
    }
    
    function executeOwnerChange(uint _changeId) 
        public
        ownerExists(msg.sender)
        confirmedOwnerChange(_changeId, msg.sender)
        notExecutedOwnerChange(_changeId)
    {
        if(isOwnerChangeConfirmed(_changeId)) {
            OwnerChange storage ownerChange = ownerChanges[_changeId];
            
            if(ownerChange.isAdd) {
                addOwner(ownerChange.owner);
            }
            else {
                removeOwner(ownerChange.owner);
            }
            
            ownerChange.executed = true;
        }
    }
    
    
    function isOwnerChangeConfirmed(uint _changeId) 
        public
        constant
        returns (bool)
    {
        uint count = 0;
        for(uint i = 0; i < owners.length; i++) {
            if(ownerChangeConfirmations[_changeId][owners[i]])
                count += 1;
            if(count == required) 
                return true;
        }
    }
    
    
    function addOwner(address _owner) 
        internal
        notNull(_owner)
        ownerDoesNotExist(_owner)
        validRequirement(owners.length + 1, required)
    {
        isOwner[_owner] = true;
        owners.push(_owner);
        
        emit OwnerAddition(_owner);
    }
    
    
    function removeOwner(address _owner) 
        internal 
        ownerExists(_owner)
    {
        isOwner[_owner] = false;
        
        for(uint i =0 ; i < owners.length; i++) {
            if(owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                break;
            }
        }
        
        owners.length -= 1;
        
        emit OwnerRemoval(_owner);
    }
}
pragma solidity ^0.4.18;

import './StandardToken.sol';
import './Ownable.sol';


/**
 * @title APIS Token
 * @dev APIS ��ū�� �����Ѵ�
 */
contract ApisToken is StandardToken, Ownable {
    // ��ū�� �̸� (Advanced Property Investment System)
    string public constant name = "Advanced Property Investment System";
    
    // ��ū�� ���� (APIS)
    string public constant symbol = "APIS";
    
    // �Ҽ��� �ڸ���. ETH 18�ڸ��� �����
    uint8 public constant decimals = 18;
    
    // �������� �۱�/���� ����� ��� ���θ� ����
    mapping (address => LockedInfo) public lockedWalletInfo;
    
    /**
     * @dev �÷������� ��ϴ� �����ͳ�� ����Ʈ ��Ʈ��Ʈ �ּ�
     */
    mapping (address => bool) public manoContracts;
    
    
    /**
     * @dev ��ū ������ ��� �Ӽ��� ����
     * 
     * @param timeLockUpEnd timeLockUpEnd �ð����� ��/���ݿ� ���� ������ ����ȴ�. ���Ŀ��� ������ Ǯ����
     * @param sendLock ��� ��� ����(true : ���, false : Ǯ��)
     * @param receiveLock �Ա� ��� ���� (true : ���, false : Ǯ��)
     */
    struct LockedInfo {
        uint timeLockUpEnd;
        bool sendLock;
        bool receiveLock;
    } 
    
    
    /**
     * @dev ��ū�� �۱ݵ��� �� �߻��ϴ� �̺�Ʈ
     * @param from ��ū�� ������ ���� �ּ�
     * @param to ��ū�� �޴� ���� �ּ�
     * @param value ���޵Ǵ� ��ū�� �� (Satoshi)
     */
    event Transfer (address indexed from, address indexed to, uint256 value);
    
    /**
     * @dev ��ū ������ �۱�/�Ա� ����� ���ѵǾ��� �� �߻��ϴ� �̺�Ʈ
     * @param target ���� ��� ���� �ּ�
     * @param timeLockUpEnd ������ ����Ǵ� �ð�(UnixTimestamp)
     * @param sendLock ���������� �۱��� �����ϴ��� ����(true : ����, false : ����)
     * @param receiveLock ���������� �Ա��� �����ϴ��� ���� (true : ����, false : ����)
     */
    event Locked (address indexed target, uint timeLockUpEnd, bool sendLock, bool receiveLock);
    
    /**
     * @dev ������ ���� �۱�/�Ա� ������ �������� �� �߻��ϴ� �̺�Ʈ
     * @param target ���� ��� ���� �ּ�
     */
    event Unlocked (address indexed target);
    
    /**
     * @dev �۱� �޴� ������ �Ա��� ���ѵǾ��־ �۱��� �����Ǿ��� �� �߻��ϴ� �̺�Ʈ
     * @param from ��ū�� ������ ���� �ּ�
     * @param to (�Ա��� ���ѵ�) ��ū�� �޴� ���� �ּ�
     * @param value �����Ϸ��� �� ��ū�� ��(Satoshi)
     */
    event RejectedPaymentToLockedUpWallet (address indexed from, address indexed to, uint256 value);
    
    /**
     * @dev �۱��ϴ� ������ ����� ���ѵǾ��־ �۱��� �����Ǿ��� �� �߻��ϴ� �̺�Ʈ
     * @param from (����� ���ѵ�) ��ū�� ������ ���� �ּ�
     * @param to ��ū�� �޴� ���� �ּ�
     * @param value �����Ϸ��� �� ��ū�� ��(Satoshi)
     */
    event RejectedPaymentFromLockedUpWallet (address indexed from, address indexed to, uint256 value);
    
    /**
     * @dev ��ū�� �Ұ��Ѵ�. 
     * @param burner ��ū�� �Ұ��ϴ� ���� �ּ�
     * @param value �Ұ��ϴ� ��ū�� ��(Satoshi)
     */
    event Burn (address indexed burner, uint256 value);
    
    /**
     * @dev ���ǽ� �÷����� �����ͳ�� ����Ʈ ��Ʈ��Ʈ�� ��ϵǰų� ������ �� �߻��ϴ� �̺�Ʈ
     */
    event ManoContractRegistered (address manoContract, bool registered);
    
    /**
     * @dev ��Ʈ��Ʈ�� ������ �� ����. ��Ʈ��Ʈ ������ ������ ��� ��ū�� �Ҵ��Ѵ�.
     * ���෮�̳� �̸��� �ҽ��ڵ忡�� Ȯ���� �� �ֵ��� �����Ͽ���
     */
    function ApisToken() public {
        // �� APIS ���෮ (95�� 2õ��)
        uint256 supplyApis = 9520000000;
        
        // wei ������ ��ū �ѷ��� �����Ѵ�.
        totalSupply = supplyApis * 10 ** uint256(decimals);
        
        balances[msg.sender] = totalSupply;
        
        Transfer(0x0, msg.sender, totalSupply);
    }
    
    
    /**
     * @dev ������ ������ �ð����� ���ѽ�Ű�ų� ������Ų��. ���� �ð��� ����ϸ� ��� ������ �����ȴ�.
     * @param _targetWallet ������ ������ ���� �ּ�
     * @param _timeLockEnd ������ ����Ǵ� �ð�(UnixTimestamp)
     * @param _sendLock (true : �������� ��ū�� ����ϴ� ����� �����Ѵ�.) (false : ������ �����Ѵ�)
     * @param _receiveLock (true : �������� ��ū�� �Աݹ޴� ����� �����Ѵ�.) (false : ������ �����Ѵ�)
     */
    function walletLock(address _targetWallet, uint _timeLockEnd, bool _sendLock, bool _receiveLock) onlyOwner public {
        require(_targetWallet != 0x0);
        
        // If all locks are unlocked, set the _timeLockEnd to zero.
        if(_sendLock == false && _receiveLock == false) {
            _timeLockEnd = 0;
        }
        
        lockedWalletInfo[_targetWallet].timeLockUpEnd = _timeLockEnd;
        lockedWalletInfo[_targetWallet].sendLock = _sendLock;
        lockedWalletInfo[_targetWallet].receiveLock = _receiveLock;
        
        if(_timeLockEnd > 0) {
            Locked(_targetWallet, _timeLockEnd, _sendLock, _receiveLock);
        } else {
            Unlocked(_targetWallet);
        }
    }
    
    /**
     * @dev ������ �Ա�/����� ������ �ð����� ���ѽ�Ų��. ���� �ð��� ����ϸ� ��� ������ �����ȴ�.
     * @param _targetWallet ������ ������ ���� �ּ�
     * @param _timeLockUpEnd ������ ����Ǵ� �ð�(UnixTimestamp)
     */
    function walletLockBoth(address _targetWallet, uint _timeLockUpEnd) onlyOwner public {
        walletLock(_targetWallet, _timeLockUpEnd, true, true);
    }
    
    /**
     * @dev ������ �Ա�/����� ������(33658-9-27 01:46:39+00) ���ѽ�Ų��.
     * @param _targetWallet ������ ������ ���� �ּ�
     */
    function walletLockBothForever(address _targetWallet) onlyOwner public {
        walletLock(_targetWallet, 999999999999, true, true);
    }
    
    
    /**
     * @dev ������ ������ ����� ������ �����Ѵ�
     * @param _targetWallet ������ �����ϰ��� �ϴ� ���� �ּ�
     */
    function walletUnlock(address _targetWallet) onlyOwner public {
        walletLock(_targetWallet, 0, false, false);
    }
    
    /**
     * @dev ������ �۱� ����� ���ѵǾ��ִ��� Ȯ���Ѵ�.
     * @param _addr �۱� ���� ���θ� Ȯ���Ϸ��� ������ �ּ�
     * @return isSendLocked (true : ���ѵǾ� ����, ��ū�� ���� �� ����) (false : ���� ����, ��ū�� ���� �� ����)
     * @return until ����ִ� �ð�, UnixTimestamp
     */
    function isWalletLocked_Send(address _addr) public constant returns (bool isSendLocked, uint until) {
        require(_addr != 0x0);
        
        isSendLocked = (lockedWalletInfo[_addr].timeLockUpEnd > now && lockedWalletInfo[_addr].sendLock == true);
        
        if(isSendLocked) {
            until = lockedWalletInfo[_addr].timeLockUpEnd;
        } else {
            until = 0;
        }
    }
    
    /**
     * @dev ������ �Ա� ����� ���ѵǾ��ִ��� Ȯ���Ѵ�.
     * @param _addr �Ա� ���� ���θ� Ȯ���Ϸ��� ������ �ּ�
     * @return (true : ���ѵǾ� ����, ��ū�� ���� �� ����) (false : ���� ����, ��ū�� ���� �� ����)
     */
    function isWalletLocked_Receive(address _addr) public constant returns (bool isReceiveLocked, uint until) {
        require(_addr != 0x0);
        
        isReceiveLocked = (lockedWalletInfo[_addr].timeLockUpEnd > now && lockedWalletInfo[_addr].receiveLock == true);
        
        if(isReceiveLocked) {
            until = lockedWalletInfo[_addr].timeLockUpEnd;
        } else {
            until = 0;
        }
    }
    
    /**
     * @dev ��û���� ������ �۱� ����� ���ѵǾ��ִ��� Ȯ���Ѵ�.
     * @return (true : ���ѵǾ� ����, ��ū�� ���� �� ����) (false : ���� ����, ��ū�� ���� �� ����)
     */
    function isMyWalletLocked_Send() public constant returns (bool isSendLocked, uint until) {
        return isWalletLocked_Send(msg.sender);
    }
    
    /**
     * @dev ��û���� ������ �Ա� ����� ���ѵǾ��ִ��� Ȯ���Ѵ�.
     * @return (true : ���ѵǾ� ����, ��ū�� ���� �� ����) (false : ���� ����, ��ū�� ���� �� ����)
     */
    function isMyWalletLocked_Receive() public constant returns (bool isReceiveLocked, uint until) {
        return isWalletLocked_Receive(msg.sender);
    }
    
    
    /**
     * @dev ���ǽ� �÷������� ��ϴ� ����Ʈ ��Ʈ��Ʈ �ּҸ� ����ϰų� �����Ѵ�.
     * @param manoAddr �����ͳ�� ����Ʈ ��Ʈ����Ʈ��Ʈ
     * @param registered true : ���, false : ����
     */
    function registerManoContract(address manoAddr, bool registered) onlyOwner public {
        manoContracts[manoAddr] = registered;
        
        ManoContractRegistered(manoAddr, registered);
    }
    
    
    /**
     * @dev _to �������� _apisWei ��ŭ�� ��ū�� �۱��Ѵ�.
     * @param _to ��ū�� �޴� ���� �ּ�
     * @param _apisWei ���۵Ǵ� ��ū�� ��
     */
    function transfer(address _to, uint256 _apisWei) public returns (bool) {
        // �ڽſ��� �۱��ϴ� ���� �����Ѵ�
        require(_to != address(this));
        
        // �����ͳ�� ��Ʈ��Ʈ�� ���, APIS �ۼ��ſ� ������ ���� �ʴ´�
        if(manoContracts[msg.sender] || manoContracts[_to]) {
            return super.transfer(_to, _apisWei);
        }
        
        // �۱� ����� ��� �������� Ȯ���Ѵ�.
        if(lockedWalletInfo[msg.sender].timeLockUpEnd > now && lockedWalletInfo[msg.sender].sendLock == true) {
            RejectedPaymentFromLockedUpWallet(msg.sender, _to, _apisWei);
            return false;
        } 
        // �Ա� �޴� ����� ��� �������� Ȯ���Ѵ�
        else if(lockedWalletInfo[_to].timeLockUpEnd > now && lockedWalletInfo[_to].receiveLock == true) {
            RejectedPaymentToLockedUpWallet(msg.sender, _to, _apisWei);
            return false;
        } 
        // ������ ���� ���, �۱��� �����Ѵ�.
        else {
            return super.transfer(_to, _apisWei);
        }
    }
    
    /**
     * @dev _to �������� _apisWei ��ŭ�� APIS�� �۱��ϰ� _timeLockUpEnd �ð���ŭ ������ ��ٴ�
     * @param _to ��ū�� �޴� ���� �ּ�
     * @param _apisWei ���۵Ǵ� ��ū�� ��(wei)
     * @param _timeLockUpEnd ����� �����Ǵ� �ð�
     */
    function transferAndLockUntil(address _to, uint256 _apisWei, uint _timeLockUpEnd) onlyOwner public {
        require(transfer(_to, _apisWei));
        
        walletLockBoth(_to, _timeLockUpEnd);
    }
    
    /**
     * @dev _to �������� _apisWei ��ŭ�� APIS�� �۱��ϰ����� ������ ��ٴ�
     * @param _to ��ū�� �޴� ���� �ּ�
     * @param _apisWei ���۵Ǵ� ��ū�� ��(wei)
     */
    function transferAndLockForever(address _to, uint256 _apisWei) onlyOwner public {
        require(transfer(_to, _apisWei));
        
        walletLockBothForever(_to);
    }
    
    
    /**
     * @dev �Լ��� ȣ���ϴ� ������ ��ū�� �Ұ��Ѵ�.
     * 
     * zeppelin-solidity/contracts/token/BurnableToken.sol ����
     * @param _value �Ұ��Ϸ��� ��ū�� ��(Satoshi)
     */
    function burn(uint256 _value) public {
        require(_value <= balances[msg.sender]);
        require(_value <= totalSupply);
        
        address burner = msg.sender;
        balances[burner] -= _value;
        totalSupply -= _value;
        
        Burn(burner, _value);
    }
    
    
    /**
     * @dev Eth�� ���� �� ������ �Ѵ�.
     */
    function () public payable {
        revert();
    }
}






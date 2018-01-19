pragma solidity ^0.4.18;

import './StandardToken.sol';
import './Ownable.sol';


/**
 * @title APIS Token
 * @dev APIS ��ū�� �����Ѵ�
 */
contract ApisToken is StandardToken, Ownable {
    // ��ū�� �̸� (Advanced Property Investment System)
    string public name;
    
    // ��ū�� ���� (APIS)
    string public symbol;
    
    // �Ҽ��� �ڸ���. QTUM 8�ڸ��� ����� (ETH�� ��� 18�ڸ�)
    uint8 public constant decimals = 8;
    
    // �������� �۱�/���� ����� ��� ���θ� ����
    mapping (address => LockedInfo) public lockedWalletInfo;
    
    struct LockedInfo {
        // timeLockUpEnd �ð����� ��/���ݿ� ���� ������ ����ȴ�. 
        // ���Ŀ��� ������ Ǯ����.
        uint timeLockUpEnd;
        
        // true : �������� �۱��� �� ����, false : �������� �۱��� �� ����
        bool sendLock;
        
        // true : �������� �Ա��� ����, false : �������� �Ա��� ����
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
     * @dev ��ū ��Ʈ��Ʈ�� ������ ������ ��� ��ū�� �Ҵ��Ѵ�.
     * @param _supply �� �����Ǵ� ��ū�� ��(APIS)
     */
    function ApisToken(uint256 _supply) public {
        // ��ū�� �̸��� ������ �����Ѵ�
        name = "Property Investment System";
        symbol = "APISTEST";
        
        // ����� ������ ��ū �ѷ��� �����Ѵ�.
        totalSupply = _supply * 10 ** uint256(decimals);
        
        balances[msg.sender] = totalSupply;
        
        Transfer(0x0, msg.sender, totalSupply);
    }
    
    
    /**
     * @dev ������ �Ա�/����� ������ �ð����� ���ѽ�Ų��. ���� �ð��� ����ϸ� ��� ������ �����ȴ�.
     * @param _targetWallet ������ ������ ���� �ּ�
     * @param _timeLockUpEnd ������ ����Ǵ� �ð�(UnixTimestamp)
     * @param _sendLock (true : �������� ��ū�� ����ϴ� ����� �����Ѵ�.) (false : ������ �����Ѵ�)
     * @param _receiveLock (true : �������� ��ū�� �Աݹ޴� ����� �����Ѵ�.) (false : ������ �����Ѵ�)
     */
    function walletLock(address _targetWallet, uint _timeLockUpEnd, bool _sendLock, bool _receiveLock) onlyOwner public {
        require(_targetWallet != 0x0);
        
        lockedWalletInfo[_targetWallet].timeLockUpEnd = _timeLockUpEnd;
        lockedWalletInfo[_targetWallet].sendLock = _sendLock;
        lockedWalletInfo[_targetWallet].receiveLock = _receiveLock;
        
        if(_timeLockUpEnd > 0) {
            Locked(_targetWallet, _timeLockUpEnd, _sendLock, _receiveLock);
        } else {
            Unlocked(_targetWallet);
        }
    }
    
    
    /**
     * @dev ������ ������ ����� ������ �����Ѵ�
     * @param _targetWallet ������ �����ϰ��� �ϴ� ���� �ּ�
     */
    function walletUnlock(address _targetWallet) onlyOwner public {
        walletLock(_targetWallet, 0, false, false);
    }
    
    
    
    /**
     * @dev _to �������� _value ��ŭ�� ��ū�� �۱��Ѵ�.
     * @param _to ��ū�� �޴� ���� �ּ�
     * @param _value ���۵Ǵ� ��ū�� �� (Satoshi)
     */
    function transfer(address _to, uint256 _value) public returns (bool) {
        // �ڽſ��� �۱��ϴ� ���� �����Ѵ�
        require(_to != address(this));
        
        // �۱� ����� ��� �������� Ȯ���Ѵ�.
        if(lockedWalletInfo[msg.sender].timeLockUpEnd > now && lockedWalletInfo[msg.sender].sendLock == true) {
            RejectedPaymentFromLockedUpWallet(msg.sender, _to, _value);
            return false;
        } 
        // �Ա� �޴� ����� ��� �������� Ȯ���Ѵ�
        else if(lockedWalletInfo[_to].timeLockUpEnd > now && lockedWalletInfo[_to].receiveLock == true) {
            RejectedPaymentToLockedUpWallet(msg.sender, _to, _value);
            return false;
        } 
        // ������ ���� ���, �۱��� �����Ѵ�.
        else {
            return super.transfer(_to, _value);
        }
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
}






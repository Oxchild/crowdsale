pragma solidity ^0.4.18;

import './StandardToken.sol';
import './Ownable.sol';


/**
 * @title APIS Token
 * @dev APIS 토큰을 생성한다
 */
contract ApisToken is StandardToken, Ownable {
    // 토큰의 이름 (Advanced Property Investment System)
    string public constant name = "Advanced Property Investment System";
    
    // 토큰의 단위 (APIS)
    string public constant symbol = "APIS";
    
    // 소수점 자리수. ETH 18자리에 맞춘다
    uint8 public constant decimals = 18;
    
    // 지갑별로 송금/수금 기능의 잠긴 여부를 저장
    mapping (address => LockedInfo) public lockedWalletInfo;
    
    
    /**
     * @dev 토큰 지갑의 잠김 속성을 정의
     * 
     * @param timeLockUpEnd timeLockUpEnd 시간까지 송/수금에 대한 제한이 적용된다. 이후에는 제한이 풀린다
     * @param sendLock 출금 잠김 여부(true : 잠김, false : 풀림)
     * @param receiveLock 입금 잠김 여부 (true : 잠김, false : 풀림)
     */
    struct LockedInfo {
        uint timeLockUpEnd;
        bool sendLock;
        bool receiveLock;
    } 
    
    
    /**
     * @dev 토큰이 송금됐을 때 발생하는 이벤트
     * @param from 토큰을 보내는 지갑 주소
     * @param to 토큰을 받는 지갑 주소
     * @param value 전달되는 토큰의 양 (Satoshi)
     */
    event Transfer (address indexed from, address indexed to, uint256 value);
    
    /**
     * @dev 토큰 지갑의 송금/입금 기능이 제한되었을 때 발생하는 이벤트
     * @param target 제한 대상 지갑 주소
     * @param timeLockUpEnd 제한이 종료되는 시간(UnixTimestamp)
     * @param sendLock 지갑에서의 송금을 제한하는지 여부(true : 제한, false : 해제)
     * @param receiveLock 지갑으로의 입금을 제한하는지 여부 (true : 제한, false : 해제)
     */
    event Locked (address indexed target, uint timeLockUpEnd, bool sendLock, bool receiveLock);
    
    /**
     * @dev 지갑에 대한 송금/입금 제한을 해제했을 때 발생하는 이벤트
     * @param target 해제 대상 지갑 주소
     */
    event Unlocked (address indexed target);
    
    /**
     * @dev 송금 받는 지갑의 입금이 제한되어있어서 송금이 거절되었을 때 발생하는 이벤트
     * @param from 토큰을 보내는 지갑 주소
     * @param to (입금이 제한된) 토큰을 받는 지갑 주소
     * @param value 전송하려고 한 토큰의 양(Satoshi)
     */
    event RejectedPaymentToLockedUpWallet (address indexed from, address indexed to, uint256 value);
    
    /**
     * @dev 송금하는 지갑의 출금이 제한되어있어서 송금이 거절되었을 때 발생하는 이벤트
     * @param from (출금이 제한된) 토큰을 보내는 지갑 주소
     * @param to 토큰을 받는 지갑 주소
     * @param value 전송하려고 한 토큰의 양(Satoshi)
     */
    event RejectedPaymentFromLockedUpWallet (address indexed from, address indexed to, uint256 value);
    
    /**
     * @dev 토큰을 소각한다. 
     * @param burner 토큰을 소각하는 지갑 주소
     * @param value 소각하는 토큰의 양(Satoshi)
     */
    event Burn (address indexed burner, uint256 value);
    
    /**
     * @dev 컨트랙트가 생성될 때 실행. 컨트렉트 소유자 지갑에 모든 토큰을 할당한다.
     * 발행량이나 이름은 소스코드에서 확인할 수 있도록 변경하였음
     */
    function ApisToken() public {
        // 총 APIS 발행량 (95억 2천만)
        uint256 supplyApis = 9520000000;
        
        // wei 단위로 토큰 총량을 생성한다.
        totalSupply = supplyApis * 10 ** uint256(decimals);
        
        balances[msg.sender] = totalSupply;
        
        Transfer(0x0, msg.sender, totalSupply);
    }
    
    
    /**
     * @dev 지갑을 지정된 시간까지 제한시키거나 해제시킨다. 제한 시간이 경과하면 모든 제한이 해제된다.
     * @param _targetWallet 제한을 적용할 지갑 주소
     * @param _timeLockEnd 제한이 종료되는 시간(UnixTimestamp)
     * @param _sendLock (true : 지갑에서 토큰을 출금하는 기능을 제한한다.) (false : 제한을 해제한다)
     * @param _receiveLock (true : 지갑으로 토큰을 입금받는 기능을 제한한다.) (false : 제한을 해제한다)
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
     * @dev 지갑의 입급/출금을 지정된 시간까지 제한시킨다. 제한 시간이 경과하면 모든 제한이 해제된다.
     * @param _targetWallet 제한을 적용할 지갑 주소
     * @param _timeLockUpEnd 제한이 종료되는 시간(UnixTimestamp)
     */
    function walletLockBoth(address _targetWallet, uint _timeLockUpEnd) onlyOwner public {
        walletLock(_targetWallet, _timeLockUpEnd, true, true);
    }
    
    /**
     * @dev 지갑의 입급/출금을 영원히(33658-9-27 01:46:39+00) 제한시킨다.
     * @param _targetWallet 제한을 적용할 지갑 주소
     */
    function walletLockBothForever(address _targetWallet) onlyOwner public {
        walletLock(_targetWallet, 999999999999, true, true);
    }
    
    
    /**
     * @dev 지갑에 설정된 입출금 제한을 해제한다
     * @param _targetWallet 제한을 해제하고자 하는 지갑 주소
     */
    function walletUnlock(address _targetWallet) onlyOwner public {
        walletLock(_targetWallet, 0, false, false);
    }
    
    /**
     * @dev 지갑의 송금 기능이 제한되어있는지 확인한다.
     * @param _addr 송금 제한 여부를 확인하려는 지갑의 주소
     * @return isSendLocked (true : 제한되어 있음, 토큰을 보낼 수 없음) (false : 제한 없음, 토큰을 보낼 수 있음)
     * @return until 잠겨있는 시간, UnixTimestamp
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
     * @dev 지갑의 입금 기능이 제한되어있는지 확인한다.
     * @param _addr 입금 제한 여부를 확인하려는 지갑의 주소
     * @return (true : 제한되어 있음, 토큰을 받을 수 없음) (false : 제한 없음, 토큰을 받을 수 있음)
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
     * @dev 요청자의 지갑에 송금 기능이 제한되어있는지 확인한다.
     * @return (true : 제한되어 있음, 토큰을 보낼 수 없음) (false : 제한 없음, 토큰을 보낼 수 있음)
     */
    function isMyWalletLocked_Send() public constant returns (bool isSendLocked, uint until) {
        return isWalletLocked_Send(msg.sender);
    }
    
    /**
     * @dev 요청자의 지갑에 입금 기능이 제한되어있는지 확인한다.
     * @return (true : 제한되어 있음, 토큰을 보낼 수 없음) (false : 제한 없음, 토큰을 보낼 수 있음)
     */
    function isMyWalletLocked_Receive() public constant returns (bool isReceiveLocked, uint until) {
        return isWalletLocked_Receive(msg.sender);
    }
    
    
    
    /**
     * @dev _to 지갑으로 _apisWei 만큼의 토큰을 송금한다.
     * @param _to 토큰을 받는 지갑 주소
     * @param _apisWei 전송되는 토큰의 양
     */
    function transfer(address _to, uint256 _apisWei) public returns (bool) {
        // 자신에게 송금하는 것을 방지한다
        require(_to != address(this));
        
        // 송금 기능이 잠긴 지갑인지 확인한다.
        if(lockedWalletInfo[msg.sender].timeLockUpEnd > now && lockedWalletInfo[msg.sender].sendLock == true) {
            RejectedPaymentFromLockedUpWallet(msg.sender, _to, _apisWei);
            return false;
        } 
        // 입금 받는 기능이 잠긴 지갑인지 확인한다
        else if(lockedWalletInfo[_to].timeLockUpEnd > now && lockedWalletInfo[_to].receiveLock == true) {
            RejectedPaymentToLockedUpWallet(msg.sender, _to, _apisWei);
            return false;
        } 
        // 제한이 없는 경우, 송금을 진행한다.
        else {
            return super.transfer(_to, _apisWei);
        }
    }
    
    /**
     * @dev _to 지갑으로 _apisWei 만큼의 APIS를 송금하고 _timeLockUpEnd 시간만큼 지갑을 잠근다
     * @param _to 토큰을 받는 지갑 주소
     * @param _apisWei 전송되는 토큰의 양(wei)
     * @param _timeLockUpEnd 잠금이 해제되는 시간
     */
    function transferAndLockUntil(address _to, uint256 _apisWei, uint _timeLockUpEnd) onlyOwner public {
        require(transfer(_to, _apisWei));
        
        walletLockBoth(_to, _timeLockUpEnd);
    }
    
    /**
     * @dev _to 지갑으로 _apisWei 만큼의 APIS를 송금하고영원히 지갑을 잠근다
     * @param _to 토큰을 받는 지갑 주소
     * @param _apisWei 전송되는 토큰의 양(wei)
     */
    function transferAndLockForever(address _to, uint256 _apisWei) onlyOwner public {
        require(transfer(_to, _apisWei));
        
        walletLockBothForever(_to);
    }
    
    
    /**
     * @dev 함수를 호출하는 지갑의 토큰을 소각한다.
     * 
     * zeppelin-solidity/contracts/token/BurnableToken.sol 참조
     * @param _value 소각하려는 토큰의 양(Satoshi)
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
     * @dev Eth은 받을 수 없도록 한다.
     */
    function () public payable {
        revert();
    }
}






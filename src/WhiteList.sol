pragma solidity ^0.4.18;

import './Ownable.sol';


/**
 * @title WhiteList
 * @dev ICO 참여가 가능한 화이트 리스트를 관리한다
 */
contract WhiteList is Ownable {
    
    mapping (address => uint8) internal list;
    
    /**
     * @dev 화이트리스트에 변동이 발생했을 때 이벤트
     * @param backer 화이트리스트에 등재하려는 지갑 주소
     * @param allowed (true : 화이트리스트에 추가) (false : 제거)
     */
    event WhiteBacker(address indexed backer, bool allowed);
    
    
    /**
     * @dev 화이트리스트에 등록하거나 해제한다.
     * @param _target 화이트리스트에 등재하려는 지갑 주소
     * @param _allowed (true : 화이트리스트에 추가) (false : 제거) 
     */
    function setWhiteBacker(address _target, bool _allowed) onlyOwner public {
        require(_target != 0x0);
        
        if(_allowed == true) {
            list[_target] = 1;
        } else {
            list[_target] = 0;
        }
        
        WhiteBacker(_target, _allowed);
    }
    
    /**
     * @dev 화이트리스트에 여러 지갑 주소를 동시에 등재하거나 제거한다.
     * 
     * 가스 소모를 줄여보기 위함
     * @param _backers 대상이 되는 지갑들의 리스트
     * @param _allows 대상이 되는 지갑들의 추가 여부 리스트 (true : 추가) (false : 제거)
     */
    function setWhiteBackersByList(address[] _backers, bool[] _allows) onlyOwner public {
        require(_backers.length > 0);
        require(_backers.length == _allows.length);
        
        for(uint backerIndex = 0; backerIndex < _backers.length; backerIndex++) {
            setWhiteBacker(_backers[backerIndex], _allows[backerIndex]);
        }
    }
    
    /**
     * @dev 화이트리스트에 여러 지갑 주소를 등재한다.
     * 
     * 모든 주소들은 화이트리스트에 추가된다.
     * @param _backers 대상이 되는 지갑들의 리스트
     */
    function addWhiteBackersByList(address[] _backers) onlyOwner public {
        for(uint backerIndex = 0; backerIndex < _backers.length; backerIndex++) {
            setWhiteBacker(_backers[backerIndex], true);
        }
    }
    
    
    /**
     * @dev 해당 지갑 주소가 화이트 리스트에 등록되어있는지 확인한다
     * @param _addr 등재 여부를 확인하려는 지갑의 주소
     * @return (true : 등록되어있음) (false : 등록되어있지 않음)
     */
    function isInWhiteList(address _addr) public constant returns (bool) {
        require(_addr != 0x0);
        return list[_addr] > 0;
    }
    
    /**
     * @dev 요청하는 지갑이 화이트리스트에 등록되어있는지 확인한다.
     * @return (true : 등록되어있음) (false : 등록되어있지 않음)
     */
    function imInWhiteList() public constant returns (bool) {
        return list[msg.sender] > 0;
    }
}
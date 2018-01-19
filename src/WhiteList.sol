pragma solidity ^0.4.18;

import './Ownable.sol';


/**
 * @title WhiteList
 * @dev ICO ������ ������ ȭ��Ʈ ����Ʈ�� �����Ѵ�
 */
contract WhiteList is Ownable {
    
    mapping (address => uint8) internal list;
    
    /**
     * @dev ȭ��Ʈ����Ʈ�� ������ �߻����� �� �̺�Ʈ
     * @param backer ȭ��Ʈ����Ʈ�� �����Ϸ��� ���� �ּ�
     * @param allowed (true : ȭ��Ʈ����Ʈ�� �߰�) (false : ����)
     */
    event WhiteBacker(address indexed backer, bool allowed);
    
    
    /**
     * @dev ȭ��Ʈ����Ʈ�� ����ϰų� �����Ѵ�.
     * @param _target ȭ��Ʈ����Ʈ�� �����Ϸ��� ���� �ּ�
     * @param _allowed (true : ȭ��Ʈ����Ʈ�� �߰�) (false : ����) 
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
     * @dev ȭ��Ʈ����Ʈ�� ���� ���� �ּҸ� ���ÿ� �����ϰų� �����Ѵ�.
     * 
     * ���� �Ҹ� �ٿ����� ����
     * @param _backers ����� �Ǵ� �������� ����Ʈ
     * @param _allows ����� �Ǵ� �������� �߰� ���� ����Ʈ (true : �߰�) (false : ����)
     */
    function setWhiteBackersByList(address[] _backers, bool[] _allows) onlyOwner public {
        require(_backers.length > 0);
        require(_backers.length == _allows.length);
        
        for(uint backerIndex = 0; backerIndex < _backers.length; backerIndex++) {
            setWhiteBacker(_backers[backerIndex], _allows[backerIndex]);
        }
    }
    
    /**
     * @dev ȭ��Ʈ����Ʈ�� ���� ���� �ּҸ� �����Ѵ�.
     * 
     * ��� �ּҵ��� ȭ��Ʈ����Ʈ�� �߰��ȴ�.
     * @param _backers ����� �Ǵ� �������� ����Ʈ
     */
    function addWhiteBackersByList(address[] _backers) onlyOwner public {
        for(uint backerIndex = 0; backerIndex < _backers.length; backerIndex++) {
            setWhiteBacker(_backers[backerIndex], true);
        }
    }
    
    
    /**
     * @dev �ش� ���� �ּҰ� ȭ��Ʈ ����Ʈ�� ��ϵǾ��ִ��� Ȯ���Ѵ�
     * @param _addr ���� ���θ� Ȯ���Ϸ��� ������ �ּ�
     * @return (true : ��ϵǾ�����) (false : ��ϵǾ����� ����)
     */
    function isInWhiteList(address _addr) public constant returns (bool) {
        require(_addr != 0x0);
        return list[_addr] > 0;
    }
    
    /**
     * @dev ��û�ϴ� ������ ȭ��Ʈ����Ʈ�� ��ϵǾ��ִ��� Ȯ���Ѵ�.
     * @return (true : ��ϵǾ�����) (false : ��ϵǾ����� ����)
     */
    function imInWhiteList() public constant returns (bool) {
        return list[msg.sender] > 0;
    }
}
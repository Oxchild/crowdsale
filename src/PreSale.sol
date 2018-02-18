pragma solidity ^0.4.18;

import './Ownable.sol';
import './ApisToken.sol';
import './WhiteList.sol';


/**
 * @title APIS Crowd Pre-Sale
 * @dev ��ū�� ���������� �����ϱ� ���� ��Ʈ��Ʈ
 */
contract PreSale is Ownable {
    
    // �Ҽ��� �ڸ���. QTUM 8�ڸ��� ����� (ETH�� ��� 18�ڸ�)
    uint8 public constant decimals = 8;
    
    
    // ũ���� ������ �Ǹ� ��ǥ��(Satoshi)
    uint256 public fundingGoal;
    
    // 1 Qtum���� �� �� �ִ� APIS�� ����
    uint256 public priceOfApisPerQtum;
    
    // �߱޵� Apis ���� (�߱� ���� ����)
    uint256 public soldApis;
    
    // �ǸŰ� ���۵� �ð�
    uint public startTime;
    uint public endTime;
    
    // ĸ ���� (�ִ� �Աݾװ� �ּ� �Աݾ�)
    uint public maximumAmount;
    uint public minimumAmount;
    
    // �������Ͽ� ������ �� �ִ� ���� �ݾ�(�����)..���� ���ݿ� ���� �켱���� ������ ���� ����
    uint public gasPrice;
    
    
    // APIS ��ū ��Ʈ��Ʈ
    ApisToken internal tokenReward;
    
    // ȭ��Ʈ����Ʈ ��Ʈ��Ʈ
    WhiteList internal whiteList;
    
    mapping (address => Property) public fundersProperty;
    
    /**
     * @dev APIS ��ū �������� �ڻ� ��Ȳ�� �����ϱ� ���� ����ü
     */
    struct Property {
        uint256 paidQtum;    	// �Ա� ���� Qtum
        uint256 withdrawedApis; // ����� ��ū
    }
    
    
    /**
     * @dev ũ���� ���� ��Ʈ��Ʈ���� Qtum�� ����Ǿ��� �� �߻��ϴ� �̺�Ʈ
     * @param addr Qtum�� �޴� ������ �ּ�
     * @param amount �۱ݵǴ� Qtum�� ��(Satoshi)
     */
    event WithdrawalQtum(address addr, uint256 amount);
    
    /**
     * @dev �����ڿ��� ��ū�� �߱޵Ǿ��� �� �߻��ϴ� �̺�Ʈ
     * @param funder ��ū�� �޴� ������ �ּ�
     * @param amount �߱� �޴� ��ū�� �� (Satoshi)
     */
    event WithdrawalApis(address funder, uint256 amount);
    
    
    // ���� �߿��� �����ϵ���
    modifier onSale() {
        require(now >= startTime);
        require(now < endTime);
        _;
    }
    
    
    /**
     * @dev ũ���� ���� ��Ʈ��Ʈ�� �����Ѵ�.
     * @param _fundingGoalApis �Ǹ��ϴ� ��ū�� �� (APIS ����)
     * @param _priceOfApisPerQtum 1 Qtum���� ������ �� �ִ� APIS�� ����
     * @param _endTime ũ���� ������ �����ϴ� �ð�
     * @param _addressOfApisTokenUsedAsReward APIS ��ū�� ��Ʈ��Ʈ �ּ�
     * @param _addressOfWhiteList WhiteList ��Ʈ��Ʈ �ּ�
     */
    function PreSale (
        uint256 _fundingGoalApis,
        uint256 _priceOfApisPerQtum,
        uint _startTime,
        uint _endTime,
        uint256 _minimumAmount,
        uint256 _maximumAmount,
        address _addressOfApisTokenUsedAsReward,
        address _addressOfWhiteList
    ) public {
        require (_fundingGoalApis > 0);
        require (_priceOfApisPerQtum > 0);
        require (_startTime > now);
        require (_endTime > now);
        require (_endTime > _startTime);
        require (_maximumAmount > 0);
        require (_minimumAmount > 0);
        require (_addressOfApisTokenUsedAsReward != 0x0);
        require (_addressOfWhiteList != 0x0);
        
        fundingGoal = _fundingGoalApis * 10 ** uint256(decimals);
        priceOfApisPerQtum = _priceOfApisPerQtum;
        startTime = _startTime;
        endTime = _endTime;
        maximumAmount = _maximumAmount * 10 ** uint256(decimals);
        minimumAmount = _minimumAmount * 10 ** uint256(decimals);
        gasPrice = 70;
        
        // �����÷ο� ����
        require (fundingGoal > _fundingGoalApis);
        
        // ��ū ����Ʈ��Ʈ��Ʈ�� �ҷ��´�
        tokenReward = ApisToken(_addressOfApisTokenUsedAsReward);
        
        // ȭ��Ʈ ����Ʈ�� �����´�
        whiteList = WhiteList(_addressOfWhiteList);
    }
    
    
    
    /**
     * @dev ������ APIS �ܰ� Ȯ���Ѵ�
     * @param _addr �ܰ� Ȯ���Ϸ��� ������ �ּ�
     * @return balance ������ ���� APIS �ܰ� (Satoshi)
     */
    function balanceOfApis(address _addr) public view returns (uint256 balance) {
        return tokenReward.balanceOf(_addr);
    }
    
    
    
    /**
     * @dev ũ���� ���� ��Ʈ��Ʈ�� �ٷ� Qtum�� �۱��ϴ� ���, buyToken���� �����Ѵ�
     */
    function () onSale public payable {
        buyToken(msg.sender);
    }
    
    /**
     * @dev ��ū�� �����ϱ� ���� Qtum�� �Աݹ޴´�.
     * @param _beneficiary ��ū�� �ް� �� ������ �ּ�
     */
    function buyToken(address _beneficiary) onSale public payable {
        require(_beneficiary != 0x0);
        
        // ������ �Ա��ص� �Ա� �ּ� ������ �Ѿ�� �Ѵ�.
        require(msg.value + fundersProperty[_beneficiary].paidQtum >= minimumAmount);
        
        // ������ �Ա��ϴ��� �Ա� ������ �ʰ��ϸ� �ȵȴ�.
        require(msg.value + fundersProperty[_beneficiary].paidQtum <= maximumAmount);
        
        // ȭ��Ʈ ����Ʈ�� ��ϵǾ����� ������ �Աݹ��� �� �ֵ��� �Ѵ�.
        require(whiteList.isInWhiteList(_beneficiary) == true);
        
        // Gas ���ݿ� ���� �켱���� ������ ���� ���� ���� ���� �����Ѵ�.
        require(tx.gasprice == 70);
        
        uint256 amountQtum = msg.value;
        uint256 withdrawedApis = amountQtum * priceOfApisPerQtum;
        
        
        // �����÷ο� ����
        require(withdrawedApis > amountQtum);
        
        // ��ǥ �ݾ� �ʰ� ����
        require(soldApis + withdrawedApis <= fundingGoal);
        
        // ������ �������� ��ū�� �����Ѵ�
        tokenReward.transfer(_beneficiary, withdrawedApis);
        
        fundersProperty[_beneficiary].paidQtum += amountQtum;
        fundersProperty[_beneficiary].withdrawedApis += withdrawedApis;
        
        soldApis += withdrawedApis;
        
        WithdrawalApis(_beneficiary, fundersProperty[_beneficiary].withdrawedApis);
    }
    
    
    
    // �ݵ��� ����ǰ�, ������ Qtum�� �����ڿ��� �����Ѵ�
    // saleState ���� 2(����)�� �����Ǿ�߸� �Ѵ�
    function withdrawalOwner() onlyOwner public {
        require(now > endTime);
        
        uint256 amount = this.balance;
        if(amount > 0) {
            msg.sender.transfer(amount);
            WithdrawalQtum(msg.sender, amount);
        }
        
        // ��Ʈ��Ʈ�� ���� ��ū�� ��ȯ�Ѵ� 
        uint256 token = tokenReward.balanceOf(this);
        tokenReward.transfer(msg.sender, token);
        
        WithdrawalApis(msg.sender, token);
    }
    
    /**
     * @dev ũ���弼�� ��Ʈ��Ʈ�� ���� Qtum�� Ȯ���Ѵ�.
     * @return balance Qtum �ܰ� (Satoshi)
     */
    function getContractBalance() onlyOwner public constant returns (uint256 balance) {
        return this.balance;
    }
}
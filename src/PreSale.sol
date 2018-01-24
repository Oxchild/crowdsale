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
    
    /**
     * @dev ���� ũ���� ������ ���¸� �����Ѵ�.
     * 
     * (0 : �Ǹ� ���� ��) (1 : �Ǹ� ���� ��) (2 : �Ǹ� ���� ��)
     */
    uint8 internal saleState = 0;
    
    // ũ���� ������ �Ǹ� ��ǥ��(Satoshi)
    uint256 public fundingGoal;
    
    // 1 Qtum���� �� �� �ִ� APIS�� ����
    uint256 public priceOfApisPerQtum;
    
    // �߱޵� Apis ���� (�߱� ���� ����)
    uint256 public soldApis;
    
    // �ǸŰ� ���۵� �ð�
    uint public startTime;
    uint public endTime;
    
    // Qtum �Ա� �� ��ū ��������� �����Ⱓ
    uint public suspensionPeriod;
    
    // APIS ��ū ��Ʈ��Ʈ
    ApisToken internal tokenReward;
    
    // ȭ��Ʈ����Ʈ ��Ʈ��Ʈ
    WhiteList internal whiteList;
    
    mapping (address => Property) public fundersProperty;
    
    /**
     * @dev APIS ��ū �������� �ڻ� ��Ȳ�� �����ϱ� ���� ����ü
     */
    struct Property {
        uint256 reservedQtum;   // �Ա������� ���� APIS�� ��ȯ���� ���� Qtum (ȯ�� ����)
        uint256 paidQtum;    	// APIS�� ��ȯ�� Qtum (ȯ�� �Ұ�)
        uint256 reservedApis;   // ���� ������ ��ū
        uint256 withdrawedApis; // �̹� ���� ��ū
        bool withdrawed;        // ��ū �߱� ���� (true : �߱� �޾���) (false : ���� �߱� ���� �ʾ���)
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
     * @param result ��ū �߱� ���� ���� (true : ����) (false : ����)
     */
    event WithdrawalApis(address funder, uint256 amount, bool result);
    
    
    // ���� �߿��� �����ϵ���
    modifier onSale() {
        require(saleState == 1);
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
        uint _endTime,
        address _addressOfApisTokenUsedAsReward,
        address _addressOfWhiteList
    ) public {
        require (_fundingGoalApis > 0);
        require (_priceOfApisPerQtum > 0);
        require (_endTime > now);
        require (_addressOfApisTokenUsedAsReward != 0x0);
        require (_addressOfWhiteList != 0x0);
        
        fundingGoal = _fundingGoalApis * 10 ** uint256(decimals);
        priceOfApisPerQtum = _priceOfApisPerQtum;
        endTime = _endTime;
        suspensionPeriod = 7 days;
        
        // �����÷ο� ����
        require (fundingGoal > _fundingGoalApis);
        
        // ��ū ����Ʈ��Ʈ��Ʈ�� �ҷ��´�
        tokenReward = ApisToken(_addressOfApisTokenUsedAsReward);
        
        // ȭ��Ʈ ����Ʈ�� �����´�
        whiteList = WhiteList(_addressOfWhiteList);
    }
    
    /**
     * @dev ũ���� ������ ���� ���� ���¸� �����Ѵ�.
     * @param _state ���� �� (0 : ���� ��) (1 : ���� ��) (2 : ���� ��)
     */
    function changeSellingState (uint8 _state) onlyOwner public {
        require (_state < 3);
        require(saleState < _state);    // ���� �ܰ�θ� ������ �� �ֵ��� �Ѵ�
        
        saleState = _state;
        
        if(saleState == 1) {
            startTime = now;
        }
    }
    
    
    
    /**
     * @dev ������ APIS �ܰ� Ȯ���Ѵ�
     * @param _addr �ܰ� Ȯ���Ϸ��� ������ �ּ�
     * @return balance ������ ���� APIS �ܰ� (Satoshi)
     */
    function balanceOf(address _addr) public view returns (uint256 balance) {
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
        require(msg.value >= 400 * 10**uint256(decimals));
        require(msg.value <= 2000 * 10**uint256(decimals));
        // ������ �Ա��ϴ��� �Ա� ������ �ʰ��ϸ� �ȵȴ�.
        require(fundersProperty[_beneficiary].reservedQtum + fundersProperty[_beneficiary].paidQtum <= 2000 *10**uint256(decimals));
        
        // ȭ��Ʈ ����Ʈ�� ��ϵǾ����� ������ �Աݹ��� �� �ֵ��� �Ѵ�.
        require(whiteList.isInWhiteList(_beneficiary) == true);
        
        
        uint256 amountQtum = msg.value;
        uint256 reservedApis = amountQtum * priceOfApisPerQtum;
        
        // �����÷ο� ����
        require(reservedApis > amountQtum);
        // ��ǥ �ݾ��� �Ѿ�� ���ϵ��� �Ѵ�
        require(soldApis + reservedApis <= fundingGoal);
        
        fundersProperty[_beneficiary].reservedQtum += amountQtum;
        fundersProperty[_beneficiary].reservedApis += reservedApis;
        fundersProperty[_beneficiary].withdrawed = false;
        
        soldApis += reservedApis;
        
        withdrawal(msg.sender);
    }
    
    
    /**
     * @dev ũ���� ������ ���� ���¸� ��ȯ�Ѵ�.
     * @return ���� ����
     */
    function sellingState() public view returns (string) {
        if(saleState == 0) {
            return "Not yet opened";
        } else if(saleState == 1) {
            return "Opened";
        } else {
            return "Closed";
        }
    }
    
    
    
    /**
     * @dev �����ڿ��� ��ū�� �����Ѵ�.
     * @param funder ��ū�� ������ ������ �ּ�
     */
    function withdrawal(address funder) internal {
        require(fundersProperty[funder].reservedApis > 0);      // ������ �ܰ� �־�� �Ѵ�
        require(fundersProperty[funder].withdrawed == false);    // ���� ������� �ʾҾ�� �Ѵ�
        
        // ������ �������� ��ū�� �����Ѵ�
        tokenReward.transfer(funder, fundersProperty[funder].reservedApis);
        
        fundersProperty[funder].withdrawedApis += fundersProperty[funder].reservedApis;
        fundersProperty[funder].paidQtum += fundersProperty[funder].reservedQtum;
        
        // �����÷ο� ����
        assert(fundersProperty[funder].withdrawedApis >= fundersProperty[funder].reservedApis);  
        
        // �������� ���� APIS �ܰ� 0���� �����ؼ�, Qtum ���Ա� �� �̹� ����� ��ū�� �ٽ� ��ݵ��� �ʰ� �Ѵ�.
        fundersProperty[funder].reservedQtum = 0;
        fundersProperty[funder].reservedApis = 0;
        fundersProperty[funder].withdrawed = true;
        
        
        
        WithdrawalApis(funder, fundersProperty[funder].reservedApis, fundersProperty[funder].withdrawed);
    }
    
    
    
    // �ݵ��� ����ǰ�, ������ Qtum�� �����ڿ��� �����Ѵ�
    // saleState ���� 2(����)�� �����Ǿ�߸� �Ѵ�
    function withdrawalOwner() onlyOwner public {
        require(saleState == 2);
        
        uint256 amount = this.balance;
        if(amount > 0) {
            msg.sender.transfer(amount);
            WithdrawalQtum(msg.sender, amount);
        }
        
        // ��Ʈ��Ʈ�� ���� ��ū�� ��ȯ�Ѵ� 
        uint256 token = tokenReward.balanceOf(this);
        tokenReward.transfer(msg.sender, token);
        WithdrawalApis(msg.sender, token, true);
    }
    
    /**
     * @dev ũ���弼�� ��Ʈ��Ʈ�� ���� Qtum�� Ȯ���Ѵ�.
     * @return balance Qtum �ܰ� (Satoshi)
     */
    function getContractBalance() onlyOwner public constant returns (uint256 balance) {
        return this.balance;
    }
}
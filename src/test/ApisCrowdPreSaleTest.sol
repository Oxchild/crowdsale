pragma solidity ^0.4.18;

import './Ownable.sol';
import './ApisToken.sol';
import './WhiteList.sol';


/**
 * @title APIS Crowd Pre-Sale
 * @dev ��ū�� ���������� �����ϱ� ���� ��Ʈ��Ʈ
 */
contract ApisCrowdPreSale is Ownable {
    
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
    
    // 24�ð� �̳��� ���� �Ա� ���Ѿ�
    uint256 public qtumDepositLimitIn24hr;
    
    // �߱޵� Apis ���� (�߱� ���� ����)
    uint256 public soldApis;
    
    // �ǸŰ� ���۵� �ð�
    uint public startTime;
    uint public endTime;
    
    // �� �ð� ���Ŀ��� ������ ��ū Ŭ������ ����������.
    uint public claimableTime;
    
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
        uint purchaseTime;      // Qtum�� �Ա��� �ð�
    }
    
    
    
    /**
     * @dev APIS�� �����ϱ� ���� Qtum�� �Ա����� �� �߻��ϴ� �̺�Ʈ
     * @param beneficiary APIS�� �����ϰ��� �ϴ� ������ �ּ�
     * @param amountQtum �Ա��� Qtum�� �� (Satoshi)
     * @param amountApis �Ա��� Qtum�� �����ϴ� APIS ��ū�� �� (Satoshi)
     */
    event ReservedApis(address beneficiary, uint256 amountQtum, uint256 amountApis);
    
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
    
    
    /**
     * @dev Qtum �Ա� ��, ���� ��ū�� �߱޹��� ���� ���¿���, ȯ�� ó���� ���� �� �߻��ϴ� �̺�Ʈ
     * @param _backer ȯ�� ó���� �����ϴ� ������ �ּ�
     * @param _amountQtum ȯ���ϴ� Qtum�� ��
     */
    event Refund(address _backer, uint256 _amountQtum);
    
    // ���� �߿��� �����ϵ���
    modifier onSale() {
        require(saleState == 1);
        require(now < endTime);
        _;
    }
    
    /**
     * @dev Qtum �Ա� �� Ŭ������ ������ ������� ���͸��Ѵ�
     */
    modifier claimable() {
        bool afterClaimableTime = now > claimableTime;
        bool afterSuspension = now > fundersProperty[msg.sender].purchaseTime + suspensionPeriod;
        
        require(afterClaimableTime == true || afterSuspension == true);
        _;
    }
    
    
    /**
     * @dev ũ���� ���� ��Ʈ��Ʈ�� �����Ѵ�.
     * @param _fundingGoalApis �Ǹ��ϴ� ��ū�� �� (APIS ����)
     * @param _priceOfApisPerQtum 1 Qtum���� ������ �� �ִ� APIS�� ����
     * @param _qtumDepositLimitIn24hrSatoshi ������ �����ϰ� 24�ð� �̳��� �Ա� ������ Qtum�� �� (Satoshi)
     * @param _endTime ũ���� ������ �����ϴ� �ð�
     * @param _addressOfApisTokenUsedAsReward APIS ��ū�� ��Ʈ��Ʈ �ּ�
     * @param _addressOfWhiteList WhiteList ��Ʈ��Ʈ �ּ�
     */
    function ApisCrowdPreSale (
        uint256 _fundingGoalApis,
        uint256 _priceOfApisPerQtum,
        uint256 _qtumDepositLimitIn24hrSatoshi,
        uint _endTime,
        address _addressOfApisTokenUsedAsReward,
        address _addressOfWhiteList
    ) public {
        require (_fundingGoalApis > 0);
        require (_priceOfApisPerQtum > 0);
        require (_qtumDepositLimitIn24hrSatoshi > 0);
        require (_endTime > now);
        require (_addressOfApisTokenUsedAsReward != 0x0);
        require (_addressOfWhiteList != 0x0);
        
        fundingGoal = _fundingGoalApis * 10 ** uint256(decimals);
        priceOfApisPerQtum = _priceOfApisPerQtum;
        endTime = _endTime;
        claimableTime = 99999999999;
        suspensionPeriod = 10 minutes;
        
        // �����÷ο� ����
        require (fundingGoal > _fundingGoalApis);
        
        // ��ū ����Ʈ��Ʈ��Ʈ�� �ҷ��´�
        tokenReward = ApisToken(_addressOfApisTokenUsedAsReward);
        
        // 24�ð� �̳��� �Ա� ������ Qtum ������ �����Ѵ�
        qtumDepositLimitIn24hr = _qtumDepositLimitIn24hrSatoshi;
        
        // ȭ��Ʈ ����Ʈ�� �����´�
        whiteList = WhiteList(_addressOfWhiteList);
    }
    
    /**
     * @dev ũ���� ������ ���� ���� ���¸� �����Ѵ�.
     * @param _state ���� �� (0 : ���� ��) (1 : ���� ��) (2 : ���� ��)
     */
    function changeSellingState (uint8 _state) onlyOwner public {
        require (_state < 3);
        //require(saleState < _state);    // �׽�Ʈ�� ���� �ּ�ó��. ���� �ܰ�θ� ������ �� �ֵ��� �Ѵ�
        
        saleState = _state;
        
        if(saleState == 1) {
            startTime = now;
        }
    }
    
    /**
     * @dev ��ū Ŭ������ ���������� �ð��� �����Ѵ�.
     * 
     * ���� Qtum�� �Ա��� ���, ��ȿ�� �Ա����� �����ϱ� ���� �����Ⱓ�� �����Ѵ�.
     * �ǸŰ� ����� ���Ŀ� ��� �Աݿ� ���� Ȯ���� �Ϸ�Ǹ�
     * ������ Ŭ������ ������������ ������ ������ �ʿ䰡 �ִ�.
     * @param _claimableTime ��ū Ŭ������ ���������� �ð�
     */
    function setClaimableTime(uint _claimableTime) onlyOwner public {
        claimableTime = _claimableTime;
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
        require(msg.value > 0);
        
        // ȭ��Ʈ ����Ʈ�� ��ϵǾ����� ������ �Աݹ��� �� �ֵ��� �Ѵ�.
        require(whiteList.isInWhiteList(_beneficiary) == true);
        
        uint256 amountQtum = msg.value;
        uint256 reservedApis = amountQtum * priceOfApisPerQtum;
        
        
        // �����÷ο� ����
        assert(reservedApis > amountQtum);
        // ��ǥ �ݾ��� �Ѿ�� ���ϵ��� �Ѵ�
        assert(soldApis + reservedApis <= fundingGoal);
        
        fundersProperty[_beneficiary].reservedQtum += amountQtum;
        fundersProperty[_beneficiary].reservedApis += reservedApis;
        fundersProperty[_beneficiary].purchaseTime = now;
        fundersProperty[_beneficiary].withdrawed = false;
        
        soldApis += reservedApis;
        
        
        // 24�ð� �̳����� ���� �ݾ� �̻��� �Ա��� ���´�.
        if(now - startTime < 1 days) {
            assert(fundersProperty[_beneficiary].reservedQtum <= qtumDepositLimitIn24hr);
        }
        
        // �����÷ο� ����
        assert(soldApis >= reservedApis);
        
        ReservedApis(_beneficiary, amountQtum, reservedApis);
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
     * @dev �����ڿ� ���ؼ� ��ū�� �߱��Ѵ�.
     * 
     * �����ڿ� ���� �߱��� �����Ⱓ�� ������ �ʴ´�
     * @param _target ��ū �߱��� û���Ϸ��� ���� �ּ�
     */
    function claimApis(address _target) onlyOwner public {
        withdrawal(_target);
    }
    
    /**
     * @dev ������ ��ū�� ���� ������ ��û�ϵ��� �Ѵ�.
     * 
     * APIS�� �����ϱ� ���� Qtum�� �Ա��� ���, �������� ���並 ���� 7���� �����Ⱓ�� �����Ѵ�.
     * �����Ⱓ�� ������ ��ū ������ �䱸�� �� �ִ�.
     */
    function claimMyApis() claimable public {
        // �̹� ��������� �ȵȴ�
        require(fundersProperty[msg.sender].withdrawed == false);
        
        // ȭ��Ʈ����Ʈ�� ��ϵ����� ������ ��ū Ŭ������ �����ϴ�
        require(whiteList.isInWhiteList(msg.sender) == true);
        
        
        withdrawal(msg.sender);
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
    
    
    /**
     * @dev ���� ��ū�� �߱޹��� ���� ������ �������, ȯ���� ������ �� �ִ�.
     * @param _funder ȯ���� �����Ϸ��� ������ �ּ�
     */
    function refund(address _funder) onlyOwner public {
        require(fundersProperty[_funder].reservedQtum > 0);
        require(fundersProperty[_funder].reservedApis > 0);
        require(fundersProperty[_funder].withdrawed == false);
        
        uint256 amount = fundersProperty[_funder].reservedQtum;
        
        // Qtum�� ȯ���Ѵ�
        _funder.transfer(amount);
        
        fundersProperty[_funder].reservedQtum = 0;
        fundersProperty[_funder].reservedApis = 0;
        fundersProperty[_funder].withdrawed = true;
        
        Refund(_funder, amount);
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
pragma solidity ^0.4.18;

import './Ownable.sol';
import './ApisToken.sol';
import './WhiteList.sol';


/**
 * @title APIS Crowd Pre-Sale
 * @dev 토큰의 프리세일을 수행하기 위한 컨트랙트
 */
contract PreSale is Ownable {
    
    // 소수점 자리수. QTUM 8자리에 맞춘다 (ETH의 경우 18자리)
    uint8 public constant decimals = 8;
    
    
    // 크라우드 세일의 판매 목표량(Satoshi)
    uint256 public fundingGoal;
    
    // 1 Qtum으로 살 수 있는 APIS의 갯수
    uint256 public priceOfApisPerQtum;
    
    // 발급된 Apis 갯수 (발급 예정 포함)
    uint256 public soldApis;
    
    // 판매가 시작된 시간
    uint public startTime;
    uint public endTime;
    
    // 캡 제한 (최대 입금액과 최소 입금액)
    uint public maximumAmount;
    uint public minimumAmount;
    
    // 프리세일에 참여할 수 있는 가스 금액(사토시)..가스 가격에 따른 우선순위 변경을 막기 위함
    uint public gasPrice;
    
    
    // APIS 토큰 컨트렉트
    ApisToken internal tokenReward;
    
    // 화이트리스트 컨트렉트
    WhiteList internal whiteList;
    
    mapping (address => Property) public fundersProperty;
    
    /**
     * @dev APIS 토큰 구매자의 자산 현황을 정리하기 위한 구조체
     */
    struct Property {
        uint256 paidQtum;    	// 입금 받은 Qtum
        uint256 withdrawedApis; // 발행된 토큰
    }
    
    
    /**
     * @dev 크라우드 세일 컨트렉트에서 Qtum이 인출되었을 때 발생하는 이벤트
     * @param addr Qtum을 받는 지갑의 주소
     * @param amount 송금되는 Qtum의 양(Satoshi)
     */
    event WithdrawalQtum(address addr, uint256 amount);
    
    /**
     * @dev 구매자에게 토큰이 발급되었을 때 발생하는 이벤트
     * @param funder 토큰을 받는 지갑의 주소
     * @param amount 발급 받는 토큰의 양 (Satoshi)
     */
    event WithdrawalApis(address funder, uint256 amount);
    
    
    // 세일 중에만 동작하도록
    modifier onSale() {
        require(now >= startTime);
        require(now < endTime);
        _;
    }
    
    
    /**
     * @dev 크라우드 세일 컨트렉트를 생성한다.
     * @param _fundingGoalApis 판매하는 토큰의 양 (APIS 단위)
     * @param _priceOfApisPerQtum 1 Qtum으로 구매할 수 있는 APIS의 개수
     * @param _endTime 크라우드 세일을 종료하는 시간
     * @param _addressOfApisTokenUsedAsReward APIS 토큰의 컨트렉트 주소
     * @param _addressOfWhiteList WhiteList 컨트렉트 주소
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
        
        // 오버플로우 감지
        require (fundingGoal > _fundingGoalApis);
        
        // 토큰 스마트컨트렉트를 불러온다
        tokenReward = ApisToken(_addressOfApisTokenUsedAsReward);
        
        // 화이트 리스트를 가져온다
        whiteList = WhiteList(_addressOfWhiteList);
    }
    
    
    
    /**
     * @dev 지갑의 APIS 잔고를 확인한다
     * @param _addr 잔고를 확인하려는 지갑의 주소
     * @return balance 지갑에 들은 APIS 잔고 (Satoshi)
     */
    function balanceOfApis(address _addr) public view returns (uint256 balance) {
        return tokenReward.balanceOf(_addr);
    }
    
    
    
    /**
     * @dev 크라우드 세일 컨트렉트로 바로 Qtum을 송금하는 경우, buyToken으로 연결한다
     */
    function () onSale public payable {
        buyToken(msg.sender);
    }
    
    /**
     * @dev 토큰을 구입하기 위해 Qtum을 입금받는다.
     * @param _beneficiary 토큰을 받게 될 지갑의 주소
     */
    function buyToken(address _beneficiary) onSale public payable {
        require(_beneficiary != 0x0);
        
        // 여러번 입금해도 입금 최소 제한을 넘어야 한다.
        require(msg.value + fundersProperty[_beneficiary].paidQtum >= minimumAmount);
        
        // 여러번 입금하더라도 입금 제한을 초과하면 안된다.
        require(msg.value + fundersProperty[_beneficiary].paidQtum <= maximumAmount);
        
        // 화이트 리스트에 등록되어있을 때에만 입금받을 수 있도록 한다.
        require(whiteList.isInWhiteList(_beneficiary) == true);
        
        // Gas 가격에 따른 우선순위 변경을 막기 위해 가스 값을 지정한다.
        require(tx.gasprice == 70);
        
        uint256 amountQtum = msg.value;
        uint256 withdrawedApis = amountQtum * priceOfApisPerQtum;
        
        
        // 오버플로우 방지
        require(withdrawedApis > amountQtum);
        
        // 목표 금액 초과 방지
        require(soldApis + withdrawedApis <= fundingGoal);
        
        // 구매자 지갑으로 토큰을 전달한다
        tokenReward.transfer(_beneficiary, withdrawedApis);
        
        fundersProperty[_beneficiary].paidQtum += amountQtum;
        fundersProperty[_beneficiary].withdrawedApis += withdrawedApis;
        
        soldApis += withdrawedApis;
        
        WithdrawalApis(_beneficiary, fundersProperty[_beneficiary].withdrawedApis);
    }
    
    
    
    // 펀딩이 종료되고, 적립된 Qtum을 소유자에게 전송한다
    // saleState 값이 2(종료)로 설정되어야만 한다
    function withdrawalOwner() onlyOwner public {
        require(now > endTime);
        
        uint256 amount = this.balance;
        if(amount > 0) {
            msg.sender.transfer(amount);
            WithdrawalQtum(msg.sender, amount);
        }
        
        // 컨트렉트에 남은 토큰을 반환한다 
        uint256 token = tokenReward.balanceOf(this);
        tokenReward.transfer(msg.sender, token);
        
        WithdrawalApis(msg.sender, token);
    }
    
    /**
     * @dev 크라우드세일 컨트렉트에 모인 Qtum을 확인한다.
     * @return balance Qtum 잔고 (Satoshi)
     */
    function getContractBalance() onlyOwner public constant returns (uint256 balance) {
        return this.balance;
    }
}
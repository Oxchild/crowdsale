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
    
    /**
     * @dev 현재 크라우드 세일의 상태를 저장한다.
     * 
     * (0 : 판매 시작 전) (1 : 판매 진행 중) (2 : 판매 종료 후)
     */
    uint8 internal saleState = 0;
    
    // 크라우드 세일의 판매 목표량(Satoshi)
    uint256 public fundingGoal;
    
    // 1 Qtum으로 살 수 있는 APIS의 갯수
    uint256 public priceOfApisPerQtum;
    
    // 발급된 Apis 갯수 (발급 예정 포함)
    uint256 public soldApis;
    
    // 판매가 시작된 시간
    uint public startTime;
    uint public endTime;
    
    // Qtum 입금 후 토큰 발행까지의 유예기간
    uint public suspensionPeriod;
    
    // APIS 토큰 컨트렉트
    ApisToken internal tokenReward;
    
    // 화이트리스트 컨트렉트
    WhiteList internal whiteList;
    
    mapping (address => Property) public fundersProperty;
    
    /**
     * @dev APIS 토큰 구매자의 자산 현황을 정리하기 위한 구조체
     */
    struct Property {
        uint256 reservedQtum;   // 입금했지만 아직 APIS로 변환되지 않은 Qtum (환불 가능)
        uint256 paidQtum;    	// APIS로 변환된 Qtum (환불 불가)
        uint256 reservedApis;   // 받을 예정인 토큰
        uint256 withdrawedApis; // 이미 받은 토큰
        bool withdrawed;        // 토큰 발급 여부 (true : 발급 받았음) (false : 아직 발급 받지 않았음)
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
     * @param result 토큰 발급 성공 여부 (true : 성공) (false : 실패)
     */
    event WithdrawalApis(address funder, uint256 amount, bool result);
    
    
    // 세일 중에만 동작하도록
    modifier onSale() {
        require(saleState == 1);
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
        
        // 오버플로우 감지
        require (fundingGoal > _fundingGoalApis);
        
        // 토큰 스마트컨트렉트를 불러온다
        tokenReward = ApisToken(_addressOfApisTokenUsedAsReward);
        
        // 화이트 리스트를 가져온다
        whiteList = WhiteList(_addressOfWhiteList);
    }
    
    /**
     * @dev 크라우드 세일의 현재 진행 상태를 변경한다.
     * @param _state 상태 값 (0 : 시작 전) (1 : 진행 중) (2 : 종료 후)
     */
    function changeSellingState (uint8 _state) onlyOwner public {
        require (_state < 3);
        require(saleState < _state);    // 다음 단계로만 변경할 수 있도록 한다
        
        saleState = _state;
        
        if(saleState == 1) {
            startTime = now;
        }
    }
    
    
    
    /**
     * @dev 지갑의 APIS 잔고를 확인한다
     * @param _addr 잔고를 확인하려는 지갑의 주소
     * @return balance 지갑에 들은 APIS 잔고 (Satoshi)
     */
    function balanceOf(address _addr) public view returns (uint256 balance) {
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
        require(msg.value >= 400 * 10**uint256(decimals));
        require(msg.value <= 2000 * 10**uint256(decimals));
        // 여러번 입금하더라도 입금 제한을 초과하면 안된다.
        require(fundersProperty[_beneficiary].reservedQtum + fundersProperty[_beneficiary].paidQtum <= 2000 *10**uint256(decimals));
        
        // 화이트 리스트에 등록되어있을 때에만 입금받을 수 있도록 한다.
        require(whiteList.isInWhiteList(_beneficiary) == true);
        
        
        uint256 amountQtum = msg.value;
        uint256 reservedApis = amountQtum * priceOfApisPerQtum;
        
        // 오버플로우 방지
        require(reservedApis > amountQtum);
        // 목표 금액을 넘어서지 못하도록 한다
        require(soldApis + reservedApis <= fundingGoal);
        
        fundersProperty[_beneficiary].reservedQtum += amountQtum;
        fundersProperty[_beneficiary].reservedApis += reservedApis;
        fundersProperty[_beneficiary].withdrawed = false;
        
        soldApis += reservedApis;
        
        withdrawal(msg.sender);
    }
    
    
    /**
     * @dev 크라우드 세일의 현재 상태를 반환한다.
     * @return 현재 상태
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
     * @dev 구매자에게 토큰을 지급한다.
     * @param funder 토큰을 지급할 지갑의 주소
     */
    function withdrawal(address funder) internal {
        require(fundersProperty[funder].reservedApis > 0);      // 인출할 잔고가 있어야 한다
        require(fundersProperty[funder].withdrawed == false);    // 아직 출금하지 않았어야 한다
        
        // 구매자 지갑으로 토큰을 전달한다
        tokenReward.transfer(funder, fundersProperty[funder].reservedApis);
        
        fundersProperty[funder].withdrawedApis += fundersProperty[funder].reservedApis;
        fundersProperty[funder].paidQtum += fundersProperty[funder].reservedQtum;
        
        // 오버플로우 방지
        assert(fundersProperty[funder].withdrawedApis >= fundersProperty[funder].reservedApis);  
        
        // 인출하지 않은 APIS 잔고를 0으로 변경해서, Qtum 재입금 시 이미 출금한 토큰이 다시 출금되지 않게 한다.
        fundersProperty[funder].reservedQtum = 0;
        fundersProperty[funder].reservedApis = 0;
        fundersProperty[funder].withdrawed = true;
        
        
        
        WithdrawalApis(funder, fundersProperty[funder].reservedApis, fundersProperty[funder].withdrawed);
    }
    
    
    
    // 펀딩이 종료되고, 적립된 Qtum을 소유자에게 전송한다
    // saleState 값이 2(종료)로 설정되어야만 한다
    function withdrawalOwner() onlyOwner public {
        require(saleState == 2);
        
        uint256 amount = this.balance;
        if(amount > 0) {
            msg.sender.transfer(amount);
            WithdrawalQtum(msg.sender, amount);
        }
        
        // 컨트렉트에 남은 토큰을 반환한다 
        uint256 token = tokenReward.balanceOf(this);
        tokenReward.transfer(msg.sender, token);
        WithdrawalApis(msg.sender, token, true);
    }
    
    /**
     * @dev 크라우드세일 컨트렉트에 모인 Qtum을 확인한다.
     * @return balance Qtum 잔고 (Satoshi)
     */
    function getContractBalance() onlyOwner public constant returns (uint256 balance) {
        return this.balance;
    }
}
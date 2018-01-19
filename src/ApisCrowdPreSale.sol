pragma solidity ^0.4.18;

import './Ownable.sol';
import './ApisToken.sol';
import './WhiteList.sol';


/**
 * @title APIS Crowd Pre-Sale
 * @dev 토큰의 프리세일을 수행하기 위한 컨트랙트
 */
contract ApisCrowdPreSale is Ownable {
    
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
    
    // 24시간 이내의 퀀텀 입금 제한액
    uint256 public qtumDepositLimitIn24hr;
    
    // 발급된 Apis 갯수 (발급 예정 포함)
    uint256 public soldApis;
    
    // 판매가 시작된 시간
    uint public startTime;
    uint public endTime;
    
    // 이 시간 이후에는 누구나 토큰 클레임이 가능해진다.
    uint public claimableTime;
    
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
        uint purchaseTime;      // Qtum을 입금한 시간
    }
    
    
    
    /**
     * @dev APIS를 구입하기 위한 Qtum을 입금했을 때 발생하는 이벤트
     * @param beneficiary APIS를 구매하고자 하는 지갑의 주소
     * @param amountQtum 입금한 Qtum의 양 (Satoshi)
     * @param amountApis 입금한 Qtum에 상응하는 APIS 토큰의 양 (Satoshi)
     */
    event ReservedApis(address beneficiary, uint256 amountQtum, uint256 amountApis);
    
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
    
    
    /**
     * @dev Qtum 입금 후, 아직 토큰을 발급받지 않은 상태에서, 환불 처리를 했을 때 발생하는 이벤트
     * @param _backer 환불 처리를 진행하는 지갑의 주소
     * @param _amountQtum 환불하는 Qtum의 양
     */
    event Refund(address _backer, uint256 _amountQtum);
    
    // 세일 중에만 동작하도록
    modifier onSale() {
        require(saleState == 1);
        require(now < endTime);
        _;
    }
    
    /**
     * @dev Qtum 입금 후 클레임이 가능할 경우인지 필터링한다
     */
    modifier claimable() {
        bool afterClaimableTime = now > claimableTime;
        bool afterSuspension = now > fundersProperty[msg.sender].purchaseTime + suspensionPeriod;
        
        require(afterClaimableTime == true || afterSuspension == true);
        _;
    }
    
    
    /**
     * @dev 크라우드 세일 컨트렉트를 생성한다.
     * @param _fundingGoalApis 판매하는 토큰의 양 (APIS 단위)
     * @param _priceOfApisPerQtum 1 Qtum으로 구매할 수 있는 APIS의 개수
     * @param _qtumDepositLimitIn24hrSatoshi 세일이 시작하고 24시간 이내에 입금 가능한 Qtum의 양 (Satoshi)
     * @param _endTime 크라우드 세일을 종료하는 시간
     * @param _addressOfApisTokenUsedAsReward APIS 토큰의 컨트렉트 주소
     * @param _addressOfWhiteList WhiteList 컨트렉트 주소
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
        suspensionPeriod = 7 days;
        
        // 오버플로우 감지
        require (fundingGoal > _fundingGoalApis);
        
        // 토큰 스마트컨트렉트를 불러온다
        tokenReward = ApisToken(_addressOfApisTokenUsedAsReward);
        
        // 24시간 이내에 입금 가능한 Qtum 수량을 저장한다
        qtumDepositLimitIn24hr = _qtumDepositLimitIn24hrSatoshi;
        
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
     * @dev 토큰 클레임이 가능해지는 시간을 적용한다.
     * 
     * 원래 Qtum을 입금할 경우, 유효한 입금인지 검증하기 위한 유예기간이 존재한다.
     * 판매가 종료된 이후에 모든 입금에 대한 확인이 완료되면
     * 누구나 클레임이 가능해지도록 조건을 변경할 필요가 있다.
     * @param _claimableTime 토큰 클레임이 가능해지는 시간
     */
    function setClaimableTime(uint _claimableTime) onlyOwner public {
        claimableTime = _claimableTime;
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
        require(msg.value > 0);
        
        // 화이트 리스트에 등록되어있을 때에만 입금받을 수 있도록 한다.
        require(whiteList.isInWhiteList(_beneficiary) == true);
        
        uint256 amountQtum = msg.value;
        uint256 reservedApis = amountQtum * priceOfApisPerQtum;
        
        
        // 오버플로우 방지
        assert(reservedApis > amountQtum);
        // 목표 금액을 넘어서지 못하도록 한다
        assert(soldApis + reservedApis <= fundingGoal);
        
        fundersProperty[_beneficiary].reservedQtum += amountQtum;
        fundersProperty[_beneficiary].reservedApis += reservedApis;
        fundersProperty[_beneficiary].purchaseTime = now;
        fundersProperty[_beneficiary].withdrawed = false;
        
        soldApis += reservedApis;
        
        
        // 24시간 이내에는 일정 금액 이상의 입금을 막는다.
        if(now - startTime < 1 days) {
            assert(fundersProperty[_beneficiary].reservedQtum <= qtumDepositLimitIn24hr);
        }
        
        // 오버플로우 방지
        assert(soldApis >= reservedApis);
        
        ReservedApis(_beneficiary, amountQtum, reservedApis);
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
     * @dev 관리자에 의해서 토큰을 발급한다.
     * 
     * 관리자에 의한 발급은 유예기간을 따지지 않는다
     * @param _target 토큰 발급을 청구하려는 지갑 주소
     */
    function claimApis(address _target) onlyOwner public {
        withdrawal(_target);
    }
    
    /**
     * @dev 예약한 토큰의 실제 지급을 요청하도록 한다.
     * 
     * APIS를 구매하기 위해 Qtum을 입금할 경우, 관리자의 검토를 위한 7일의 유예기간이 존재한다.
     * 유예기간이 지나면 토큰 지급을 요구할 수 있다.
     */
    function claimMyApis() claimable public {
        // 이미 출금했으면 안된다
        require(fundersProperty[msg.sender].withdrawed == false);
        
        // 화이트리스트에 등록되있을 때에만 토큰 클래임이 가능하다
        require(whiteList.isInWhiteList(msg.sender) == true);
        
        
        withdrawal(msg.sender);
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
    
    
    /**
     * @dev 아직 토큰을 발급받지 않은 지갑을 대상으로, 환불을 진행할 수 있다.
     * @param _funder 환불을 진행하려는 지갑의 주소
     */
    function refund(address _funder) onlyOwner public {
        require(fundersProperty[_funder].reservedQtum > 0);
        require(fundersProperty[_funder].reservedApis > 0);
        require(fundersProperty[_funder].withdrawed == false);
        
        uint256 amount = fundersProperty[_funder].reservedQtum;
        
        // Qtum을 환불한다
        _funder.transfer(amount);
        
        fundersProperty[_funder].reservedQtum = 0;
        fundersProperty[_funder].reservedApis = 0;
        fundersProperty[_funder].withdrawed = true;
        
        Refund(_funder, amount);
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
pragma solidity ^0.4.18;

import './ApisToken.sol';
import './WhiteList.sol';


/**
 * @title APIS Crowd Pre-Sale
 * @dev 토큰의 프리세일을 수행하기 위한 컨트랙트
 */
contract ApisCrowdSale is Ownable {
    
    // 소수점 자리수. Eth 18자리에 맞춘다
    uint8 public constant decimals = 18;
    
    
    // 크라우드 세일의 판매 목표량(APIS)
    uint256 public fundingGoal;
    
    // 현재 진행하는 판매 목표량 
    // QTUM과 공동으로 판매가 진행되기 때문에,  QTUM 쪽 컨트렉트와 합산한 판매량이 총 판매목표를 넘지 않도록 하기 위함
    uint256 public fundingGoalCurrent;
    
    // 1 ETH으로 살 수 있는 APIS의 갯수
    uint256 public priceOfApisPerFund;
    

    // 발급된 Apis 갯수 (예약 + 발행)
    uint256 public totalSoldApis;
    
    // 발행 대기중인 APIS 갯수
    uint256 public totalReservedApis;
    
    // 발행되서 출금된 APIS 갯수
    uint256 public totalWithdrawedApis;
    
    
    // 입금된 투자금의 총액 (예약 + 발행)
    uint256 public totalReceivedFunds;
    
    // 구매 확정 전 투자금의 총액
    uint256 public totalReservedFunds;
    
    // 구매 확정된 투자금의 총액
    uint256 public totalPaidFunds;

    
    // 판매가 시작되는 시간
    uint public startTime;
    
    // 판매가 종료되는 시간
    uint public endTime;

    // 판매가 조기에 종료될 경우를 대비하기 위함
    bool closed = false;
    
    
    // APIS 토큰 컨트렉트
    ApisToken internal tokenReward;
    
    // 화이트리스트 컨트렉트
    WhiteList internal whiteList;

    
    
    mapping (address => Property) public fundersProperty;
    
    /**
     * @dev APIS 토큰 구매자의 자산 현황을 정리하기 위한 구조체
     */
    struct Property {
        uint256 reservedFunds;   // 입금했지만 아직 APIS로 변환되지 않은 Eth (환불 가능)
        uint256 paidFunds;    	// APIS로 변환된 Eth (환불 불가)
        uint256 reservedApis;   // 받을 예정인 토큰
        uint256 withdrawedApis; // 이미 받은 토큰
        uint purchaseTime;      // 구입한 시간
    }
    
    
    
    /**
     * @dev APIS를 구입하기 위한 Eth을 입금했을 때 발생하는 이벤트
     * @param beneficiary APIS를 구매하고자 하는 지갑의 주소
     * @param amountOfFunds 입금한 Eth의 양 (wei)
     * @param amountOfApis 투자금에 상응하는 APIS 토큰의 양 (wei)
     */
    event ReservedApis(address beneficiary, uint256 amountOfFunds, uint256 amountOfApis);
    
    /**
     * @dev 크라우드 세일 컨트렉트에서 Eth이 인출되었을 때 발생하는 이벤트
     * @param addr 받는 지갑의 주소
     * @param amount 송금되는 양(wei)
     */
    event WithdrawalFunds(address addr, uint256 amount);
    
    /**
     * @dev 구매자에게 토큰이 발급되었을 때 발생하는 이벤트
     * @param funder 토큰을 받는 지갑의 주소
     * @param amountOfFunds 입금한 투자금의 양 (wei)
     * @param amountOfApis 발급 받는 토큰의 양 (wei)
     */
    event WithdrawalApis(address funder, uint256 amountOfFunds, uint256 amountOfApis);
    
    
    /**
     * @dev 투자금 입금 후, 아직 토큰을 발급받지 않은 상태에서, 환불 처리를 했을 때 발생하는 이벤트
     * @param _backer 환불 처리를 진행하는 지갑의 주소
     * @param _amountFunds 환불하는 투자금의 양
     * @param _amountApis 취소되는 APIS 양
     */
    event Refund(address _backer, uint256 _amountFunds, uint256 _amountApis);
    
    
    /**
     * @dev 크라우드 세일 진행 중에만 동작하도록 제한하고, APIS의 가격도 설정되어야만 한다.
     */
    modifier onSale() {
        require(now >= startTime);
        require(now < endTime);
        require(closed == false);
        require(priceOfApisPerFund > 0);
        _;
    }
    
    /**
     * @dev 크라우드 세일 종료 후에만 동작하도록 제한
     */
    modifier onFinished() {
        require(now >= endTime || closed == true);
        _;
    }
    
    /**
     * @dev 화이트리스트에 등록되어있어야하고 아직 구매완료 되지 않은 투자금이 있어야만 한다.
     */
    modifier claimable() {
        require(whiteList.isInWhiteList(msg.sender) == true);
        require(fundersProperty[msg.sender].reservedFunds > 0);
        _;
    }
    
    
    /**
     * @dev 크라우드 세일 컨트렉트를 생성한다.
     * @param _fundingGoalApis 판매하는 토큰의 양 (APIS 단위)
     * @param _startTime 크라우드 세일을 시작하는 시간
     * @param _endTime 크라우드 세일을 종료하는 시간
     * @param _addressOfApisTokenUsedAsReward APIS 토큰의 컨트렉트 주소
     * @param _addressOfWhiteList WhiteList 컨트렉트 주소
     */
    function ApisCrowdSale (
        uint256 _fundingGoalApis,
        uint _startTime,
        uint _endTime,
        address _addressOfApisTokenUsedAsReward,
        address _addressOfWhiteList
    ) public {
        require (_fundingGoalApis > 0);
        require (_startTime > now);
        require (_endTime > _startTime);
        require (_addressOfApisTokenUsedAsReward != 0x0);
        require (_addressOfWhiteList != 0x0);
        
        fundingGoal = _fundingGoalApis * 10 ** uint256(decimals);
        
        // 1 Qtum으로 구매할 수 있는 APIS의 개수
        // priceOfApisPerFund = 5000;
        startTime = _startTime;
        endTime = _endTime;
        
        // 오버플로우 방지
        require (fundingGoal > _fundingGoalApis);
        
        // 토큰 스마트컨트렉트를 불러온다
        tokenReward = ApisToken(_addressOfApisTokenUsedAsReward);
        
        // 화이트 리스트를 가져온다
        whiteList = WhiteList(_addressOfWhiteList);
    }
    
    /**
     * @dev 판매 종료는 1회만 가능하도록 제약한다. 종료 후 다시 판매 중으로 변경할 수 없다
     */
    function closeSale(bool _closed) onlyOwner public {
        require (closed == false);
        
        closed = _closed;
    }
    
    /**
     * @dev 크라우드 세일 시작 전에 1Eth에 해당하는 APIS 량을 설정한다.
     */
    function setPriceOfApis(uint256 price) onlyOwner public {
        require(priceOfApisPerFund == 0);
        
        priceOfApisPerFund = price;
    }
    
    /**
     * @dev 현 시점에서 판매 가능한 목표량을 수정한다.
     * @param _fundingGoalCurrent 현 시점의 판매 목표량 (wei 단위)
     */
    function setCurrentFundingGoal(uint256 _fundingGoalCurrent) onlyOwner public {
        require(_fundingGoalCurrent <= fundingGoal);
        
        fundingGoalCurrent = _fundingGoalCurrent;
    }
    
    
    /**
     * @dev APIS 잔고를 확인한다
     * @param _addr 잔고를 확인하려는 지갑의 주소
     * @return balance 지갑에 들은 APIS 잔고 (wei)
     */
    function balanceOf(address _addr) public view returns (uint256 balance) {
        return tokenReward.balanceOf(_addr);
    }
    
    /**
     * @dev 화이트리스트 등록 여부를 확인한다
     * @param _addr 등록 여부를 확인하려는 주소
     * @return addrIsInWhiteList true : 등록되있음, false : 등록되어있지 않음
     */
    function whiteListOf(address _addr) public view returns (string message) {
        if(whiteList.isInWhiteList(_addr) == true) {
            return "The address is in whitelist.";
        } else {
            return "The address is *NOT* in whitelist.";
        }
    }
    
    
    /**
     * @dev 전달받은 지갑이 APIS 지급 요청이 가능한지 확인한다.
     * @param _addr 확인하는 주소
     * @return message 결과 메시지
     */
    function isClaimable(address _addr) public view returns (string message) {
        if(fundersProperty[_addr].reservedFunds == 0) {
            return "The address has no claimable balance.";
        }
        
        if(whiteList.isInWhiteList(_addr) == false) {
            return "The address must be registered with KYC and Whitelist";
        }
        
        else {
            return "The address can claim APIS!";
        }
    }
    
    /**
     * @dev 함수를 호출하는 지갑이 APIS 지급 요청이 가능한지 확인한다.
     * @return message 결과 메시지
     */
    function isClaimableMe() public view returns (string message) {
        return isClaimable(msg.sender);
    }
    
    
    
    /**
     * @dev 크라우드 세일 컨트렉트로 바로 투자금을 송금하는 경우, buyToken으로 연결한다
     */
    function () onSale public payable {
        buyToken(msg.sender);
    }
    
    /**
     * @dev 토큰을 구입하기 위해 Qtum을 입금받는다.
     * @param _beneficiary 토큰을 받게 될 지갑의 주소
     */
    function buyToken(address _beneficiary) onSale public payable {
        // 주소 확인
        require(_beneficiary != 0x0);
        
        // 크라우드 세일 컨트렉트의 토큰 송금 기능이 정지되어있으면 판매하지 않는다
        bool isLocked = false;
        uint timeLock = 0;
        (isLocked, timeLock) = tokenReward.isWalletLocked_Send(this);
        
        require(isLocked == false);
        
        
        uint256 amountFunds = msg.value;
        uint256 reservedApis = amountFunds * priceOfApisPerFund;
        
        // 오버플로우 방지
        require(reservedApis > amountFunds);
        
        // 목표 금액을 넘어서지 못하도록 한다
        require(totalSoldApis + reservedApis <= fundingGoalCurrent);
        require(totalSoldApis + reservedApis <= fundingGoal);
        
        // 투자자의 자산을 업데이트한다
        fundersProperty[_beneficiary].reservedFunds += amountFunds;
        fundersProperty[_beneficiary].reservedApis += reservedApis;
        fundersProperty[_beneficiary].purchaseTime = now;
        
        // 총액들을 업데이트한다
        totalReceivedFunds += amountFunds;
        totalReservedFunds += amountFunds;
        
        totalSoldApis += reservedApis;
        totalReservedApis += reservedApis;
        
        // 오버플로우 방지
        assert(totalSoldApis >= reservedApis);
        
        
        // 화이트리스트에 등록되어있으면 바로 출금한다
        if(whiteList.isInWhiteList(_beneficiary) == true) {
            withdrawal(_beneficiary);
        }
        else {
            // 토큰 발행 예약 이벤트 발생
            ReservedApis(_beneficiary, amountFunds, reservedApis);
        }
    }
    
    
    
    /**
     * @dev 관리자에 의해서 토큰을 발급한다. 하지만 기본 요건은 갖춰야만 가능하다
     * 
     * @param _target 토큰 발급을 청구하려는 지갑 주소
     */
    function claimApis(address _target) onlyOwner public {
        // 화이트 리스트에 있어야만 하고
        require(whiteList.isInWhiteList(_target) == true);
        // 예약된 투자금이 있어야만 한다.
        require(fundersProperty[_target].reservedFunds > 0);
        
        withdrawal(_target);
    }
    
    /**
     * @dev 예약한 토큰의 실제 지급을 요청하도록 한다.
     * 
     * APIS를 구매하기 위해 Qtum을 입금할 경우, 관리자의 검토를 위한 7일의 유예기간이 존재한다.
     * 유예기간이 지나면 토큰 지급을 요구할 수 있다.
     */
    function claimMyApis() claimable public {
        withdrawal(msg.sender);
    }
    
    
    /**
     * @dev 구매자에게 토큰을 지급한다.
     * @param funder 토큰을 지급할 지갑의 주소
     */
    function withdrawal(address funder) internal {
        // 구매자 지갑으로 토큰을 전달한다
        assert(tokenReward.transferFrom(owner, funder, fundersProperty[funder].reservedApis));
        
        fundersProperty[funder].withdrawedApis += fundersProperty[funder].reservedApis;
        fundersProperty[funder].paidFunds += fundersProperty[funder].reservedFunds;
        
        // 오버플로우 방지
        assert(fundersProperty[funder].withdrawedApis >= fundersProperty[funder].reservedApis);  
        
        // 총액에 반영
        totalReservedFunds -= fundersProperty[funder].reservedFunds;
        totalPaidFunds += fundersProperty[funder].reservedFunds;
        
        totalReservedApis -= fundersProperty[funder].reservedApis;
        totalWithdrawedApis += fundersProperty[funder].reservedApis;
        
        // APIS가 출금 되었음을 알리는 이벤트
        WithdrawalApis(funder, fundersProperty[funder].reservedFunds, fundersProperty[funder].reservedApis);
        
        // 인출하지 않은 APIS 잔고를 0으로 변경해서, Qtum 재입금 시 이미 출금한 토큰이 다시 출금되지 않게 한다.
        fundersProperty[funder].reservedFunds = 0;
        fundersProperty[funder].reservedApis = 0;
    }
    
    
    /**
     * @dev 아직 토큰을 발급받지 않은 지갑을 대상으로, 환불을 진행할 수 있다.
     * @param _funder 환불을 진행하려는 지갑의 주소
     */
    function refund(address _funder) onlyOwner public {
        require(fundersProperty[_funder].reservedFunds > 0);
        
        uint256 amountFunds = fundersProperty[_funder].reservedFunds;
        uint256 amountApis = fundersProperty[_funder].reservedApis;
        
        // Eth을 환불한다
        _funder.transfer(amountFunds);
        
        totalReceivedFunds -= amountFunds;
        totalReservedFunds -= amountFunds;
        
        totalSoldApis -= amountApis;
        totalReservedApis -= amountApis;
        
        fundersProperty[_funder].reservedFunds = 0;
        fundersProperty[_funder].reservedApis = 0;
        
        Refund(_funder, amountFunds, amountApis);
    }
    
    
    /**
     * @dev 펀딩이 종료된 이후면, 적립된 투자금을 반환한다.
     * @param remainRefundable true : 환불할 수 있는 금액은 남기고 반환한다. false : 모두 반환한다
     */
    function withdrawalFunds(bool remainRefundable) onlyOwner public {
        require(now > endTime || closed == true);
        
        uint256 amount = 0;
        if(remainRefundable) {
            amount = this.balance - totalReservedFunds;
        } else {
            amount = this.balance;
        }
        
        if(amount > 0) {
            msg.sender.transfer(amount);
            
            WithdrawalFunds(msg.sender, amount);
        }
    }
    
    /**
     * @dev 크라우드세일 컨트렉트에 모인 Qtum을 확인한다.
     * @return balance Qtum 잔고 (Satoshi)
     */
    function getContractBalance() onlyOwner public constant returns (uint256 balance) {
        return this.balance;
    }
}
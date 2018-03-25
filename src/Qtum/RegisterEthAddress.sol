pragma solidity ^0.4.18;

import './Ownable.sol';

/**
 * @title RegisterEthAddress
 * @dev QTUM에서 지급된 APIS 토큰을 이더리움으로 이동하기 위해 입력하는 ETH 주소에 대한 QTUM 주소를 증명해야한다.
 * @dev QRC20で支給されたAPISトークンをERC20トークンで変えるように入力したETHのアドレスに対するQTUMアドレスを証明してください。
 * @dev Must prove the QTUM address for the ETH address you enter to move the APIS token paid in QTUM to etherium.
 */
contract RegisterEthAddress is Ownable {
    address[] public qtumAddressList;
    mapping (address => address) internal ethAddresses;
    
    event RegisterEthAddress(address qtumAddress, address ethAddress);
    event ClearEthAddress(address qtumAddress);
    
    /**
     * @dev APIS 토큰을 받을 ETH 주소를 입력한다.
     * @dev APIS　トークンをもらうETHAddressを入力します。
     * @dev Enter the ETH address to receive the APIS token. 
	 *
     * @param ethAddress 토큰 지급 ETH 주소
	 *					 Token配布されるETHAddress
	 *					 ethAddress Token paid ETH address
     */
    function registerEthAddress(address ethAddress) public {
        require(ethAddresses[msg.sender] == 0x0);
        
        qtumAddressList.push(msg.sender);
        ethAddresses[msg.sender] = ethAddress;
        
        emit RegisterEthAddress(msg.sender, ethAddress);
    }
    
    /**
     * @dev 전달된 QTUM 주소에 할당된 ETH 주소를 확인한다.
	 * @dev QTUMAddressに対するETHAddressを確認する。 
	 * @dev Identify the ETH address assigned to the delivered QTUM address. 
     */
    function checkEthAddress(address qtumAddress) public view returns(address ethAddress) {
        ethAddress = ethAddresses[qtumAddress];
    }
    
    /**
     * @dev QTUM 주소에 할당된 ETH 주소를 삭제한다. (사용자가 잘 못 입력한 경우를 대비)
     * @dev QTUMAddressに対するETHAddressを消す。(使用者が間違えて入力した時）
     * @dev Delete the ETH address assigned to the QTUM address. (In case the user has entered incorrectly)
     */
    function clearEthAddress(address qtumAddress) onlyOwner public {
        ethAddresses[qtumAddress] = 0x0;
        
        emit ClearEthAddress(qtumAddress);
    }
    
    /**
     * @dev QTUM 입금은 거부한다.
　　 * @dev QTUM入金は拒否する。
     * @dev Reject QTUM deposit
     */
    function () public payable {
        revert();
    }
}
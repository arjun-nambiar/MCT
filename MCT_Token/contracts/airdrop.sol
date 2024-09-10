pragma solidity >=0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./MundoCryptoToken.sol";


contract Airdrop is Ownable {
    using SafeMath for uint;

    address public tokenAddr;

    constructor(address _tokenAddr) public {
        tokenAddr = _tokenAddr;
    }

    function dropTokens(address[] memory _recipients, uint256[] memory _amount) public onlyOwner returns (bool) {
       
        for (uint i = 0; i < _recipients.length; i++) {
            require(_recipients[i] != address(0) && _amount[i] > 0);
            require(Token(tokenAddr).transfer(_recipients[i], _amount[i]));
        }

        return true;
    }


    function withdrawTokens(address beneficiary) public onlyOwner {
        require(Token(tokenAddr).transfer(beneficiary, Token(tokenAddr).balanceOf(address(this))));
    }
}
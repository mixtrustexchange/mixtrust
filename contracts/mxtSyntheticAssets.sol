pragma solidity ^0.4.26;

import "SafeMath.sol"
import "ERC20Token.sol";


contract mxtSyntheticAssets is ERC20Token {
    using SafeMath for uint256;

    event Synthesize(address indexed to, uint256 indexed amount, uint256 indexed locked);
    event Burn(address indexed from, uint256 indexed amount, uint256 indexed unlocked);
    event ChangeRate(uint256 indexed oldRate, uint256 indexed newRate);

    uint256 public rate;
    uint256 public rateDecimals;

    ERC20Token private _baseToken;

    mapping(address => uint256) public lockedMXT;

    string public name;
    string public symbol;
    uint8 public decimals;

    constructor(address _issuer, address _token, string _name, string _symbol, uint8 _decimals, uint256 _rateDecimals) public Owned(_issuer){
        _baseToken = ERC20Token(_token);

        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        totalSupply = uint256(0);
        balances[_issuer] = uint256(0);

        rate = 0;
        rateDecimals = 10 ** _rateDecimals;
    }

    function setRate(uint256 newRate) onlyOwner public {
        require(newRate != 0);
        require(rate != newRate);

        emit ChangeRate(rate, newRate);

        rate = newRate;
    }

    function synthesize(uint256 _amount) public {
        address user = msg.sender;

        require(rate != 0);

        uint256 userMXTBalance = _baseToken.balanceOf(user);
        uint256 tokenCost = _amount.mul(rate);

        tokenCost = tokenCost.div(rateDecimals);
        require(tokenCost <= userMXTBalance);

        _baseToken.transferFrom(user, address(this), tokenCost);
        lockedMXT[user] = lockedMXT[user].add(tokenCost);
        _synthesizeAssets(user, _amount, tokenCost);
    }

    function redeem(uint256 _tokenAmount) public {
        address user = msg.sender;

        require(rate != 0);
        uint256 mxtBalance = lockedMXT[user];
        require(mxtBalance >= _tokenAmount, "MXT unlock out of range");

        uint256 synBalance = balanceOf(user);
        uint256 synBurnAmount = _tokenAmount.mul(rateDecimals);
        synBurnAmount = synBurnAmount.div(rate);

        require(synBalance >= synBurnAmount, "mxtETH insufficient");

        _burnAssets(user, synBurnAmount, _tokenAmount);

        _baseToken.transfer(user, _tokenAmount);
        lockedMXT[user] = lockedMXT[user].sub(_tokenAmount);
    }

    function _synthesizeAssets(address _to, uint256 _amount, uint256 _locked) private returns (bool) {
        totalSupply = totalSupply.add(_amount);
        balances[_to] = balances[_to].add(_amount);

        emit Synthesize(_to, _amount, _locked);
        emit Transfer(address(0), _to, _amount);
        return true;
    }

    function _burnAssets(address _from, uint256 _amount, uint256 _unlocked) private returns (bool) {
        balances[_from] = balances[_from].sub(_amount);
        totalSupply = totalSupply.sub(_amount);

        emit Burn(_from, _amount, _unlocked);
        emit Transfer(_from, address(0), _amount);

        return true;
    }
}

pragma solidity ^0.4.17;

contract Owner {
  address public owner;
  modifier onlyOwner() {
   require(msg.sender == owner);
    _;
  }

  function Owner(address _owner) public {
    owner = _owner;
  }

  function changeOwner(address _newOwnerAddr) public onlyOwner {
    owner = _newOwnerAddr;
  }
}

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  /**
  * @dev Substracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }
}

contract GreenX is Owner {
  using SafeMath for uint256;

  // Variables for ERC standard
  string public name = "GreenX";
  string public symbol = "GXT";
  uint8 public decimals = 18;
  uint256 public totalSupply = 500000000*10**18; // 500.000.000 tokens
  
  mapping(address => uint256) balances;
  mapping(address => mapping (address => uint256)) internal allowed;

  event Approval(address indexed owner, address indexed spender, uint256 value);
  event Transfer(address indexed from, address indexed to, uint256 value);

  // Variables for control
  address public portal;
  address public admin;

  address public fundKeeperAddress;
  address public founderAddress;
  address public teamAddress;
  address public reservedAddress;
  
  // Variables for sale process
  mapping(address => bool) public privateList;
  mapping(address => bool) public whiteList;
  mapping(address => uint256) public noneKYCInvestedMoney;

  // Token price per 1 Ether
  uint256 public privateSalePrice;
  uint256 public preSalePrice;
  uint256 public icoStandardPrice;
  uint256 public icoFirstPhasePrice;
  uint256 public icoSecondPhasePrice;

  uint256 NOT_SALE = 0;
  uint256 IN_PRIVATE_SALE = 1;
  uint256 IN_PRESALE = 2;
  uint256 END_PRESALE = 3;
  uint256 IN_ICO_PHASE1 = 4;
  uint256 IN_ICO_PHASE2 = 5;
  uint256 IN_ICO_PHASE3 = 6;
  uint256 END_SALE = 7;

  uint256 private saleState;
  uint256 private icoStartTime;
  uint256 private icoEndTime;

  uint founderAllocateTimes = 1;
  uint teamAllocateTimes = 1;

  bool public inactive;
  bool public isSelling;
  bool public isTransferable;

  // Sale info
  uint256 TOKEN_FOR_ICO = 250000000 * 10 ** 18; // 250m
  uint256 public referalReservedTokenNumber = 50000000 * 10**18; // 50m
  uint256 public reservedTokenNumber = 1200000000 * 10 ** 18; // 120m
  uint256 public founderTokenNumber = 50000000 * 10 ** 18; // 50m
  uint256 public teamTokenNumber = 30000000 * 10 ** 18; // 30m

  uint256 public availableTokenForSale = TOKEN_FOR_ICO;
  uint256 public availableReservedTokenNumber = reservedTokenNumber + referalReservedTokenNumber;


  event AddToWhiteList(address investorAddr);
  event RemoveFromWhiteList(address investorAddr);
  event AddToPrivateInvestor(address investorAddr);
  event RemoveFromPrivateInvestor(address investorAddr);

  event StartPrivateSale(uint256 state);
  event StartPresale(uint256 state);
  event EndPresale(uint256 state);
  event StartICO(uint256 state);
  event EndICO(uint256 state);

  event SetPrivateSalePrice(uint256 price);
  event SetPreSalePrice(uint256 price);
  event SetICOPrice(uint256 price);

  event IssueToken(address investor,uint256 amount, uint256 tokenAmount, uint state);
  event RevokeToken(address noneKycAddress, uint256 numberOfEth, uint256 numberOfToken, uint256 fee);

  event AllocateTokenForFounder(address founderAddress, uint256 founderAllocateTimes, uint256 amount);
  event AllocateTokenForTeam(address teamAddress, uint256 teamAllocateTimes, uint256 amount);
  event AllocateReservedToken(address reservedAddress, uint256 amount);

  event ActivateContract();
  event DeactivateContract();

  modifier isActive() {
    require(inactive == false);
    _;
  }

  modifier isInSale() {
    require(isSelling == true);
    _;
  }

  modifier transferable() {
    require(isTransferable == true);
    _;
  }

  modifier onlyOwnerOrAdminOrPortal() {
    require(msg.sender == owner || msg.sender == admin || msg.sender == portal);
    _;
  }

  modifier onlyOwnerOrAdmin() {
//    require(msg.sender == owner || msg.sender == admin || msg.sender == portal);
	require(msg.sender == owner || msg.sender == admin);
    _;
  }

  function GreenX(address fundAddr, address adminAddr, address portalAddr) Owner(msg.sender) public {
    fundKeeperAddress = fundAddr;
    admin = adminAddr;
    portal = portalAddr;
  }

  /**
   * ERC20 Transfer token
   */
  function transfer(address _to, uint256 _value) transferable external returns (bool) {
    require(_to != address(0));
    require(_value <= balances[msg.sender]);

    // SafeMath.sub will throw if there is not enough balance.
    balances[msg.sender] = balances[msg.sender].sub(_value);
    balances[_to] = balances[_to].add(_value);
    Transfer(msg.sender, _to, _value);
    return true;
  }

  /**
   * ERC20 TransferFrom token
   */
  function transferFrom(address _from, address _to, uint256 _value) transferable isActive external returns (bool) {
    require(_to != address(0));
    require(_value <= balances[_from]);
    require(_value <= allowed[_from][msg.sender]);

    balances[_from] = balances[_from].sub(_value);
    balances[_to] = balances[_to].add(_value);
    allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
    Transfer(_from, _to, _value);
    return true;
  }

  /**
   * ERC20 approve
   */
  function approve(address _spender, uint256 _value) transferable isActive external returns (bool) {
    allowed[msg.sender][_spender] = _value;
    Approval(msg.sender, _spender, _value);
    return true;
  }

  /**
   * ERC20 allowance
   */
  function allowance(address _owner, address _spender) public view returns (uint256) {
    return allowed[_owner][_spender];
  }
  /**
   * ERC20 balanceOf
   */
  function balanceOf(address _owner) public view returns (uint256 balance) {
    return balances[_owner];
  }

  function () public payable isActive isInSale {
    uint state = getCurrentState();

    require(state >= IN_PRIVATE_SALE);

    // Private investor
    if (privateList[msg.sender] == true) {
      return issueTokenForPrivateInvestor(state);
    }

    if (state == IN_PRESALE) {
      return issueTokenForPresale(state);
    }

    if (IN_ICO_PHASE1 <= state && state <= IN_ICO_PHASE3) {
      return issueTokenForICO(state);
    }

    revert();
  }

  function getCurrentState() public view returns(uint256) {
    if (saleState == IN_ICO_PHASE1) {
      if (now > icoStartTime + 45 days) {
        return END_SALE;
      }
      if (now > icoStartTime + 30 days) {
        return IN_ICO_PHASE3;
      }
      if (now > icoStartTime + 15 days) {
        return IN_ICO_PHASE2;
      }
      return IN_ICO_PHASE1;
    }
    return saleState;
  }

  function issueTokenForPrivateInvestor(uint256 state) private {
    uint256 price = privateSalePrice;
    issueToken(price, state);
  }

  function issueTokenForPresale(uint256 state) private {
    uint256 price = preSalePrice;
    trackdownInvestedEther();
    issueToken(price, state);
  }

  function issueTokenForICO(uint256 state) private {
    uint256 price = icoStandardPrice;
    if (state == IN_ICO_PHASE1) {
      price = icoFirstPhasePrice;
    } else if (state == IN_ICO_PHASE2) {
      price = icoSecondPhasePrice;
    }
    trackdownInvestedEther();
    issueToken(price, state);
  }

  function trackdownInvestedEther() private {
    if (whiteList[msg.sender] == false) {
      noneKYCInvestedMoney[msg.sender] = noneKYCInvestedMoney[msg.sender].add(msg.value);
    }
  }

  function issueToken(uint256 price, uint256 state) private {
    require(fundKeeperAddress != address(0));
    address investor = msg.sender;
    uint amount = msg.value.mul(price).mul(10**18).div(1 ether);
    require(availableTokenForSale >= amount);

    balances[investor] = balances[investor].add(amount);
    availableTokenForSale = availableTokenForSale.sub(amount);
    IssueToken(investor, msg.value, amount, state);

    // Move ether to fund keeper address
    fundKeeperAddress.transfer(msg.value);
  }

  function addToWhitelist(address[] investorAddrs) isActive onlyOwnerOrAdminOrPortal external returns(bool) {
    for (uint256 i = 0; i < investorAddrs.length; i++) {
      whiteList[investorAddrs[i]] = true;
      AddToWhiteList(investorAddrs[i]);
    }
    return true;
  }

  function removeFromWhitelist(address[] investorAddrs) isActive onlyOwnerOrAdminOrPortal external returns(bool) {
    for (uint256 i = 0; i < investorAddrs.length; i++) {
      whiteList[investorAddrs[i]] = false;
      RemoveFromWhiteList(investorAddrs[i]);
    }
    return true;
  }

  function addPrivateInvestor(address[] investorAddrs) isActive onlyOwnerOrAdminOrPortal external returns(bool) {
    for (uint256 i = 0; i < investorAddrs.length; i++) {
      privateList[investorAddrs[i]] = true;
      AddToPrivateInvestor(investorAddrs[i]);
    }
    return true;
  }

  function removePrivateInvestor(address[] investorAddrs) isActive onlyOwnerOrAdminOrPortal external returns(bool) {
    for (uint256 i = 0; i < investorAddrs.length; i++) {
      privateList[investorAddrs[i]] = false;
      RemoveFromPrivateInvestor(investorAddrs[i]);
    }
    return true;
  }

  function startPrivateSale() isActive onlyOwnerOrAdmin external returns (bool) {
    require(saleState == NOT_SALE);
    require(privateSalePrice > 0);

    saleState = IN_PRIVATE_SALE;
    isSelling = true;
    StartPrivateSale(IN_PRIVATE_SALE);
    return true;
  }

  function startPreSale() isActive onlyOwnerOrAdmin external returns (bool) {
    require(saleState < IN_PRESALE);
    require(preSalePrice != 0);
    saleState = IN_PRESALE;
    isSelling = true;
    StartPresale(IN_PRESALE);
    return true;
  }

  function endPreSale() isActive onlyOwnerOrAdmin external returns (bool) {
    require(saleState == IN_PRESALE);
    saleState = END_PRESALE;
    isSelling = false;
    EndPresale(END_PRESALE);
    return true;
  }

  function startICO() isActive onlyOwnerOrAdmin external returns (bool) {
    require(saleState == END_PRESALE);
    saleState = IN_ICO_PHASE1;
    icoStartTime = now;
    isSelling = true;
    StartICO(IN_ICO_PHASE1);
    return true;
  }

  function endICO() isActive onlyOwnerOrAdmin external returns (bool) {
    require(getCurrentState() == END_SALE);
    require(icoEndTime == 0);

    saleState = END_SALE;
    isSelling = false;
    icoEndTime = now;
    EndICO(END_SALE);
    return true;
  }

  function setPrivateSalePrice(uint256 tokenPerEther) onlyOwnerOrAdmin external returns(bool) {
    require(getCurrentState() == NOT_SALE);
    privateSalePrice = tokenPerEther;
    SetPrivateSalePrice(tokenPerEther);
    return true;
  }

  function setPreSalePrice(uint256 tokenPerEther) onlyOwnerOrAdmin external returns(bool) {
    require(getCurrentState() < IN_PRESALE);
    preSalePrice = tokenPerEther;
    SetPreSalePrice(tokenPerEther);
    return true;
  }

  function setICOPrice(uint256 tokenPerEther) onlyOwnerOrAdmin external returns(bool) {
    require(getCurrentState() < IN_ICO_PHASE1);
    icoStandardPrice = tokenPerEther;
    icoFirstPhasePrice = tokenPerEther + tokenPerEther * 20 / 100; // Bonus 20%
    icoSecondPhasePrice = tokenPerEther + tokenPerEther * 10 / 100; // Bonus 10%
    SetICOPrice(tokenPerEther);
    return true;
  }

  function revokeToken(address noneKycAddr, uint256 transactionFee) isActive onlyOwnerOrAdmin external payable {
    uint256 investedAmount = noneKYCInvestedMoney[noneKycAddr];
    require(whiteList[noneKycAddr] == false);
    require(investedAmount > 0);
    require(investedAmount >= transactionFee);
    require(msg.value >= investedAmount);

    uint refundAmount = investedAmount.sub(transactionFee);
    uint tokenRevoked = balances[noneKycAddr];
    noneKYCInvestedMoney[noneKycAddr] = 0;
    balances[noneKycAddr] = 0;
    noneKycAddr.transfer(refundAmount);
    availableTokenForSale = availableTokenForSale.add(tokenRevoked);
    RevokeToken(noneKycAddr, refundAmount, tokenRevoked, transactionFee);
  }

  function activateContract() onlyOwner() external {
    inactive = false;
    ActivateContract();
  }

  function deactivateContract() onlyOwner() external {
    inactive = true;
    DeactivateContract();
  }

  function enableTokenTransfer() onlyOwner external {
    isTransferable = true;
  }

  function changeFundKeeper(address newAddress) onlyOwner external {
    require(fundKeeperAddress != newAddress);
    fundKeeperAddress = newAddress;
  }

  function changeAdminAddress(address newAddress) onlyOwner external {
    require(admin != newAddress);
    admin = newAddress;
  }

  function changePortalAddress(address newAddress) onlyOwner external {
    require(portal != newAddress);
    portal = newAddress;
  }
  
  function changeFounderAddress(address newAddress) onlyOwnerOrAdmin external {
    require(founderAddress != newAddress);
    founderAddress = newAddress;
  }

  function changeTeamAddress(address newAddress) onlyOwnerOrAdmin external {
    require(teamAddress != newAddress);
    teamAddress = newAddress;
  }

  function changeReservedAddress(address newAddress) onlyOwnerOrAdmin external {
    require(reservedAddress != newAddress);
    reservedAddress = newAddress;
  }

  function allocateTokenForFounder() isActive onlyOwnerOrAdmin external {
    require(getCurrentState() == END_SALE);
    require(founderAddress != address(0));

    uint256 amount;
    if (founderAllocateTimes == 1) {
      amount = founderTokenNumber * 20/100;
      balances[founderAddress] = balances[founderAddress].add(amount);
      AllocateTokenForFounder(founderAddress, founderAllocateTimes, amount);
      founderAllocateTimes = 2;
      return;
    }

    if (founderAllocateTimes == 2) {
      require(now >= icoEndTime + 180 days);
      amount = founderTokenNumber * 30/100;
      balances[founderAddress] = balances[founderAddress].add(amount);
      AllocateTokenForFounder(founderAddress, founderAllocateTimes, amount);
      founderAllocateTimes = 3;
      return;
    }

    if (founderAllocateTimes == 3) {
      require(now >= icoEndTime + 365 days);
      amount = founderTokenNumber * 50/100;
      balances[founderAddress] = balances[founderAddress].add(amount);
      AllocateTokenForFounder(founderAddress, founderAllocateTimes, amount);
      return;
    }

    revert();
  }

  function allocateTokenForTeam () isActive onlyOwnerOrAdmin external {
    require(getCurrentState() == END_SALE);
    require(teamAddress != address(0));

    uint256 amount;
    if (teamAllocateTimes == 1) {
      amount = teamTokenNumber * 20/100;
      balances[teamAddress] = balances[teamAddress].add(amount);
      AllocateTokenForTeam(teamAddress, teamAllocateTimes, amount);
      teamAllocateTimes = 2;
      return;
    }

    if (teamAllocateTimes == 2) {
      require(now >= icoEndTime + 180 days);
      amount = teamTokenNumber * 30/100;
      balances[teamAddress] = balances[teamAddress].add(amount);
      AllocateTokenForTeam(teamAddress, teamAllocateTimes, amount);
      teamAllocateTimes = 3;
      return;
    }

    if (teamAllocateTimes == 3) {
      require(now >= icoEndTime + 365 days);
      amount = teamTokenNumber * 50/100;
      balances[teamAddress] = balances[teamAddress].add(amount);
      AllocateTokenForTeam(teamAddress, teamAllocateTimes, amount);
      return;
    }

    revert();
  }

  function moveAllAvailableToken(address tokenHolder) isActive onlyOwnerOrAdmin external {
    require(saleState == END_SALE);
    require(availableTokenForSale > 0);
    require(tokenHolder != address(0));

    balances[tokenHolder] = balances[tokenHolder].add(availableTokenForSale);
    availableTokenForSale = 0;
  }

  function allocateReservedToken(uint amount) isActive onlyOwnerOrAdmin external {
    require(saleState == END_SALE);
    require(availableReservedTokenNumber > 0);
    require(availableReservedTokenNumber >= amount);
    require(reservedAddress != address(0));

    balances[reservedAddress] = balances[reservedAddress].add(amount);
    availableReservedTokenNumber = availableReservedTokenNumber.sub(amount);
    AllocateReservedToken(reservedAddress, amount);
  }

  function decreaseICOStartTimeForTestOnly(uint256 day) public {
    icoStartTime = icoStartTime - day * 1 days;
  }
  function decreaseICOEndTimeForTestOnly(uint256 day) public {
    icoEndTime = icoEndTime - day * 1 days;
  }
}

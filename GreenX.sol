pragma solidity ^0.4.21;


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
    string public constant name = "GreenX";
    string public constant symbol = "GXT";
    uint public constant decimals = 18;
    uint256 constant public totalSupply = 500000000*10**18;
  
    mapping(address => uint256) balances;
    mapping(address => mapping (address => uint256)) internal allowed;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Variables for control
    address public portalAddress;
    address public adminAddress;

    address public wallet;
    address public founderAddress;
    address public teamAddress;
    address public reservedAddress;

    // Variables for sale process
    mapping(address => bool) public privateList;
    mapping(address => bool) public whiteList;
    mapping(address => uint256) public totalInvestedAmountOf;

    // Token price per 1 Ether
    uint256 public privateSalePrice;
    uint256 public preSalePrice;
    uint256 public icoStandardPrice;
    uint256 public ico1stPrice;
    uint256 public ico2ndPrice;

    uint256 private constant NOT_SALE = 0;
    uint256 private constant IN_PRIVATE_SALE = 1;
    uint256 private constant IN_PRESALE = 2;
    uint256 private constant END_PRESALE = 3;
    uint256 private constant IN_1ST_ICO = 4;
    uint256 private constant IN_2ND_ICO = 5;
    uint256 private constant IN_3RD_ICO = 6;
    uint256 private constant END_SALE = 7;

    uint private saleState;
    uint public icoStartTime;
    uint public icoEndTime;

    uint founderAllocatedTime = 1;
    uint teamAllocatedTime = 1;

    bool public inActive;
    bool public isSelling;
    bool public isTransferable;

    // Sale info
    uint256 private constant salesAllocation = 250000000 * 10 ** 18;
    uint256 private constant bountyAllocation = 50000000 * 10**18;
    uint256 private constant reservedAllocation = 1200000000 * 10 ** 18;
    uint256 private constant founderAllocation = 50000000 * 10 ** 18;
    uint256 private constant teamAllocation = 30000000 * 10 ** 18;

    uint256 public availableTokenForSale;
    uint256 public availableReservedAndBountyAllocation;

    event AddToWhiteList(address investorAddr);
    event RemoveFromWhiteList(address investorAddr);
    event AddToPrivateList(address investorAddr);
    event RemoveFromPrivateList(address investorAddr);
    event StartPrivateSale(uint256 state);
    event StartPresale(uint256 state);
    event EndPresale(uint256 state);
    event StartICO(uint256 state);
    event EndICO(uint256 state);
    event SetPrivateSalePrice(uint256 price);
    event SetPreSalePrice(uint256 price);
    event SetICOPrice(uint256 price);
    event IssueToken(address investor, uint256 amount, uint256 tokenAmount, uint state);
    event RevokeToken(address noneKycAddress, uint256 numberOfEth, uint256 numberOfToken, uint256 fee);
    event AllocateTokenForFounder(address founderAddress, uint256 founderAllocatedTime, uint256 amount);
    event AllocateTokenForTeam(address teamAddress, uint256 teamAllocatedTime, uint256 amount);
    event AllocateReservedToken(address reservedAddress, uint256 amount);
    event ActivateContract();
    event DeactivateContract();

    modifier isActive() {
        require(inActive == false);
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
        require(msg.sender == owner || msg.sender == adminAddress || msg.sender == portalAddress);
        _;
    }

    modifier onlyOwnerOrAdmin() {
        require(msg.sender == owner || msg.sender == adminAddress);
        _;
    }

    function GreenX(address fundAddr, address adminAddr, address portalAddr) public Owner(msg.sender) {
        wallet = fundAddr;
        adminAddress = adminAddr;
        portalAddress = portalAddr;
        inActive = true;
        availableTokenForSale = salesAllocation;
        availableReservedAndBountyAllocation = reservedAllocation + bountyAllocation;
    }

    function () external payable isActive isInSale {
        uint state = getCurrentState();
        require(state >= IN_PRIVATE_SALE && state < END_SALE);
        bool isPrivate = privateList[msg.sender];
        if (isPrivate == true) {
            return issueTokenForPrivateInvestor(state);
        }
        if (state == IN_PRESALE) {
            return issueTokenForPresale(state);
        }
        if (IN_1ST_ICO <= state && state <= IN_3RD_ICO) {
            return issueTokenForICO(state);
        }
        revert();
    }

    /**
    * ERC20 Transfer token
    */
    function transfer(address _to, uint256 _value) external transferable isActive returns (bool) {
        require(_to != address(0));
        require(_value <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(_value);
        balances[_to] = balances[_to].add(_value);
        emit Transfer(msg.sender, _to, _value);
        return true;
    }

    /**
    * ERC20 TransferFrom token
    */
    function transferFrom(address _from, address _to, uint256 _value) external transferable isActive returns (bool) {
        require(_to != address(0));
        require(_value <= balances[_from]);
        require(_value <= allowed[_from][msg.sender]);
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);
        emit Transfer(_from, _to, _value);
        return true;
    }

    /**
    * ERC20 approve
    */
    function approve(address _spender, uint256 _value) external transferable isActive returns (bool) {
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }

    function addToWhitelist(address[] investorAddrs) external isActive onlyOwnerOrAdminOrPortal returns(bool) {
        for (uint256 i = 0; i < investorAddrs.length; i++) {
            whiteList[investorAddrs[i]] = true;
            emit AddToWhiteList(investorAddrs[i]);
        }
        return true;
    }

    function removeFromWhitelist(address[] investorAddrs) external isActive onlyOwnerOrAdminOrPortal returns(bool) {
        for (uint256 i = 0; i < investorAddrs.length; i++) {
            whiteList[investorAddrs[i]] = false;
            emit RemoveFromWhiteList(investorAddrs[i]);
        }
        return true;
    }

    function addToPrivateList(address[] investorAddrs) external isActive onlyOwnerOrAdminOrPortal returns(bool) {
        for (uint256 i = 0; i < investorAddrs.length; i++) {
            privateList[investorAddrs[i]] = true;
            emit AddToPrivateList(investorAddrs[i]);
        }
        return true;
    }

    function removeFromPrivateList(address[] investorAddrs) external isActive onlyOwnerOrAdminOrPortal returns(bool) {
        for (uint256 i = 0; i < investorAddrs.length; i++) {
            privateList[investorAddrs[i]] = false;            
            emit RemoveFromPrivateList(investorAddrs[i]);
        }
        return true;
    }

    function startPrivateSale() external isActive onlyOwnerOrAdmin returns (bool) {
        require(saleState == NOT_SALE);
        require(privateSalePrice > 0);

        saleState = IN_PRIVATE_SALE;
        isSelling = true;
        emit StartPrivateSale(saleState);
        return true;
    }

    function startPreSale() external isActive onlyOwnerOrAdmin returns (bool) {
        require(saleState < IN_PRESALE);
        require(preSalePrice != 0);

        saleState = IN_PRESALE;
        isSelling = true;
        emit StartPresale(saleState);
        return true;
    }

    function endPreSale() external isActive onlyOwnerOrAdmin returns (bool) {
        require(saleState == IN_PRESALE);

        saleState = END_PRESALE;
        isSelling = false;
        emit EndPresale(saleState);
        return true;
    }

    function startICO() external isActive onlyOwnerOrAdmin returns (bool) {
        require(saleState == END_PRESALE);

        saleState = IN_1ST_ICO;
        icoStartTime = now;
        isSelling = true;
        emit StartICO(saleState);
        return true;
    }

    function endICO() external isActive onlyOwnerOrAdmin returns (bool) {
        require(getCurrentState() == IN_3RD_ICO);
        require(icoEndTime == 0);

        saleState = END_SALE;
        isSelling = false;
        icoEndTime = now;
        emit EndICO(saleState);
        return true;
    }

    function setPrivateSalePrice(uint256 tokenPerEther) external onlyOwnerOrAdmin returns(bool) {
        privateSalePrice = tokenPerEther;
        emit SetPrivateSalePrice(privateSalePrice);
        return true;
    }

    function setPreSalePrice(uint256 tokenPerEther) external onlyOwnerOrAdmin returns(bool) {
        preSalePrice = tokenPerEther;
        emit SetPreSalePrice(preSalePrice);
        return true;
    }

    function setICOPrice(uint256 tokenPerEther) external onlyOwnerOrAdmin returns(bool) {
        icoStandardPrice = tokenPerEther;
        ico1stPrice = tokenPerEther + tokenPerEther * 20 / 100;
        ico2ndPrice = tokenPerEther + tokenPerEther * 10 / 100;
        emit SetICOPrice(icoStandardPrice);
        return true;
    }

    function revokeToken(address noneKycAddr, uint256 transactionFee) external isActive onlyOwnerOrAdmin payable {
        uint256 investedAmount = totalInvestedAmountOf[noneKycAddr];
        require(whiteList[noneKycAddr] == false);
        require(privateList[noneKycAddr] == false);
        require(investedAmount > 0);
        require(investedAmount >= transactionFee);
        require(msg.value >= investedAmount);
        uint256 refundAmount = investedAmount.sub(transactionFee);
        uint tokenRevoked = balances[noneKycAddr];
        uint256 backFund = msg.value.sub(refundAmount);
        totalInvestedAmountOf[noneKycAddr] = 0;
        balances[noneKycAddr] = 0;
        availableTokenForSale = availableTokenForSale.add(tokenRevoked);
        noneKycAddr.transfer(refundAmount);
        msg.sender.transfer(backFund);
        emit RevokeToken(noneKycAddr, refundAmount, tokenRevoked, transactionFee);
    }

    function activateContract() external onlyOwner {
        inActive = false;
        emit ActivateContract();
    }

    function deactivateContract() external onlyOwner {
        inActive = true;
        emit DeactivateContract();
    }

    function enableTokenTransfer() external onlyOwner {
        isTransferable = true;
    }

    function changeWallet(address newAddress) external onlyOwner {
        require(wallet != newAddress);
        wallet = newAddress;
    }

    function changeAdminAddress(address newAddress) external onlyOwner {
        require(adminAddress != newAddress);
        adminAddress = newAddress;
    }

    function changePortalAddress(address newAddress) external onlyOwner {
        require(portalAddress != newAddress);
        portalAddress = newAddress;
    }
  
    function changeFounderAddress(address newAddress) external onlyOwnerOrAdmin {
        require(founderAddress != newAddress);
        founderAddress = newAddress;
    }

    function changeTeamAddress(address newAddress) external onlyOwnerOrAdmin {
        require(teamAddress != newAddress);
        teamAddress = newAddress;
    }

    function changeReservedAddress(address newAddress) external onlyOwnerOrAdmin {
        require(reservedAddress != newAddress);
        reservedAddress = newAddress;
    }

    function allocateTokenForFounder() external isActive onlyOwnerOrAdmin {
        require(saleState == END_SALE);
        require(founderAddress != address(0));
        uint256 amount;
        if (founderAllocatedTime == 1) {
            amount = founderAllocation * 20/100;
            balances[founderAddress] = balances[founderAddress].add(amount);
            emit AllocateTokenForFounder(founderAddress, founderAllocatedTime, amount);
            founderAllocatedTime = 2;
            return;
        }
        if (founderAllocatedTime == 2) {
            require(now >= icoEndTime + 180 days);
            amount = founderAllocation * 30/100;
            balances[founderAddress] = balances[founderAddress].add(amount);
            emit AllocateTokenForFounder(founderAddress, founderAllocatedTime, amount);
            founderAllocatedTime = 3;
            return;
        }
        if (founderAllocatedTime == 3) {
            require(now >= icoEndTime + 365 days);
            amount = founderAllocation * 50/100;
            balances[founderAddress] = balances[founderAddress].add(amount);
            emit AllocateTokenForFounder(founderAddress, founderAllocatedTime, amount);
            return;
        }
        revert();
    }

    function allocateTokenForTeam () external isActive onlyOwnerOrAdmin {
        require(saleState == END_SALE);
        require(teamAddress != address(0));
        uint256 amount;
        if (teamAllocatedTime == 1) {
            amount = teamAllocation * 20/100;
            balances[teamAddress] = balances[teamAddress].add(amount);
            emit AllocateTokenForTeam(teamAddress, teamAllocatedTime, amount);
            teamAllocatedTime = 2;
            return;
        }
        if (teamAllocatedTime == 2) {
            require(now >= icoEndTime + 180 days);
            amount = teamAllocation * 30/100;
            balances[teamAddress] = balances[teamAddress].add(amount);
            emit AllocateTokenForTeam(teamAddress, teamAllocatedTime, amount);
            teamAllocatedTime = 3;
            return;
        }
        if (teamAllocatedTime == 3) {
            require(now >= icoEndTime + 365 days);
            amount = teamAllocation * 50/100;
            balances[teamAddress] = balances[teamAddress].add(amount);
            emit AllocateTokenForTeam(teamAddress, teamAllocatedTime, amount);
            return;
        }
        revert();
    }

    function moveAllAvailableToken(address tokenHolder) external isActive onlyOwnerOrAdmin {
        require(saleState == END_SALE);
        require(availableTokenForSale > 0);
        require(tokenHolder != address(0));
        balances[tokenHolder] = balances[tokenHolder].add(availableTokenForSale);
        availableTokenForSale = 0;
    }

    function allocateReservedToken(uint amount) external isActive onlyOwnerOrAdmin {
        require(saleState == END_SALE);
        require(availableReservedAndBountyAllocation > 0);
        require(availableReservedAndBountyAllocation >= amount);
        require(reservedAddress != address(0));
        balances[reservedAddress] = balances[reservedAddress].add(amount);
        availableReservedAndBountyAllocation = availableReservedAndBountyAllocation.sub(amount);
        emit AllocateReservedToken(reservedAddress, amount);
    }

    /**
    * ERC20 allowance
    */
    function allowance(address _owner, address _spender) external constant returns (uint256) {
        return allowed[_owner][_spender];
    }

    /**
    * ERC20 balanceOf
    */
    function balanceOf(address _owner) external constant returns (uint256 balance) {
        return balances[_owner];
    }

    function getCurrentState() public view returns(uint256) {
        if (saleState == IN_1ST_ICO) {
            if (now > icoStartTime + 30 days) {
                return IN_3RD_ICO;
            }
            if (now > icoStartTime + 15 days) {
                return IN_2ND_ICO;
            }
            return IN_1ST_ICO;
        }
        return saleState;
    }    

    function issueTokenForPrivateInvestor(uint256 state) private {
        uint256 price = privateSalePrice;
        issueToken(price, state);
    }

    function issueTokenForPresale(uint256 state) private {
        uint256 price = preSalePrice;
        issueToken(price, state);
    }

    function issueTokenForICO(uint256 state) private {
        uint256 price = icoStandardPrice;
        if (state == IN_1ST_ICO) {
            price = ico1stPrice;
        } else if (state == IN_2ND_ICO) {
            price = ico2ndPrice;
        }
        issueToken(price, state);
    }

    function issueToken(uint256 price, uint256 state) private {
        require(wallet != address(0));
        address investor = msg.sender;
        uint256 fundedAmount = msg.value;
        uint tokenAmount = fundedAmount.mul(price).mul(10**18).div(1 ether);
        require(availableTokenForSale >= tokenAmount);
        balances[investor] = balances[investor].add(tokenAmount);
        availableTokenForSale = availableTokenForSale.sub(tokenAmount);
        totalInvestedAmountOf[investor] = totalInvestedAmountOf[investor].add(fundedAmount);
        wallet.transfer(fundedAmount);
        emit IssueToken(investor, fundedAmount, tokenAmount, state);
    }

    // function decreaseICOStartTimeForTestOnly(uint256 day) public {
    //   icoStartTime = icoStartTime - day * 1 days;
    // }
    // function decreaseICOEndTimeForTestOnly(uint256 day) public {
    //   icoEndTime = icoEndTime - day * 1 days;
    // }
}
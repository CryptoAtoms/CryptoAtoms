pragma solidity ^0.4.19;

import "./CryptoAtoms.sol";

contract CaCoreInterface {
    function createCombinedAtom(uint, uint) external returns (uint);
    function createRandomAtom() external returns (uint);
    function createTransferAtom(address , address , uint) external;
}

contract CryptoAtomsLogicV2{
    
    address public CaDataAddress = 0x9b3554E6FC4F81531F6D43b611258bd1058ef6D5;
    CaData public CaDataContract = CaData(CaDataAddress);
    CaCoreInterface private CaCoreContract;
    
    bool public pauseMode = false;
    bool public bonusMode = true;
    
    uint128   public newAtomFee = 1 finney;
    uint8     public buyFeeRate = 0;
    
    uint8[4]  public levelupValues  = [0, 
                                       2, 
                                       5, 
                                       10];

    event NewSetRent(address sender, uint atom);
    event NewSetBuy(address sender, uint atom);
    event NewUnsetRent(address sender, uint atom);
    event NewUnsetBuy(address sender, uint atom);
    event NewAutoRentAtom(address sender, uint atom);
    event NewRentAtom(address sender, uint atom, address receiver, uint amount);
    event NewBuyAtom(address sender, uint atom, address receiver, uint amount);
    event NewEvolveAtom(address sender, uint atom);
    event NewBonusAtom(address sender, uint atom);
    
    function() public payable{}
    
    function kill() external
	{
	    require(msg.sender == CaDataContract.CTO());
		selfdestruct(msg.sender); 
	}
	
	modifier onlyAdmin() {
      require(msg.sender == CaDataContract.COO() || msg.sender == CaDataContract.CFO() || msg.sender == CaDataContract.CTO());
      _;
     }
	
	modifier onlyActive() {
        require(pauseMode == false);
        _;
    }
    
    modifier onlyOwnerOf(uint _atomId, bool _flag) {
        require((tx.origin == CaDataContract.atomOwner(_atomId)) == _flag);
        _;
    }
    
    modifier onlyRenting(uint _atomId, bool _flag) {
        uint128 isRent;
        (,,,,,,,isRent,,) = CaDataContract.atoms(_atomId);
        require((isRent > 0) == _flag);
        _;
    }
    
    modifier onlyBuying(uint _atomId, bool _flag) {
        uint128 isBuy;
        (,,,,,,,,isBuy,) = CaDataContract.atoms(_atomId);
        require((isBuy > 0) == _flag);
        _;
    }
    
    modifier onlyReady(uint _atomId) {
        uint32 isReady;
        (,,,,,,,,,isReady) = CaDataContract.atoms(_atomId);
        require(isReady <= now);
        _;
    }
    
    modifier beDifferent(uint _atomId1, uint _atomId2) {
        require(_atomId1 != _atomId2);
        _;
    }
    
    function setCoreContract(address _neWCoreAddress) external {
        require(msg.sender == CaDataAddress);
        CaCoreContract = CaCoreInterface(_neWCoreAddress);
    }
    
    function setPauseMode(bool _newPauseMode) external onlyAdmin {
        pauseMode = _newPauseMode;
    }
    
    function setGiftMode(bool _newBonusMode) external onlyAdmin {
        bonusMode = _newBonusMode;
    }
   
    function setFee(uint128 _newFee) external onlyAdmin {
        newAtomFee = _newFee;
    }
    
    function setRate(uint8 _newRate) external onlyAdmin {
        buyFeeRate = _newRate;
    }
    
    function setLevelup(uint8[4] _newLevelup) external onlyAdmin {
        levelupValues = _newLevelup;
    }
    
    function setIsRentByAtom(uint _atomId, uint128 _fee) external onlyActive onlyOwnerOf(_atomId,true) onlyRenting(_atomId, false) onlyReady(_atomId) {
	    require(_fee > 0);
	    CaDataContract.setAtomIsRent(_atomId,_fee);
	    NewSetRent(tx.origin,_atomId);
  	}
  	
  	function setIsBuyByAtom(uint _atomId, uint128 _fee) external onlyActive onlyOwnerOf(_atomId,true) onlyBuying(_atomId, false){
	    require(_fee > 0);
	    CaDataContract.setAtomIsBuy(_atomId,_fee);
	    NewSetBuy(tx.origin,_atomId);
  	}
  	
  	function unsetIsRentByAtom(uint _atomId) external onlyActive onlyOwnerOf(_atomId, true) onlyRenting(_atomId, true){
	    CaDataContract.setAtomIsRent(_atomId,0);
	    NewUnsetRent(tx.origin,_atomId);
  	}
  	
  	function unsetIsBuyByAtom(uint _atomId) external onlyActive onlyOwnerOf(_atomId, true) onlyBuying(_atomId, true){
	    CaDataContract.setAtomIsBuy(_atomId,0);
	    NewUnsetBuy(tx.origin,_atomId);
  	}
  	
  	function autoRentByAtom(uint _atomId, uint _ownedId) external payable onlyActive beDifferent(_atomId, _ownedId) onlyOwnerOf(_atomId, true) onlyOwnerOf(_ownedId,true) onlyReady(_atomId) onlyReady(_ownedId)  {
        require(newAtomFee == msg.value);
        CaDataAddress.transfer(newAtomFee);
        uint id = CaCoreContract.createCombinedAtom(_atomId,_ownedId);
        NewAutoRentAtom(tx.origin,id);
  	}
  	
  	 function rentByAtom(uint _atomId, uint _ownedId) external payable onlyActive beDifferent(_atomId, _ownedId) onlyOwnerOf(_ownedId, true) onlyRenting(_atomId, true) onlyReady(_ownedId) {
	    address owner = CaDataContract.atomOwner(_atomId);
	    uint128 isRent;
        (,,,,,,,isRent,,) = CaDataContract.atoms(_atomId);
	    require(isRent + newAtomFee == msg.value);
	    owner.transfer(isRent);
	    CaDataAddress.transfer(newAtomFee);
        uint id = CaCoreContract.createCombinedAtom(_atomId,_ownedId);
        NewRentAtom(tx.origin,id,owner,isRent);
  	}
  	
  	function buyByAtom(uint _atomId) external payable onlyActive onlyOwnerOf(_atomId, false) onlyBuying(_atomId, true) {
  	    address owner = CaDataContract.atomOwner(_atomId);
  	    uint128 isBuy;
        (,,,,,,,,isBuy,) = CaDataContract.atoms(_atomId);
	    require(isBuy == msg.value);
	    if(buyFeeRate>0)
	    {
	        uint128 fee = uint128(isBuy/100) * buyFeeRate;
            isBuy = isBuy - fee;
	        CaDataAddress.transfer(fee);
	    }
	    owner.transfer(isBuy);
        CaDataContract.setAtomIsBuy(_atomId,0);
        CaDataContract.setAtomIsRent(_atomId,0);
        CaDataContract.setOwnerAtomsCount(tx.origin,CaDataContract.ownerAtomsCount(tx.origin)+1);
        CaDataContract.setOwnerAtomsCount(owner,CaDataContract.ownerAtomsCount(owner)-1);
        CaDataContract.setAtomOwner(_atomId,tx.origin);
        CaCoreContract.createTransferAtom(owner, tx.origin, _atomId);
        NewBuyAtom(tx.origin,_atomId,owner,isBuy);
  	}
  	
  	function evolveByAtom(uint _atomId) external onlyActive onlyOwnerOf(_atomId, true) {
  	    uint8 lev;
  	    uint8 cool;
  	    uint32 sons;
  	    (,,lev,cool,sons,,,,,) = CaDataContract.atoms(_atomId);
  	    require(lev < 4 && sons >= levelupValues[lev]);
  	    CaDataContract.setAtomLev(_atomId,lev+1);
  	    CaDataContract.setAtomCool(_atomId,cool-1);
        NewEvolveAtom(tx.origin,_atomId);
  	}
  	
  	function receiveBonus() onlyActive external {
  	    require(bonusMode == true && CaDataContract.bonusReceived(tx.origin) == false);
  	    CaDataContract.setBonusReceived(tx.origin,true);
        uint id = CaCoreContract.createRandomAtom();
        NewBonusAtom(tx.origin,id);
    }
    
}

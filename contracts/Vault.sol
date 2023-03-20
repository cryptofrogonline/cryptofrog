pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IGeneScience.sol";
import "./interfaces/IGenesisFrog.sol";

contract Vault is ReentrancyGuard, Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 ONE_DAY = 1 days;
    uint256 BURN_TIME = 30 days;
    uint256 UPGRADE_TIME = 7 days;
    uint256 public FEES = 300;
    uint256 public PERCENT_DIVIDER = 10000;
    uint256 public PROMOTE_REWARD = 800;
    uint256 public dailyPercent = 100;

    IERC20 public busd;
    IGeneScience public geneScience;
    address mysteryBox;
    IGenesisFrog public genesisFrog;

    struct Frog {
        uint256 upgradeDate;
        uint256 lastClaimedDate;
        uint256 claimedAmount;
    }

    struct User{
        address referer;
        uint256 deposited;
        uint256 rewarded;
    }

    mapping(uint256 => Frog) public frogs;
    mapping(address => User) public users;
    address public developer;


    event AddBlack(uint256 tokenId);
    event RemoveBlack(uint256 tokenId);

    constructor (
        IERC20 _busd, 
        address _genesisFrog,
        address _geneScience,
        address _mysteryBox,
        address _developer) {
      busd = _busd;
      genesisFrog = IGenesisFrog(_genesisFrog);
      geneScience = IGeneScience(_geneScience);
      mysteryBox = _mysteryBox;
      developer = _developer;
    }

    modifier onlyFrog(){
        require(address(genesisFrog) == msg.sender, "Vault: caller is not genesisFrog");
        _;
    }

    modifier onlyMysteryBox() {
        require(mysteryBox == msg.sender, "Vault: caller is not mysteryBox");
        _;
    }

    function setDeveloper(address _developer) external onlyOwner{
        developer = _developer;
    }

    function deposit(address investor, uint256 _amount, address referer) external onlyMysteryBox{
        if(address(0) == users[investor].referer && address(0) != referer){
            users[investor].referer = referer;
        }
        if(0 == _amount){
            return;
        }

        uint256 fee = _getFee(_amount);
        uint256 amount = _amount.add(fee);
        busd.safeTransferFrom(investor, address(this), amount);
        busd.transfer(developer, fee);
    
        
        if(address(0) != users[investor].referer){
            uint256 referrerAmount = (_amount * PROMOTE_REWARD).div(PERCENT_DIVIDER);
            busd.transfer(users[investor].referer, referrerAmount);
        }

        users[investor].deposited = users[investor].deposited.add(_amount);
        users[address(this)].deposited = users[address(this)].deposited.add(_amount);

        _addBudget(_amount);
    }

    function _getFee(uint256 _amount) private view returns(uint256){
        return (_amount.mul(FEES)).div(PERCENT_DIVIDER);
    }

    function claimBatch(uint256[] calldata tokenIds) external {
        _claimFrogs(msg.sender, tokenIds);
    }

    function claimByMystery(address owner, uint256 tokenId) external onlyMysteryBox {
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        _claimFrogs(owner, tokenIds);
    }

    function _claimFrogs(address owner, uint256[] memory tokenIds) private {
        uint256 amount = 0;
        for(uint i = 0; i < tokenIds.length; i++){
            amount = amount + _claimFrog(owner, tokenIds[i]);
        }
        if(getBalance() < amount){
            amount = getBalance();
        }
        _addReward(owner, amount);
        busd.safeTransfer(owner, amount);
    }

    function _claimFrog(address owner, uint256 tokenId) private returns(uint256) {
        require(owner == genesisFrog.ownerOf(tokenId), "Vault: caller do not own tokenId");
        _verifyBlack(tokenId);

        uint256 amount = getClaimable(tokenId);
        frogs[tokenId].claimedAmount = frogs[tokenId].claimedAmount.add(amount);
        frogs[tokenId].lastClaimedDate = block.timestamp;

        return amount;
    }

    function getClaimable(uint256 tokenId) public view returns(uint256 amount){
        uint256 claimableSeconds = block.timestamp - frogs[tokenId].lastClaimedDate;
        uint256 genes = genesisFrog.frogGenes(tokenId);
        amount = geneScience.valueToAmount(geneScience.genesMultipleValue(genes));

        amount = (claimableSeconds * amount * dailyPercent).div(PERCENT_DIVIDER * ONE_DAY);
    }

    function burnFrog(uint256 tokenId) external {
        require(block.timestamp > frogs[tokenId].upgradeDate + BURN_TIME, "Vault: The frog can't burn yet.");
        
        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        _claimFrogs(msg.sender, tokenIds);

        uint256 genes = genesisFrog.frogGenes(tokenId);
        uint256 amount = geneScience.valueToAmount(geneScience.genesValue(genes));
        busd.safeTransfer(msg.sender, amount);
        _addReward(msg.sender, amount);

        genesisFrog.burnFrog(tokenId);
    }

    function _addReward(address investor, uint256 amount) private {
        users[investor].rewarded = users[investor].rewarded.add(amount);
        users[address(this)].rewarded = users[address(this)].rewarded.add(amount);
    }

    function upgradeFrog(uint256 tokenId) external {
        require(block.timestamp > frogs[tokenId].upgradeDate + UPGRADE_TIME, "Vault: The frog can't upgrade yet.");

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = tokenId;
        _claimFrogs(msg.sender, tokenIds);

        genesisFrog.upgradeFrog(tokenId);

        frogs[tokenId].upgradeDate = block.timestamp;
    }

    function addFrog(uint256 tokenId) external onlyFrog {
        frogs[tokenId].upgradeDate = block.timestamp;
        frogs[tokenId].lastClaimedDate = block.timestamp;
    }

    mapping(uint256 => bool) public blacklist;

    function _verifyBlack(uint256 tokenId) private view {
        require(!blacklist[tokenId], "Vault: tokenId in the blacklist");
    }

    function addBatchBlack(uint256[] calldata tokenIds) external onlyOwner {
        uint256 genes;
        uint256 value;
        for(uint i = 0; i < tokenIds.length; i++){
            if(0 == frogs[tokenIds[i]].upgradeDate){
                continue;
            }
            genes = genesisFrog.frogGenes(tokenIds[i]);
            value = geneScience.genesValue(genes);
            if( value > (4 * 10000) ){
                continue;
            }
            blacklist[tokenIds[i]] = true;
            emit AddBlack(tokenIds[i]);
        }
    }

    function removeBatchBlack(uint256[] calldata tokenIds) external onlyOwner {
        for(uint i = 0; i < tokenIds.length; i++){
            blacklist[tokenIds[i]] = false;
            emit RemoveBlack(tokenIds[i]);
        }
    }

    uint256 public marketBudget;

    function _addBudget(uint256 _amount) private {
        uint256 budget = _amount.div(100) * 10;
        marketBudget = marketBudget.add(budget);
    }

    function withdrawBudget(uint256 _amount) external onlyOwner nonReentrant {
        require(_amount < marketBudget, "Vault: insufficient market budget");
        busd.safeTransfer(msg.sender, _amount);
        marketBudget = marketBudget - _amount;
    }

    function setDailyPercent(uint256 _dailyPercent) external onlyOwner {
        require(_dailyPercent >= 100 && _dailyPercent < 10000, "Vault: dailyPercent too small");

        dailyPercent = _dailyPercent;
    }

    function getBalance() public view returns(uint256) {
        return IERC20(busd).balanceOf(address(this));
    }
}

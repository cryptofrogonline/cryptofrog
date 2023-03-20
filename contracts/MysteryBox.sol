pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IVault.sol";
import "./interfaces/IGenesisFrog.sol";
import "./interfaces/IGeneScience.sol";
import "./interfaces/IFrogPart.sol";



contract MysteryBox is Ownable, ReentrancyGuard{
    using SafeMath for uint256;

    uint32[8] public SPECIES_LIST = [1, 4, 1, 1, 1, 1, 0, 0];
    IGeneScience public geneScience;
    IFrogPart public frogPart;
    IGenesisFrog public genesisFrog;
    IVault public vault;
    address public freeSigner;
    mapping(uint256 => uint32[]) WEIGHTS;
    uint256 public startDate;

    struct Free {
        uint256 id;
        address owner;
        uint256 value;
        address referer;
    }

    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    mapping(uint256 => bool) frees;

    event OpenFrogBox(address indexed owner, uint256 indexed tokenId, uint256 genes);
    event OpenPartBox(address indexed owner, uint256 genes);
    event OpenFreeBox(uint256 indexed id, address owner);
    event MixFrog(address indexed owner, uint256 indexed tokenId, uint256 genes);

    constructor (
        address _freeSigner,
        address _geneScience,
        uint256 _startDate
    ) {
        freeSigner = _freeSigner;
        geneScience = IGeneScience(_geneScience);
        startDate = _startDate;

        WEIGHTS[2]    = [0,   100, 0,  0,  0,  0,  0, 0];
        WEIGHTS[5]    = [50,  100, 5,  0,  0,  0,  0, 0];
        WEIGHTS[50]   = [50,  100, 50, 5,  0,  0,  0, 0];
        WEIGHTS[100]  = [100, 100, 50, 25, 5,  0,  0, 0];
        WEIGHTS[200]  = [100, 100, 75, 50, 25, 5,  0, 0];
        WEIGHTS[500]  = [100, 100, 75, 50, 50, 15, 0, 0];
        WEIGHTS[1000] = [100, 100, 90, 75, 50, 25, 0, 0];
        WEIGHTS[2000] = [100, 100, 90, 75, 75, 40, 0, 0];
        WEIGHTS[5000] = [100, 100, 90, 90, 90, 90, 0, 0];
    }

    function setFreeSigner(address _freeSigner) external onlyOwner {
        freeSigner = _freeSigner;
    }

    function setStartDate(uint256 _startDate) external onlyOwner {
        require(startDate > block.timestamp, "MysteryBox started");
        startDate = _startDate;
    }

    function setVault(address _vault) external onlyOwner {
        vault = IVault(_vault);
    }

    function setGenesisFrog(address _genesisFrog) external onlyOwner {
        genesisFrog = IGenesisFrog(_genesisFrog);
    }

    function setFrogPart(address _frogPart) external onlyOwner {
        frogPart = IFrogPart(_frogPart);
    }

    function openBox(uint256 value, uint256 amount, address referer) external {
        require(block.timestamp >= startDate, "MysteryBox: cannot deposit at this moment");
        uint256 total = value.mul(amount);
        
        vault.deposit(msg.sender, total, referer);

        uint256 weight = convertToWeight(value);
        require(weight > 2, "MysteryBox: weight > 2");
        for(uint i = 0; i < amount; i++){
            open(weight);
        }
    }

    function open(uint256 weight) private {
        uint256 randomGene = _random(msg.sender, weight);
        uint32[] memory weightList = getWeightList(weight);
        _open(randomGene, weight, weightList);
    }

    function _open(uint256 randomGene, uint256 weight, uint32[] memory weightList) private {
        require(weightList.length > 0, "MysteryBox: invalid weight");

        uint32[] memory bit32List = geneScience.decode(randomGene);
        uint256 genes;
        uint32 mod;
        uint32[] memory traits = new uint32[](8);

        for(uint32 i = 0; i < weightList.length; i++){
            if(0 == weightList[i] || 0 == SPECIES_LIST[i]){
                traits[i] = 0;
                continue;
            }
            uint32 bit32 = bit32List[i] % 100;
            if(bit32 >= weightList[i]){
                traits[i] = 0;
                continue;
            }

            mod = bit32 % SPECIES_LIST[i] + 1;
            traits[i] = mod;
            if(i > 1){
                uint32[] memory partTraits = new uint32[](8);
                partTraits[i] = mod;
                genes = geneScience.encode(partTraits);
                frogPart.born(msg.sender, genes);
                emit OpenPartBox(msg.sender, genes);
            }
        }

        genes = geneScience.encodePacked(
            traits[0],
            traits[1],
            traits[2],
            traits[3],
            traits[4],
            traits[5], 
            uint32(weight));
        uint256 tokenId = _getTokenId();
        genesisFrog.born(msg.sender, tokenId, genes);
        emit OpenFrogBox(msg.sender, tokenId, genes);
    }

    function openFreeBox(Free calldata free, Sig calldata sig) external{
        require(block.timestamp >= startDate, "MysteryBox: cannot deposit at this moment");

        require(!frees[free.id], "MysteryBox: invalid free");
        require(address(0) != free.referer, "MysteryBox: invalid referer");
        require(free.owner == msg.sender, "MysteryBox: Not free owner");

        verifyFree(free, sig.v, sig.r, sig.s);

        uint256 value = free.value;
        uint256 randomGene = _random(msg.sender, free.value);
        require(free.value > 0, "MysteryBox: value > 0");

        uint256 weight = convertToWeight(value);
        require(weight <= 100, "MysteryBox: value <= 100");

        uint32[] memory weightList = getWeightList(weight);
        _open(randomGene, weight, weightList);

        vault.deposit(free.owner, 0, free.referer);
        frees[free.id] = true;
        emit OpenFreeBox(free.id, free.owner);
    }

    function mixFrog(uint256 tokenId, uint256[] calldata partList) external {
        require(partList.length > 0, "MysteryBox: partList.length > 0");

        uint256 _genes = mixPartList(partList);
        require(geneScience.countPart(_genes) == partList.length, "MysteryBox: partList exists in the same trait");

        vault.claimByMystery(msg.sender, tokenId);

        uint256 newTokenId = _getTokenId();
        uint256 newGenes = genesisFrog.mixPartGenes(msg.sender, newTokenId, tokenId, _genes);
        frogPart.burnPartBatch(msg.sender, partList);
        emit MixFrog(msg.sender, newTokenId, newGenes);
    }

    function mixPartList(uint256[] calldata partList) public view returns(uint256 _genes) {
        _genes = partList[0];
        for(uint i = 0; i < partList.length; i++){
            require(frogPart.balanceOf(msg.sender, partList[i]) > 0, "MysteryBox: insufficient balance");
            _genes = _genes | partList[i];
        }
    }

    function getWeightList(uint256 weight) public view returns(uint32[] memory weightList){
        weightList = WEIGHTS[weight];
    }

    uint256 private nonce = 0;
    function _random(address sender, uint256 price) private returns (uint256) {
      uint256 num = uint256(keccak256(abi.encodePacked(block.timestamp, sender, block.number, nonce, price)));
      nonce = num;
      return num;
    }

    function random(address sender, uint256 price) public view returns(uint256){
        return uint256(keccak256(abi.encodePacked(sender, nonce, price)));
    }

    using Counters for Counters.Counter;
    Counters.Counter private _tokenId;
    function _getTokenId() private returns(uint256 ){
        _tokenId.increment();
        uint256 tokenId = _tokenId.current();
        return tokenId;
    }

    function verifyFree(Free calldata free, uint8 _v, bytes32 _r, bytes32 _s) public view {
        address _freeSigner = verifyMessage(keccak256(abi.encode(free)), _v, _r, _s);
        require(freeSigner == _freeSigner, "MysteryBox: wrong free signature");
    }

    function verifyMessage(bytes32 message, uint8 _v, bytes32 _r, bytes32 _s) public pure returns (address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, message));
        address signer = ecrecover(prefixedHashMessage, _v, _r, _s);
        return signer;
    }

    function convertToWeight(uint256 amount) public pure returns(uint256) {
        return amount.div(10 ** 18);
    }
}

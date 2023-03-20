pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/IGeneScience.sol";

contract FrogPart is ERC1155Burnable, Ownable, ReentrancyGuard{
    using Strings for uint256;
    address public mysteryBox;
    IGeneScience public geneScience;

    string public name;
    string public symbol;
    string public baseURI;

    mapping(address => bool) public managers;

    constructor(
            string memory _name,
            string memory _symbol,
            string memory _baseURI,
            address _geneScience,
            address _mysteryBox) ERC1155(_baseURI) {
        name = _name;
        symbol = _symbol;
        baseURI = _baseURI;
        mysteryBox = _mysteryBox;
        geneScience = IGeneScience(_geneScience);
    }

    modifier onlyMysteryBox() {
        require(mysteryBox == _msgSender(), "caller is not the MysteryBox");
        _;
    }

    modifier onlyManager(){
        require(managers[_msgSender()], "caller is not the manager");
        _;
    }

    function uri(uint256 _id) public view virtual override returns (string memory) {
        string memory _uri = geneScience.decodeTokenURI(_id);
        return string(abi.encodePacked(baseURI, _uri));
    }

    function born(address owner, uint256 _id) external onlyMysteryBox {
        _mint(owner, _id, 1, bytes(""));
    }

    function burnPartBatch(address from, uint256[] memory ids) external onlyMysteryBox{
        uint256[] memory amounts = new uint256[](ids.length);
        for(uint i = 0; i < ids.length; i++){
            amounts[i] = 1;
        }
        _burnBatch(from, ids, amounts);
    }

    function mint(address owner, uint256 _id) external onlyManager {
        _mint(owner, _id, 1, bytes(""));
    }

    function addManager(address manager) external onlyOwner {
        managers[manager] = true;
    }

    function removeManager(address manager) external onlyOwner {
        managers[manager] = false;
    }

}

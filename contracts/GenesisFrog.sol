pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "./interfaces/IGeneScience.sol";
import "./interfaces/IVault.sol";

contract GenesisFrog is Ownable, ERC721Burnable, ReentrancyGuard{
    using Strings for uint256;

    mapping(uint256 => uint256) public frogGenes;
    string public baseURI;
    IGeneScience public geneScience;
    address mysteryBox;
    IVault public vault;

    event UpgradeFrog(uint256 indexed tokenId, uint256 genes);

    constructor(
            string memory name_,
            string memory symbol_,
            string memory _baseURI,
            address _geneScience,
            address _mysteryBox) ERC721(name_, symbol_) {
        geneScience = IGeneScience(_geneScience);
        baseURI = _baseURI;
        mysteryBox = _mysteryBox;
    }

    modifier onlyVault() {
        require(address(vault) == _msgSender(), "GenesisFrog: caller is not the vault");
        _;
    }

    modifier onlyMysteryBox() {
        require(mysteryBox == _msgSender(), "GenesisFrog: caller is not the MysteryBox");
        _;
    }

    function setVault(address _vault) external onlyOwner {
        vault = IVault(_vault);
    }


    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "GenesisFrog: nonexistent token");
        string memory uri = geneScience.decodeTokenURI(frogGenes[tokenId]);
        return string(abi.encodePacked(baseURI, uri));
    }

    function born(address owner, uint256 tokenId, uint256 genes) external onlyMysteryBox{
        _mintToken(owner, tokenId, genes);
    }

    function burnFrog(uint256 tokenId) external onlyVault {
        _burn(tokenId);
    }

    function mixPartGenes(address owner, uint256 newTokenId, uint256 tokenId, uint256 partGenes) external onlyMysteryBox returns(uint256) {
        require(owner == ownerOf(tokenId), "GenesisFrog: caller is not owner");

        uint256 genes = frogGenes[tokenId];
        uint256 newGenes = geneScience.mixGenes(genes, partGenes);

        _burn(tokenId);

        _mintToken(owner, newTokenId, newGenes);
        return newGenes;
    }

    function upgradeFrog(uint256 tokenId) external onlyVault {
        uint256 genes = geneScience.genesUpgrade(frogGenes[tokenId]);
        frogGenes[tokenId] = genes;
        emit UpgradeFrog(tokenId, genes);
    }

    function _mintToken(address owner, uint256 tokenId, uint256 genes) private {
        _mint(owner, tokenId);
        frogGenes[tokenId] = genes;
        vault.addFrog(tokenId);
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override{
        super._afterTokenTransfer(from, to, tokenId);

        if(address(0) == from && address(0) != to){
            vault.addFrog(tokenId);
        }
    }

}

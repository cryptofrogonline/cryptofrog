pragma solidity >=0.4.22 <0.9.0;

interface IGenesisFrog {
    function frogGenes(uint256 tokenId) external view returns(uint256);
    function born(address owner, uint256 tokenId, uint256 genes) external;
    function burnFrog(uint256 tokenId) external;
    function upgradeFrog(uint256 tokenId) external;
    function mixPartGenes(address owner, uint256 newTokenId, uint256 tokenId, uint256 partGenes) external returns(uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
}
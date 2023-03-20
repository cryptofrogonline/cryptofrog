pragma solidity >=0.4.22 <0.9.0;

interface IGeneScience {
    function decode(uint256 _genes) external pure returns(uint32[] memory);
    function encode(uint32[] calldata traits) external pure returns (uint256);
    function countPart(uint256 _genes) external pure returns(uint256 count);
    function genesValue(uint256 genes) external view returns(uint256 value);
    function genesMultipleValue(uint256 genes) external view returns(uint256 multipleValue);
    function genesUpgrade(uint256 genes) external pure returns(uint256);
    function encodePacked(
        uint32 talent,
        uint32 body,
        uint32 head,
        uint32 clothes,
        uint32 shoe,
        uint32 hand,
        uint32 value
        ) external pure returns(uint256 _genes);
    function mixGenes(uint256 genes, uint256 partGenes) external view returns(uint256 _genes);
    function valueToAmount(uint256 value) external pure returns(uint256);
    function decodeTokenURI(uint256 genes) external pure returns(string memory);
}
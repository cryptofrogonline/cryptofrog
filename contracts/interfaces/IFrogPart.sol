pragma solidity >=0.4.22 <0.9.0;

interface IFrogPart {
    function born(address owner, uint256 genes) external;
    function burnPartBatch(address from, uint256[] memory ids) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
}
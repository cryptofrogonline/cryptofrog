pragma solidity >=0.4.22 <0.9.0;

interface IVault {
    function deposit(address investor, uint256 amount, address referer) external;
    function addFrog(uint256 tokenId) external;
    function claimByMystery(address owner, uint256 tokenId) external;
}

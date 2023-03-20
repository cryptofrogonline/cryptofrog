pragma solidity >=0.4.22 <0.9.0;


contract MarkingType {

    enum AssetType {ERC721, ERC1155 }

    enum Side { None, Sell, Offer }

    struct BaseOrder {
        address trader;
        Side side;
        address collection;
        uint256 tokenId;
        AssetType assetType;
        address payToken;
        uint256 salt;
    }


    struct Order {
        address trader;
        Side side;
        address collection;
        uint256 tokenId;
        uint256 amount;
        AssetType assetType;
        address payToken;
        uint256 price;
        uint256 expirationTime;
        uint256 salt;
    }

    struct Sig {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
}

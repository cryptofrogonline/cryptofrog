pragma solidity >=0.4.22 <0.9.0;
import "./MarkingType.sol";

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract Marking is Ownable, MarkingType {
    using SafeERC20 for IERC20;
    using SafeMath for uint;


    event Exchange(
        address indexed trader,
        address indexed collection,
        uint256 indexed tokenId,
        uint256 amount,
        address payToken,
        uint256 price,
        uint256 salt,
        uint256 buyAmount,
        address caller
    );

    event Cancel(
        address indexed trader,
        address indexed collection,
        uint256 indexed tokenId,
        uint256 salt
    );

    uint256 public PERCENT_DIVIDER = 10000;
    address constant ETH_ADDRESS = address(0);
    uint256 private constant CANCEL_STATE = 2 ** 256 - 1;

    mapping(bytes32 => uint256) public states;
    address public operator;
    address public signer;

    constructor(
        address _operator,
        address _signer
    ) {
        operator = _operator;
        signer = _signer;
    }

    function setOperate(address _operator) external onlyOwner {
        operator = _operator;
    }

    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    function execute(
        Order calldata order,
        Sig calldata sig,
        uint256 signerFee,
        Sig calldata signerSig,
        uint256 amount
    ) payable external {
        require(order.side > Side.None, "Marking: invalid order side");
        require(order.expirationTime > block.timestamp, "Marking: order expired");
        verifyMessage(order, sig);
        verifySignerMessage(order, signerFee, signerSig);

        verifyMarkingState(order, order.amount, amount);

        if(order.side == Side.Offer){
            require(order.payToken != ETH_ADDRESS, "Marking: ETH is not supported on offer side");
        }
        uint256 totalPrice = order.price.mul(amount).div(order.amount);
        if(order.payToken == ETH_ADDRESS){
            require(msg.value == totalPrice, "Marking: incorrect msg.value");
        }

        _transfer(order, totalPrice, amount, signerFee);

        emit Exchange(
            order.trader,
            order.collection,
            order.tokenId,
            order.amount,
            order.payToken,
            order.price,
            order.salt,
            amount,
            msg.sender
        );
    }

    function verifyMessage(Order memory order, Sig memory sig) private pure {
        bytes32 message = keccak256(abi.encode(order));
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        message = keccak256(abi.encodePacked(prefix, message));
        require(ecrecover(message, sig.v, sig.r, sig.s) == order.trader, "Marking: invalid trader signature");
    }

    function verifySignerMessage(Order memory order, uint fee, Sig memory sig) private view {
        bytes32 message = keccak256(abi.encode(order, fee));
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";
        message = keccak256(abi.encodePacked(prefix, message));
        require(ecrecover(message, sig.v, sig.r, sig.s) == signer, "Marking: invalid signer signature");
    }

    function cancel(BaseOrder calldata baseOrder) external {
        require(baseOrder.trader == msg.sender, "Marking: not an owner");
        require(CANCEL_STATE > getState(baseOrder), "Marking: order has been canceled");
        _setState(baseOrder, CANCEL_STATE);
        emit Cancel(
            baseOrder.trader,
            baseOrder.collection,
            baseOrder.tokenId,
            baseOrder.salt
        );
    }

    function _transfer(Order memory order, uint256 totalPrice, uint256 amount, uint256 signerFee) private {
        uint256 feePrice = _getFeePrice(totalPrice, signerFee);
        uint256 paying = totalPrice.sub(feePrice);
        address assetOwner;
        address payTokenOwner;
        if(order.side == Side.Sell){
            assetOwner = order.trader;
            payTokenOwner = msg.sender;
        }else {
            assetOwner = msg.sender;
            payTokenOwner = order.trader;
        }

        if(feePrice > 0){
            _transferFrom20(payTokenOwner, operator, order.payToken, feePrice);
        }
        _transferFrom20(payTokenOwner, assetOwner, order.payToken, paying);

        if(order.assetType == AssetType.ERC721){
            _transferFrom721(assetOwner, payTokenOwner, order.collection, order.tokenId);
        }else{
            _transferFrom1155(assetOwner, payTokenOwner, order.collection, order.tokenId, amount);
        }
    }

    function verifyMarkingState(Order memory order, uint amount, uint buyAmount) private {
        BaseOrder memory baseOrder = BaseOrder({
            trader: order.trader,
            side: order.side,
            collection: order.collection,
            tokenId: order.tokenId,
            assetType: order.assetType,
            payToken: order.payToken,
            salt: order.salt
        });
        uint256 state = getState(baseOrder);

        state = state.add(buyAmount);
        require(state <= amount, "Marking: not enough stock of amount");
        _setState(baseOrder, state);
    }

    function _getFeePrice(uint256 totalPrice, uint256 signerFee) private view returns(uint256){
        return totalPrice.mul(signerFee).div(PERCENT_DIVIDER);
    }

    function _transferFrom20(address from, address to, address token, uint256 value) private {
        IERC20(token).safeTransferFrom(from, to, value);
    }

    function _transferFrom721(address from, address to, address token, uint256 tokenId) private {
        IERC721(token).safeTransferFrom(from, to, tokenId);
    }

    function _transferFrom1155(address from, address to, address token, uint256 id, uint256 value) private {
        IERC1155(token).safeTransferFrom(from, to, id, value, "");
    }

    function getState(BaseOrder memory key) public view returns (uint256) {
        bytes32 _key = keccak256(abi.encode(key));
        return states[_key];
    }

    function _setState(BaseOrder memory key, uint256 state) private {
        bytes32 _key = keccak256(abi.encode(key));
        states[_key] = state;
    }

    function getStateKey(BaseOrder memory key) public pure returns (bytes32) {
        return keccak256(abi.encode(key));
    }

}

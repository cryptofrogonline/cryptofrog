pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract GeneScience {
    using Strings for uint256;
    using Strings for uint32;
    using SafeMath for uint256;

    uint256 public constant VALUE_MASK = uint256(0x000000000000000000000000000000000000000000000000ffffffff00000000);
    uint256 public constant MULTIPLE_MASK = uint256(0x00000000000000000000000000000000000000000000000000000000ffffffff);
    uint256[] public TRAIT_MULTIPLE = [1000, 13000, 1000, 1500, 1500, 2000, 0, 0];
    uint256 constant PERCENT_DIVIDER = 10000;
    uint256 constant UPGRADE_RATE = 500;
    constructor(){}

    function _sliceNumber(uint256 _n, uint256 _nbits, uint256 _offset) private pure returns (uint256) {
        // mask is made by shifting left an offset number of times
        uint256 mask = uint256((2**_nbits) - 1) << _offset;
        // AND n with mask, and trim to max of _nbits bits
        return uint256((_n & mask) >> _offset);
    }

    function _get32Bits(uint256 _input, uint256 _slot) internal pure returns(uint32) {
        return uint32(_sliceNumber(_input, uint256(32), _slot * 32));
    }

    function decode(uint256 _genes) public pure returns(uint32[] memory) {
        uint32[] memory traits = new uint32[](8);
        uint256 i;
        for(i = 0; i < 8; i++) {
            traits[i] = _get32Bits(_genes, 7 - i);
        }
        return traits;
    }

    /// @dev Given an array of traits return the number that represent genes
    function encode(uint32[] memory _traits) public pure returns (uint256 _genes) {
        _genes = 0;
        for(uint256 i = 0; i < 8; i++) {
            _genes = _genes << 32;
            // bitwise OR trait with _genes;
            _genes = _genes | _traits[i];
        }
        return _genes;
    }

    function countPart(uint256 _genes) public pure returns(uint256 count){
        uint32[] memory traits = decode(_genes);
        count = 0;
        for(uint i = 2; i < traits.length - 2; i++){
            if(traits[i] > 0){
                count = count + 1;
            }
        }
    }

    function genesMultiple(uint256 genes) public pure returns(uint256) {
        return genes & MULTIPLE_MASK;
    }

    function genesValue(uint256 genes) public pure returns(uint256 value) {
        value = genes & VALUE_MASK;
        value = value >> 32;
        value = value;
    }

    function genesMultipleValue(uint256 genes) public pure returns(uint256 multipleValue) {
        multipleValue = genesValue(genes);
        multipleValue = multipleValue.mul(genesMultiple(genes)).div(PERCENT_DIVIDER);
    }

    function genesUpgrade(uint256 genes) public pure returns(uint256){
        uint32[] memory traits = decode(genes);
        uint256 value = (traits[6] * UPGRADE_RATE).div(PERCENT_DIVIDER);
        uint32 value32 = traits[6] + uint32(value);
        traits[6] = value32;
        return encode(traits);
    }


    function _decodeMultiple(uint32[] memory traits) private view returns(uint256 multiple) {
        for(uint i = 0; i < traits.length; i++){
            if(traits[i] > 0){
                multiple = multiple.add(TRAIT_MULTIPLE[i]);
            }
        }
    }

    function encodePacked(
        uint32 talent,
        uint32 body,
        uint32 head,
        uint32 clothes,
        uint32 shoe,
        uint32 hand,
        uint32 value
        ) public view returns(uint256 _genes) {
            uint32[] memory traits = new uint32[](8);
            traits[0] = talent;
            traits[1] = body;
            traits[2] = head;
            traits[3] = clothes;
            traits[4] = shoe;
            traits[5] = hand;
            traits[6] = value * 10000;

            uint256 multiple = _decodeMultiple(traits);
            traits[7] = uint32(multiple);
            return encode(traits);
        }

    function mixGenes(uint256 genes, uint256 partGenes) public view returns(uint256 _genes){
        uint32[] memory traits = decode(genes);
        uint32[] memory partTraits = decode(partGenes);
        for(uint i = 0; i < partTraits.length - 2; i++){
            if(partTraits[i] > 0){
                traits[i] = partTraits[i];
            }
        }
        uint256 multiple = _decodeMultiple(traits);
        traits[7] = uint32(multiple);
        _genes = encode(traits);
    }

    function decodeTokenURI(uint256 genes) public pure returns(string memory) {
        uint32[] memory traits = decode(genes);
        string memory uri = traits[0].toString();
        for(uint32 i=1; i<6; i++) {
            uri = string(abi.encodePacked(uri, "_", traits[i].toString()));
        }
        return uri;
    }

    function decimalsValue(uint256 value) public pure returns(uint256) {
        return value * 10 ** 18;
    }

    function valueToAmount(uint256 value) public pure returns(uint256) {
        return (value * 10 ** 18).div(PERCENT_DIVIDER);
    }
}

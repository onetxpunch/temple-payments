// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


import "@openzeppelin/contracts/access/Ownable.sol";
import "./TempleTeamPayments.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MerkleProofTempleTeamPayments is Ownable {

    IERC20 public immutable TEMPLE;

    mapping(address => uint256) public allocation;
    mapping(address => uint256) public claimed;
    // event Claimed(address indexed member, uint256 amount);
    bytes32[] hashes;
    // bytes32[] claimedHashes;
    mapping(bytes32 => bool) claimedHashes;
    mapping(bytes32 => bool) pausedHashes;

    // uint256 public immutable roundStartDate;
    // uint256 public immutable roundEndDate;
    constructor(IERC20 temple, uint256 paymentPeriodInSeconds, uint256 startTimestamp) TempleTeamPayments(temple, paymentPeriodInSeconds, startTimestamp) {
        // owner = msg.sender;
        // hashes = _hashes;
    }

    // function proofClaim(bytes32 _senderProof) external {
    //     require(!claimedHashes[_senderProof] && !pausedHashes[_senderProof]);


    
    //     claimedHashes[_senderProof] = true;
        
    // } 

    // function getRoot() public view returns (bytes32) {
    //     return hashes[hashes.length - 1];
    // }

    function setAllocations(
        address[] memory _addresses,
        uint256[] memory _amounts
    ) external onlyOwner {
        require(
            _addresses.length == _amounts.length,
            "TempleTeamPayments: addresses and amounts must be the same length"
        );
        address addressZero = address(0);
        for (uint256 i = 0; i < _addresses.length; i++) {
            require(_addresses[i] != addressZero, "TempleTeamPayments: Address cannot be 0x0");
            allocation[_addresses[i]] = _amounts[i];
        }
    }

    function setAllocation(address _address, uint256 _amount) external onlyOwner {
        require(_address != address(0), "TempleTeamPayments: Address cannot be 0x0");
        allocation[_address] = _amount;
    }

    function withdrawToken(IERC20 _token, uint256 _amount)
        external
        onlyOwner
    {
        require(_amount > 0, "TempleTeamPayments: Amount must be greater than 0");
        SafeERC20.safeTransfer(_token, owner, _amount);
    }

        function toggleCanClaim(bytes32 _senderProof)
        external
        onlyOwner
    {
        pausedHashes[_senderProof] = !pausedHashes[_senderProof];
    }


}

contract TempleTeamPaymentsFactory is Ownable {

    struct FundingData {
        address paymentContract;
        uint256 totalFunding;
        uint256 epoch;
    }
    mapping (uint256 => FundingData) roundsFunded;

    function deploy(IERC20 temple, uint256 epoch, bytes32[] calldata hashes, uint256 totalFunding, uint256 paymentPeriodInSeconds, uint256 startTimestamp) external onlyOwner {

        TempleTeamPayments payment =  new MerkleProofTempleTeamPayments(temple, paymentPeriodInSeconds, startTimestamp);
        
        // fundingToken must be approved by caller. 
        // the paymentContract can be topped up by sending tokens directly to it
        temple.transferFrom(msg.sender, address(payment), totalFunding);

        roundsFunded[epoch] = FundingData({
            paymentContract: address(payment),
            totalFunding: totalFunding,
            epoch: epoch
        });
    }

    function withdrawToken(IERC20 _token, uint256 _amount)
        external
        onlyOwner
    {
        require(_amount > 0, "TempleTeamPayments: Amount must be greater than 0");
        SafeERC20.safeTransfer(_token, owner, _amount);
    }
}
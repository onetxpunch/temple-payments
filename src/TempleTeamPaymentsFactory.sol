// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./TempleTeamPaymentsV2.sol";

contract TempleTeamPaymentsFactory is Ownable {
    struct FundingData {
        address paymentContract;
        uint256 totalFunding;
        uint16 epoch;
    }

    address public templeTeamPaymentsImplementation;
    uint16 public initialEpoch;
    uint16 public lastPaidEpoch;
    mapping(uint256 => FundingData) public epochsFunded;

    event FundingPaid(
        address paymentToken,
        uint256 indexed fundingRound,
        address[] indexed dests,
        uint256[] indexed amounts
    );
    event FundingDeployed(
        address paymentToken,
        uint256 indexed fundingRound,
        address[] indexed dests,
        uint256[] indexed amounts,
        address deployedTo
    );

    constructor(uint16 _lastPaidEpoch) {
        templeTeamPaymentsImplementation = address(new TempleTeamPaymentsV2());
        lastPaidEpoch = _lastPaidEpoch;
        initialEpoch = _lastPaidEpoch + 1;
    }

    function incrementEpoch(
        address _paymentContract,
        uint256 _totalFunding
    ) internal {
        lastPaidEpoch++;
        epochsFunded[lastPaidEpoch] = FundingData({
            paymentContract: address(_paymentContract),
            totalFunding: _totalFunding,
            epoch: lastPaidEpoch
        });
    }

    function withdrawToken(IERC20 _token, uint256 _amount) external onlyOwner {
        if (_amount == 0) revert ClaimZeroValue();
        SafeERC20.safeTransfer(_token, msg.sender, _amount);
    }

    /**
     * @dev Deploys a new TempleTeamPayments contract, setAllocations to _dests and _allocations, funded with _totalFunding as _temple tokens, available to claim at _startTimestamp
     * @param _temple the token to distribute
     * @param _dests the recipient of the tokens
     * @param _allocations the recipients respective amounts
     * @param _totalFunding the total funding to supply the contract with initially
     * @param _startTimestamp the time when recipients can make a claim
     */
    function deployPayouts(
        IERC20 _temple,
        address[] calldata _dests,
        uint256[] calldata _allocations,
        uint256 _totalFunding,
        uint40 _startTimestamp
    ) external onlyOwner returns (TempleTeamPaymentsV2) {
        bytes32 salt = keccak256(abi.encodePacked(_temple, lastPaidEpoch + 1));
        TempleTeamPaymentsV2 paymentContract = TempleTeamPaymentsV2(
            Clones.cloneDeterministic(templeTeamPaymentsImplementation, salt)
        );
        paymentContract.initialize(_temple);
        paymentContract.setClaimOpenTimestamp(_startTimestamp);
        paymentContract.setAllocations(_dests, _allocations);

        paymentContract.transferOwnership(msg.sender);

        if (_totalFunding > 0)
            SafeERC20.safeTransferFrom(
                _temple,
                msg.sender,
                address(paymentContract),
                _totalFunding
            );

        incrementEpoch(address(paymentContract), _totalFunding);

        emit FundingDeployed(
            address(_temple),
            lastPaidEpoch,
            _dests,
            _allocations,
            address(paymentContract)
        );

        return paymentContract;
    }

    /**
     * @dev Directly transfers _temple tokens to _dests and _allocations
     * @param _temple the token to distribute
     * @param _dests the recipient of the tokens
     * @param _allocations the recipients respective amounts
     */
    function directPayouts(
        IERC20 _temple,
        address[] calldata _dests,
        uint256[] calldata _allocations
    ) external onlyOwner {
        if (_dests.length != _allocations.length)
            revert AllocationsLengthMismatch();

        uint256 totalFunding;
        for (uint256 i; i < _dests.length; ) {
            address dest = _dests[i];
            if (dest == address(0)) revert AllocationAddressZero();
            uint256 value = _allocations[i];
            if (value < 0) revert ClaimZeroValue();
            SafeERC20.safeTransferFrom(_temple, msg.sender, _dests[i], value);
            totalFunding += value;
            unchecked {
                i++;
            }
        }

        incrementEpoch(address(this), totalFunding);

        emit FundingPaid(address(_temple), lastPaidEpoch, _dests, _allocations);
    }
}

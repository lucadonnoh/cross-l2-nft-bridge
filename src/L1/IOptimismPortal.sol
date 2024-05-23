// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IOptimismPortal {
    struct OutputRootProof {
        bytes32 version;
        bytes32 stateRoot;
        bytes32 messagePasserStorageRoot;
        bytes32 latestBlockhash;
    }

    struct WithdrawalTransaction {
        uint256 nonce;
        address sender;
        address target;
        uint256 value;
        uint256 gasLimit;
        bytes data;
    }

    event Initialized(uint8 version);
    event TransactionDeposited(address indexed from, address indexed to, uint256 indexed version, bytes opaqueData);
    event WithdrawalFinalized(bytes32 indexed withdrawalHash, bool success);
    event WithdrawalProven(bytes32 indexed withdrawalHash, address indexed from, address indexed to);

    receive() external payable;

    function GUARDIAN() external view returns (address);
    function L2_ORACLE() external view returns (address);
    function SYSTEM_CONFIG() external view returns (address);
    function depositTransaction(address _to, uint256 _value, uint64 _gasLimit, bool _isCreation, bytes memory _data)
        external
        payable;
    function donateETH() external payable;
    function finalizeWithdrawalTransaction(WithdrawalTransaction memory _tx) external;
    function finalizedWithdrawals(bytes32) external view returns (bool);
    function guardian() external view returns (address);
    function initialize(address _l2Oracle, address _systemConfig, address _superchainConfig) external;
    function isOutputFinalized(uint256 _l2OutputIndex) external view returns (bool);
    function l2Oracle() external view returns (address);
    function l2Sender() external view returns (address);
    function minimumGasLimit(uint64 _byteCount) external pure returns (uint64);
    function params() external view returns (uint128 prevBaseFee, uint64 prevBoughtGas, uint64 prevBlockNum);
    function paused() external view returns (bool paused_);
    function proveWithdrawalTransaction(
        WithdrawalTransaction memory _tx,
        uint256 _l2OutputIndex,
        OutputRootProof memory _outputRootProof,
        bytes[] memory _withdrawalProof
    ) external;
    function provenWithdrawals(bytes32)
        external
        view
        returns (bytes32 outputRoot, uint128 timestamp, uint128 l2OutputIndex);
    function superchainConfig() external view returns (address);
    function systemConfig() external view returns (address);
    function version() external view returns (string memory);
}

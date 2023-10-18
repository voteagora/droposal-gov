// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

struct Payee {
    address account;
    uint32 shares;
    bool transfersAllowedWhileLocked;
}

/**
 * @param payees Addresses and shares of the initial payees
 * @param minimumShares Amount of shares that gives an account access to restricted
 * @param currencies Array of tokens accepted by the slicer
 * @param releaseTimelock The timestamp when the slicer becomes releasable
 * @param transferTimelock The timestamp when the slicer becomes transferable
 * @param controller The address of the slicer controller
 * @param slicerFlags See `_flags` in {Slicer}
 * @param sliceCoreFlags See `flags` in {SlicerParams} struct
 */
struct SliceParams {
    Payee[] payees;
    uint256 minimumShares;
    address[] currencies;
    uint256 releaseTimelock;
    uint40 transferTimelock;
    address controller;
    uint8 slicerFlags;
    uint8 sliceCoreFlags;
}

interface ISliceCore {
    function slice(SliceParams calldata params) external;

    function supply() external view returns (uint256);

    function slicers(uint256 id) external view returns (address);
}

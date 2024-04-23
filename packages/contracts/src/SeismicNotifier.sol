// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract SeismicNotifier {

    mapping(address => bool) extensionContracts;

    event NewExtensionsContract(address indexed contractAddress);

    // TODO: Add a way to remove an extension contract
    function notify(address contractAddress) public {
        extensionContracts[msg.sender] = true;
        emit NewExtensionsContract(contractAddress);
    }
}

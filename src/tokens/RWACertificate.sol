// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title RWACertificate — ERC-721 NFT representing legal ownership of a real-world asset
/// @dev Full implementation to be added by team contributor
contract RWACertificate is ERC721, AccessControl {
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    uint256 private _tokenIdCounter;

    struct CertificateData {
        string assetId;
        uint256 faceValue;
        uint64 issuedAt;
        uint64 expiresAt;
        bool active;
    }

    mapping(uint256 => CertificateData) public certificates;

    event CertificateIssued(uint256 indexed tokenId, address indexed to, string assetId, uint256 faceValue);
    event CertificateRevoked(uint256 indexed tokenId, string reason);

    constructor(address admin) ERC721("RWA Certificate", "RWACERT") {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ISSUER_ROLE, admin);
    }

    function issueCertificate(
        address to,
        string calldata assetId,
        uint256 faceValue,
        uint64 expiresAt,
        string calldata tokenURI_
    ) external onlyRole(ISSUER_ROLE) returns (uint256 tokenId) {
        tokenId = _tokenIdCounter++;
        certificates[tokenId] = CertificateData(assetId, faceValue, uint64(block.timestamp), expiresAt, true);
        _safeMint(to, tokenId);
        emit CertificateIssued(tokenId, to, assetId, faceValue);
    }

    function revokeCertificate(uint256 tokenId, string calldata reason) external onlyRole(ISSUER_ROLE) {
        require(_ownerOf(tokenId) != address(0), "Token does not exist");
        certificates[tokenId].active = false;
        emit CertificateRevoked(tokenId, reason);
    }

    function isValid(uint256 tokenId) external view returns (bool) {
        CertificateData memory cert = certificates[tokenId];
        if (!cert.active) return false;
        if (cert.expiresAt != 0 && block.timestamp > cert.expiresAt) return false;
        return true;
    }

    function supportsInterface(bytes4 interfaceId)
        public view override(ERC721, AccessControl) returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

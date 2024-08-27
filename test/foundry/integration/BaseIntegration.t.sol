// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// External imports
import { IERC6551Registry } from "erc6551/interfaces/IERC6551Registry.sol";
import { ERC6551AccountLib } from "erc6551/lib/ERC6551AccountLib.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

// Internal imports
import { IIPAccountRegistry } from "contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IIPAssetRegistry } from "contracts/interfaces/registries/IIPAssetRegistry.sol";

// Test imports
import { MockERC721 } from "test/foundry/mocks/token/MockERC721.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";

contract BaseIntegration is BaseTest {
    using Strings for *;

    function setUp() public virtual override(BaseTest) {
        super.setUp();
        dealMockAssets();

        vm.prank(u.admin);
        royaltyModule.setSnapshotInterval(7 days);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    /**
     * @notice Registers an IP account and emits relevant events.
     * @param nft Address of the NFT contract
     * @param tokenId Token ID of the NFT
     * @param owner Address of the owner
     * @return Address of the registered IP account
     */
    function registerIpAccount(address nft, uint256 tokenId, address owner) 
        internal 
        returns (address) 
    {
        address expectedAddr = ERC6551AccountLib.computeAddress(
            address(erc6551Registry),
            address(ipAccountImpl),
            ipAccountRegistry.IP_ACCOUNT_SALT(),
            block.chainid,
            nft,
            tokenId
        );

        // Label the expected address for easier debugging
        vm.label(expectedAddr, string(abi.encodePacked("IPAccount", tokenId.toString())));

        // Emit events to track the account creation and registration
        emitAccountEvents(expectedAddr, nft, tokenId);

        // Register the IP account under the caller's address
        vm.startPrank(owner);
        return ipAssetRegistry.register(block.chainid, nft, tokenId);
    }

    /**
     * @notice Registers an IP account for a MockERC721 token.
     * @param nft MockERC721 contract instance
     * @param tokenId Token ID of the NFT
     * @param caller Address of the caller
     * @return Address of the registered IP account
     */
    function registerIpAccount(MockERC721 nft, uint256 tokenId, address caller) 
        internal 
        returns (address) 
    {
        return registerIpAccount(address(nft), tokenId, caller);
    }

    /**
     * @notice Registers a derivative work with associated license tokens.
     * @param ipId ID of the IP to register the derivative with
     * @param licenseTokenIds Array of license token IDs
     * @param royaltyContext Additional data for royalty processing
     * @param caller Address of the caller
     */
    function registerDerivativeWithLicenseTokens(
        address ipId,
        uint256[] memory licenseTokenIds,
        bytes memory royaltyContext,
        address caller
    ) internal {
        vm.startPrank(caller);
        licensingModule.registerDerivativeWithLicenseTokens(ipId, licenseTokenIds, royaltyContext);
        vm.stopPrank();
    }

    /**
     * @notice Emits relevant events for IP account creation and registration.
     * @param account Address of the IP account
     * @param nft Address of the NFT contract
     * @param tokenId Token ID of the NFT
     */
    function emitAccountEvents(address account, address nft, uint256 tokenId) internal {
        vm.expectEmit();
        emit IERC6551Registry.ERC6551AccountCreated({
            account: account,
            implementation: address(ipAccountImpl),
            salt: ipAccountRegistry.IP_ACCOUNT_SALT(),
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId
        });

        vm.expectEmit();
        emit IIPAccountRegistry.IPAccountRegistered({
            account: account,
            implementation: address(ipAccountImpl),
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId
        });

        vm.expectEmit();
        emit IIPAssetRegistry.IPRegistered({
            ipId: account,
            chainId: block.chainid,
            tokenContract: nft,
            tokenId: tokenId,
            name: string.concat(block.chainid.toString(), ": Ape #", tokenId.toString()),
            uri: string.concat("https://storyprotocol.xyz/erc721/", tokenId.toString()),
            registrationDate: block.timestamp
        });
    }
}

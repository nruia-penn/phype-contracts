// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {PHYPE} from "../src/PHYPE.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {RoleRegistry} from "../src/RoleRegistry.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract PHYPETest is Test {
    RoleRegistry roleRegistry;
    /// forge-lint: disable-next-line(mixed-case-variable)
    PHYPE public pHYPE;

    address public owner = makeAddr("owner");
    address public manager = makeAddr("manager");
    address public operator = makeAddr("operator");

    function setUp() public {
        RoleRegistry roleRegistryImplementation = new RoleRegistry();
        bytes memory roleRegistryInitData = abi.encodeWithSelector(RoleRegistry.initialize.selector, owner);
        ERC1967Proxy roleRegistryProxy = new ERC1967Proxy(address(roleRegistryImplementation), roleRegistryInitData);
        roleRegistry = RoleRegistry(address(roleRegistryProxy));

        PHYPE implementation = new PHYPE();
        bytes memory initData = abi.encodeWithSelector(PHYPE.initialize.selector, address(roleRegistryProxy));
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        pHYPE = PHYPE(address(proxy));

        // Grant MANAGER_ROLE to manager
        vm.startPrank(owner);
        roleRegistry.grantRole(roleRegistry.MANAGER_ROLE(), manager);
        vm.stopPrank();
        
        // Verify the role was granted
        assertTrue(roleRegistry.hasRole(roleRegistry.MANAGER_ROLE(), manager));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Tests: Mint                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function test_Mint_OnlyManager(address user, uint256 amount) public {
        vm.assume(user != address(0));
        vm.assume(amount > 0);

        vm.prank(manager);
        pHYPE.mint(user, amount);
        assertEq(pHYPE.balanceOf(user), amount);
        assertEq(pHYPE.totalSupply(), amount);
    }

    function test_Mint_NotManager(address notManager, uint256 amount) public {
        vm.assume(notManager != manager);
        vm.assume(notManager != address(0));
        vm.assume(amount > 0);

        vm.startPrank(notManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, notManager, roleRegistry.MANAGER_ROLE()
            )
        );
        pHYPE.mint(notManager, amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Tests: Burn                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function test_Burn_OnlyManager(uint256 amount, uint256 burnAmount) public {
        vm.assume(amount > 0);
        vm.assume(amount > burnAmount);
        vm.assume(burnAmount > 0);

        vm.prank(manager);
        pHYPE.mint(manager, amount);

        vm.prank(manager);
        pHYPE.burn(burnAmount);

        assertEq(pHYPE.balanceOf(manager), amount - burnAmount);
        assertEq(pHYPE.totalSupply(), amount - burnAmount);
    }

    function test_Burn_NotManager(address notManager, uint256 amount, uint256 burnAmount) public {
        vm.assume(notManager != manager);
        vm.assume(notManager != address(0));
        vm.assume(amount > 0);
        vm.assume(amount > burnAmount);
        vm.assume(burnAmount > 0);

        vm.prank(manager);
        pHYPE.mint(notManager, amount);

        vm.startPrank(notManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, notManager, roleRegistry.MANAGER_ROLE()
            )
        );
        pHYPE.burn(burnAmount);
    }

    function test_Burn_CannotBurnMoreThanBalance(uint256 amount, uint256 burnAmount) public {
        vm.assume(amount > 0);
        vm.assume(burnAmount > amount);

        vm.prank(manager);
        pHYPE.mint(manager, amount);

        vm.prank(manager);
        vm.expectRevert();
        pHYPE.burn(burnAmount);
    }

    function test_Burn_WhenPaused() public {
        uint256 amount = 1000e18;
        uint256 burnAmount = 500e18;

        vm.prank(manager);
        pHYPE.mint(manager, amount);

        // Pause the contract
        vm.prank(owner);
        roleRegistry.pause(address(pHYPE));

        vm.prank(manager);
        vm.expectRevert();
        pHYPE.burn(burnAmount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    Tests: Burn From                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function test_BurnFrom_OnlyManager(address user, uint256 amount, uint256 burnAmount) public {
        vm.assume(user != address(0));
        vm.assume(user != manager);
        vm.assume(amount > 0);
        vm.assume(amount >= burnAmount);
        vm.assume(burnAmount > 0);
        vm.assume(burnAmount < type(uint256).max); // Exclude max uint256 to avoid infinite approval behavior

        vm.prank(manager);
        pHYPE.mint(user, amount);

        vm.prank(user);
        pHYPE.approve(manager, burnAmount);

        vm.prank(manager);
        pHYPE.burnFrom(user, burnAmount);

        assertEq(pHYPE.balanceOf(user), amount - burnAmount);
        assertEq(pHYPE.totalSupply(), amount - burnAmount);
        assertEq(pHYPE.allowance(user, manager), 0);
    }

    function test_BurnFrom_NotManager(address notManager, address user, uint256 amount, uint256 burnAmount) public {
        vm.assume(notManager != manager);
        vm.assume(notManager != address(0));
        vm.assume(user != address(0));
        vm.assume(user != notManager);
        vm.assume(user != manager);
        vm.assume(amount > 0);
        vm.assume(burnAmount > 0);
        vm.assume(amount >= burnAmount);

        vm.prank(manager);
        pHYPE.mint(user, amount);

        vm.prank(user);
        pHYPE.approve(notManager, burnAmount);

        vm.startPrank(notManager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, notManager, roleRegistry.MANAGER_ROLE()
            )
        );
        pHYPE.burnFrom(user, burnAmount);
    }

    function test_BurnFrom_InsufficientAllowance(address user, uint256 amount, uint256 burnAmount) public {
        vm.assume(user != address(0));
        vm.assume(user != manager);
        vm.assume(amount > 0);
        vm.assume(burnAmount > 1);
        vm.assume(amount >= burnAmount);

        uint256 approval = burnAmount - 1;

        vm.prank(manager);
        pHYPE.mint(user, amount);

        vm.prank(user);
        pHYPE.approve(manager, approval);

        vm.prank(manager);
        vm.expectRevert();
        pHYPE.burnFrom(user, burnAmount);
    }

    function test_BurnFrom_WhenPaused() public {
        address user = makeAddr("user");
        uint256 amount = 1000e18;
        uint256 burnAmount = 500e18;

        vm.prank(manager);
        pHYPE.mint(user, amount);

        vm.prank(user);
        pHYPE.approve(manager, burnAmount);

        // Pause the contract
        vm.prank(owner);
        roleRegistry.pause(address(pHYPE));

        vm.prank(manager);
        vm.expectRevert();
        pHYPE.burnFrom(user, burnAmount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       Tests: Transfer                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function test_Transfer(uint256 amount, uint256 transferAmount) public {
        vm.assume(amount > 0);
        vm.assume(amount > transferAmount);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        vm.prank(manager);
        pHYPE.mint(user1, amount);

        vm.prank(user1);
        /// forge-lint: disable-next-line(erc20-unchecked-transfer)
        pHYPE.transfer(user2, transferAmount);

        assertEq(pHYPE.balanceOf(user1), amount - transferAmount);
        assertEq(pHYPE.balanceOf(user2), transferAmount);
    }

    function test_ApproveAndTransferFrom(uint256 amount, uint256 transferAmount) public {
        vm.assume(amount > 0);
        vm.assume(amount > transferAmount);

        address user1 = makeAddr("user1");
        address user2 = makeAddr("user2");

        vm.prank(manager);
        pHYPE.mint(user1, amount);

        vm.prank(user1);
        pHYPE.approve(user2, transferAmount);

        vm.prank(user2);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        pHYPE.transferFrom(user1, user2, transferAmount);

        assertEq(pHYPE.balanceOf(user1), amount - transferAmount);
        assertEq(pHYPE.balanceOf(user2), transferAmount);
        assertEq(pHYPE.allowance(user1, user2), 0);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 Tests: Upgradeability                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/
    function test_UpgradeToAndCall_OnlyOwner() public {
        PHYPEWithExtraFunction newImplementation = new PHYPEWithExtraFunction();

        vm.prank(owner);
        pHYPE.upgradeToAndCall(address(newImplementation), "");

        // Verify upgrade preserved state
        assertEq(address(pHYPE.roleRegistry()), address(roleRegistry));

        // Check that the extra function is available
        PHYPEWithExtraFunction newProxy = PHYPEWithExtraFunction(payable(address(pHYPE)));
        assertTrue(newProxy.extraFunction());
    }

    function test_UpgradeToAndCall_NotOwner(address notOwner) public {
        vm.assume(notOwner != owner);

        PHYPEWithExtraFunction newImplementation = new PHYPEWithExtraFunction();

        vm.prank(notOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, notOwner));
        pHYPE.upgradeToAndCall(address(newImplementation), "");

        // Check that the extra function is not available
        PHYPEWithExtraFunction newProxy = PHYPEWithExtraFunction(payable(address(pHYPE)));
        vm.expectRevert();
        newProxy.extraFunction();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     Tests: Ownership                       */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function test_TransferOwnership_NewOwnerCanUpgrade() public {
        address originalOwner = owner;
        address newOwner = makeAddr("newOwner");

        // Transfer ownership using 2-step process
        vm.prank(originalOwner);
        roleRegistry.transferOwnership(newOwner);

        vm.prank(newOwner);
        roleRegistry.acceptOwnership();

        // Verify ownership has been transferred
        assertEq(roleRegistry.owner(), newOwner);

        // New owner upgrades the contract
        PHYPEWithExtraFunction newImplementation = new PHYPEWithExtraFunction();
        vm.prank(newOwner);
        pHYPE.upgradeToAndCall(address(newImplementation), "");

        // Verify upgrade preserved state
        assertEq(address(pHYPE.roleRegistry()), address(roleRegistry));

        // Check that the extra function is available
        PHYPEWithExtraFunction newProxy = PHYPEWithExtraFunction(payable(address(pHYPE)));
        assertTrue(newProxy.extraFunction());

        // Verify that the old owner can no longer upgrade
        PHYPEWithExtraFunction anotherImplementation = new PHYPEWithExtraFunction();
        vm.prank(originalOwner);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, originalOwner));
        pHYPE.upgradeToAndCall(address(anotherImplementation), "");
    }
}

contract PHYPEWithExtraFunction is PHYPE {
    function extraFunction() public pure returns (bool) {
        return true;
    }
}


// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/FlashLoanArb.sol";
import "../contracts/mocks/MockToken.sol";
import "../contracts/mocks/MockPool.sol";

contract FlashLoanArbTest is Test {
    FlashloanArb public bot;
    MockToken public usdc;
    MockToken public weth;
    MockPool public mockPoolLogic; 

    address public user = address(1);
    address public calculatedPoolAddress;
    address public factory = address(0x1234567890123456789012345678901234567890); 

    
    function setUp() public {
        vm.startPrank(user);
        usdc = new MockToken("USDC", "USDC");
        weth = new MockToken("WETH", "WETH");
        vm.stopPrank();

        calculatedPoolAddress = _computePoolAddress(
            factory,
            address(usdc),
            address(weth),
            3000
        );

        mockPoolLogic = new MockPool(address(usdc), address(weth));

        vm.etch(calculatedPoolAddress, address(mockPoolLogic).code);

        (address token0, address token1) = address(usdc) < address(weth) 
            ? (address(usdc), address(weth)) 
            : (address(weth), address(usdc));
            
        vm.store(calculatedPoolAddress, bytes32(uint256(0)), bytes32(uint256(uint160(token0))));
        vm.store(calculatedPoolAddress, bytes32(uint256(1)), bytes32(uint256(uint160(token1))));
        vm.store(calculatedPoolAddress, bytes32(uint256(2)), bytes32(uint256(3000))); 

        vm.startPrank(user);
        usdc.mint(calculatedPoolAddress, 10_000_000 * 1e18);
        weth.mint(calculatedPoolAddress, 10_000_000 * 1e18);
        vm.stopPrank();

        vm.startPrank(user);
        bot = new FlashloanArb(factory, calculatedPoolAddress);
        vm.stopPrank();
    }
    function test_FlashLoanExecution() public {
        uint256 borrowAmount = 1000 * 1e18;
        
        address[] memory path = new address[](3);
        path[0] = address(usdc);
        path[1] = address(weth);
        path[2] = address(usdc); 

        vm.prank(user);
        bot.requestFlashLoan(calculatedPoolAddress, borrowAmount, 0, path);
    }

    function testFuzz_FlashLoan(uint256 amount) public {
        vm.assume(amount > 1000 && amount < 5_000_000 * 1e18);

        address[] memory path = new address[](3);
        path[0] = address(usdc);
        path[1] = address(weth);
        path[2] = address(usdc); 

        vm.prank(user);
        bot.requestFlashLoan(calculatedPoolAddress, amount, 0, path);
        
    }

    function _computePoolAddress(
        address _factory,
        address _token0,
        address _token1,
        uint24 _fee
    ) internal pure returns (address pool) {
        (address tokenA, address tokenB) = _token0 < _token1 ? (_token0, _token1) : (_token1, _token0);
        pool = address(
            uint160(
                uint256(
                    keccak256(
                        abi.encodePacked(
                            hex'ff',
                            _factory,
                            keccak256(abi.encode(tokenA, tokenB, _fee)),
                            bytes32(0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54)
                        )
                    )
                )
            )
        );
    }
}
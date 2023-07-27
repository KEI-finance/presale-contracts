// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "forge-std/Test.sol";

import "contracts/PreSale.sol";

import "../mocks/TestERC20.sol";
import "../mocks/MockV3Aggregator.sol";

import "forge-std/console.sol";

contract PresaleTest is Test {
    Presale internal presale;

    uint256 internal immutable PRECISION;
    uint256 internal immutable USD_PRECISION;
    uint256 internal immutable USDC_SCALE;

    address payable internal GLOBAL_ADMIN;

    address internal ALICE;
    address internal BOB;

    address payable internal withdrawTo;

    uint48 internal startDate;
    uint48 internal endDate;

    uint8 internal totalRounds;

    TestERC20 internal USDC;
    TestERC20 internal DAI;
    MockV3Aggregator internal ORACLE;
    IPresale.PresaleConfig internal config;
    IPresale.RoundConfig[] internal rounds;

    uint256[] internal tokenPrices;
    uint256[] internal tokensAllocated;

    constructor() {
        PRECISION = 1e8;
        USD_PRECISION = 1e18;
        USDC_SCALE = 1e12;

        GLOBAL_ADMIN = payable(makeAddr("GLOBAL_ADMIN"));
        vm.label(GLOBAL_ADMIN, "GLOBAL_ADMIN");

        ALICE = makeAddr("ALICE");
        vm.label(ALICE, "ALICE");

        BOB = makeAddr("BOB");
        vm.label(BOB, "BOB");

        withdrawTo = GLOBAL_ADMIN;

        startDate = 1 days;
        endDate = 10 days;

        totalRounds = 7;

        USDC = new TestERC20("USDC", "USDC");
        DAI = new TestERC20("DAI", "DAI");
        ORACLE = new MockV3Aggregator(8, int256(2000 * PRECISION));

        USDC.setDecimals(6);

        vm.deal(ALICE, 1_000 ether);
        vm.deal(BOB, 1_000 ether);
        vm.deal(GLOBAL_ADMIN, 1_000 ether);

        USDC.mint(ALICE, 100_000 * 10 ** 6);
        USDC.mint(BOB, 100_000 * 10 ** 6);

        DAI.mint(ALICE, 100_000 ether);
        DAI.mint(BOB, 100_000 ether);

        config = IPresale.PresaleConfig({
            minDepositAmount: 1 ether,
            maxUserAllocation: uint128(70_000 * PRECISION),
            startDate: startDate,
            endDate: endDate,
            withdrawTo: withdrawTo
        });

        tokenPrices = [
            70000000000000000,
            70000000000000000,
            80000000000000000,
            80000000000000000,
            90000000000000000,
            90000000000000000,
            100000000000000000
        ];

        for (uint256 i; i < totalRounds; ++i) {
            tokensAllocated.push(10_000 * PRECISION);

            IPresale.RoundConfig memory _round =
                IPresale.RoundConfig({tokenPrice: tokenPrices[i], tokensAllocated: tokensAllocated[i]});

            rounds.push(_round);
        }

        vm.startPrank(GLOBAL_ADMIN);
        presale = new Presale(address(ORACLE), address(USDC), address(DAI), config);
        presale.setConfig(config);
        presale.setRounds(rounds);
        vm.stopPrank();

        vm.startPrank(ALICE);
        USDC.approve(address(presale), type(uint256).max);
        DAI.approve(address(presale), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(BOB);
        USDC.approve(address(presale), type(uint256).max);
        DAI.approve(address(presale), type(uint256).max);
        vm.stopPrank();
    }

    modifier assertEvent() {
        vm.expectEmit(true, true, true, true);
        _;
    }
}

contract PresaleTest_currentRoundIndex is PresaleTest {
    function test_success() external {
        vm.warp(startDate + 1);

        vm.prank(ALICE);
        presale.purchaseUSDC(701 * 1e6);

        assertEq(presale.currentRoundIndex(), 1);

        vm.prank(BOB);
        presale.purchaseDAI(700 * 1e18);

        assertEq(presale.currentRoundIndex(), 2);
    }
}

contract PresaleTest_config is PresaleTest {
    function test_success() external {
        IPresale.PresaleConfig memory _config = presale.config();

        assertEq(_config.minDepositAmount, config.minDepositAmount);
        assertEq(_config.maxUserAllocation, config.maxUserAllocation);
        assertEq(_config.startDate, config.startDate);
        assertEq(_config.endDate, config.endDate);
        assertEq(_config.withdrawTo, config.withdrawTo);
    }
}

contract PresaleTest_round is PresaleTest {
    function test_success() external {
        for (uint256 i; i < totalRounds; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);

            assertEq(_round.tokenPrice, tokenPrices[i]);
            assertEq(_round.tokensAllocated, tokensAllocated[i]);
        }
    }
}

contract PresaleTest_rounds is PresaleTest {
    function test_success() external {
        IPresale.RoundConfig[] memory _rounds = presale.rounds();

        for (uint256 i; i < totalRounds; ++i) {
            assertEq(_rounds[i].tokenPrice, rounds[i].tokenPrice);
            assertEq(_rounds[i].tokensAllocated, rounds[i].tokensAllocated);
        }
    }
}

contract PresaleTest_totalRounds is PresaleTest {
    function test_success() external {
        assertEq(presale.totalRounds(), totalRounds);
    }
}

contract PresaleTest_roundAllocated is PresaleTest {
    uint256 private _availableToPurchaseUSD;

    function setUp() public {
        IPresale.RoundConfig memory _round = rounds[0];

        _availableToPurchaseUSD = _round.tokenPrice * _round.tokensAllocated / 1e26;

        vm.warp(startDate + 1);

        vm.prank(ALICE);
        presale.purchaseUSDC(_availableToPurchaseUSD * 1e6);
    }

    function test_success() external {
        assertEq(presale.roundAllocated(0), tokensAllocated[0]);
    }
}

contract PresaleTest_totalRaisedUSD is PresaleTest {
    uint256 private _totalCostUSD;
    uint256[] private _purchaseAmountsUSD;

    function setUp() public {
        vm.warp(startDate + 1);

        _purchaseAmountsUSD = [700, 700, 800, 100];

        for (uint256 i; i < _purchaseAmountsUSD.length; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);
            uint256 _roundAllocation = _purchaseAmountsUSD[i] * (USD_PRECISION * PRECISION) / _round.tokenPrice;
            uint256 _tokenCostUSD = _roundAllocation * _round.tokenPrice / PRECISION;
            _totalCostUSD += _tokenCostUSD;
        }

        vm.prank(ALICE);
        presale.purchaseUSDC(2300 * 1e6);
    }

    function test_success() external {
        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
    }
}

contract PresaleTest_userTokensAllocated is PresaleTest {
    uint256 private _totalUserAllocation;
    uint256[] private _purchaseAmountsUSD;

    function setUp() public {
        vm.warp(startDate + 1);

        _purchaseAmountsUSD = [700, 700, 800, 100];

        for (uint256 i; i < _purchaseAmountsUSD.length; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);
            uint256 _roundAllocation = _purchaseAmountsUSD[i] * (USD_PRECISION * PRECISION) / _round.tokenPrice;
            _totalUserAllocation += _roundAllocation;
        }

        vm.prank(ALICE);
        presale.purchase{value: 115 * 1e16}();
    }

    function test_success() external {
        assertEq(presale.userTokensAllocated(ALICE), _totalUserAllocation);
    }
}

contract PresaleTest_ethPrice is PresaleTest {
    function test_success() external {
        assertEq(presale.ethPrice(), 2_000 * PRECISION);
    }
}

contract PresaleTest_ethToUsd is PresaleTest {
    function test_success() external {
        uint256 _ethAmount = 2 * USD_PRECISION;
        uint256 _usdAmount = _ethAmount * presale.ethPrice() / PRECISION;
        assertEq(presale.ethToUsd(_ethAmount), _usdAmount);
    }
}

contract PresaleTest_ethToTokens is PresaleTest {
    function test_success() external {
        IPresale.RoundConfig memory _round = presale.round(0);
        uint256 _ethAmount = 2 * USD_PRECISION;
        uint256 _usdAmount = _ethAmount * presale.ethPrice() / PRECISION;
        uint256 _tokenAmount = _usdAmount * _round.tokenPrice / (USD_PRECISION * PRECISION);
        assertEq(presale.ethToTokens(0, _ethAmount), _tokenAmount);
    }
}

contract PresaleTest_usdToTokens is PresaleTest {
    function test_success() external {
        IPresale.RoundConfig memory _round = presale.round(0);
        uint256 _usdAmount = 100 * USD_PRECISION;
        uint256 _tokenAmount = _usdAmount * _round.tokenPrice / USD_PRECISION;
        assertEq(presale.usdToTokens(0, _usdAmount), _tokenAmount);
    }
}

contract PresaleTest_pause is PresaleTest {
    event Paused(address account);

    function test_success() external {
        vm.prank(GLOBAL_ADMIN);
        presale.pause();

        assertTrue(presale.paused());
    }

    function test_rejects_whenPaused() external {
        vm.startPrank(GLOBAL_ADMIN);
        presale.pause();

        vm.expectRevert("Pausable: paused");
        presale.pause();

        vm.stopPrank();
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        presale.pause();
    }

    function test_emits_Paused() external assertEvent {
        vm.prank(GLOBAL_ADMIN);
        emit Paused(GLOBAL_ADMIN);
        presale.pause();
    }
}

contract PresaleTest_unpause is PresaleTest {
    event Unpaused(address account);

    function setUp() public {
        vm.prank(GLOBAL_ADMIN);
        presale.pause();
    }

    function test_success() external {
        vm.prank(GLOBAL_ADMIN);
        presale.unpause();
        assertFalse(presale.paused());
    }

    function test_rejects_whenNotPaused() external {
        vm.startPrank(GLOBAL_ADMIN);
        presale.unpause();

        vm.expectRevert("Pausable: not paused");
        presale.unpause();

        vm.stopPrank();
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        presale.unpause();
    }

    function test_emits_Unpaused() external assertEvent {
        vm.prank(GLOBAL_ADMIN);
        emit Unpaused(GLOBAL_ADMIN);
        presale.unpause();
    }
}

contract PresaleTest_setConfig is PresaleTest {
    event ConfigUpdated(IPresale.PresaleConfig prevConfig, IPresale.PresaleConfig newConfig, address indexed sender);

    IPresale.PresaleConfig private _newConfig;

    function setUp() public {
        _newConfig = IPresale.PresaleConfig({
            minDepositAmount: uint128(1 * USD_PRECISION),
            maxUserAllocation: uint128(10_000 * PRECISION),
            startDate: 1 days,
            endDate: 10 days,
            withdrawTo: GLOBAL_ADMIN
        });
    }

    function test_success() external {
        vm.prank(GLOBAL_ADMIN);

        presale.setConfig(_newConfig);

        IPresale.PresaleConfig memory _config = presale.config();

        assertEq(_config.minDepositAmount, uint128(1 * USD_PRECISION));
        assertEq(_config.maxUserAllocation, uint128(10_000 * PRECISION));
        assertEq(_config.startDate, 1 days);
        assertEq(_config.endDate, 10 days);
        assertEq(_config.withdrawTo, GLOBAL_ADMIN);
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        presale.setConfig(_newConfig);
    }

    function test_rejects_whenInvalidDates() external {
        IPresale.PresaleConfig memory _invalidConfig = IPresale.PresaleConfig({
            minDepositAmount: uint128(1 * USD_PRECISION),
            maxUserAllocation: uint128(10_000 * PRECISION),
            startDate: 10 days,
            endDate: 1 days,
            withdrawTo: GLOBAL_ADMIN
        });

        vm.expectRevert("INVALID_DATES");

        vm.prank(GLOBAL_ADMIN);
        presale.setConfig(_invalidConfig);
    }

    function test_rejects_whenInvalidWithdrawTo() external {
        IPresale.PresaleConfig memory _invalidConfig = IPresale.PresaleConfig({
            minDepositAmount: uint128(1 * USD_PRECISION),
            maxUserAllocation: uint128(10_000 * PRECISION),
            startDate: 1 days,
            endDate: 10 days,
            withdrawTo: payable(address(0))
        });

        vm.expectRevert("INVALID_WITHDRAW_TO");

        vm.prank(GLOBAL_ADMIN);
        presale.setConfig(_invalidConfig);
    }

    function test_emit_ConfigUpdated() external assertEvent {
        IPresale.PresaleConfig memory _prevConfig = presale.config();
        vm.prank(GLOBAL_ADMIN);
        emit ConfigUpdated(_prevConfig, _newConfig, GLOBAL_ADMIN);
        presale.setConfig(_newConfig);
    }
}

contract PresaleTest_setRounds is PresaleTest {
    event RoundsUpdated(IPresale.RoundConfig[] prevRounds, IPresale.RoundConfig[] newRounds, address indexed sender);

    IPresale.RoundConfig[] private _newRounds;
    uint256 private _totalRounds;

    function setUp() public {
        _totalRounds = 10;
        for (uint256 i; i < 10; ++i) {
            IPresale.RoundConfig memory _round = IPresale.RoundConfig({tokenPrice: i * 10, tokensAllocated: i * 100});
            _newRounds.push(_round);
        }
    }

    function test_success() external {
        vm.prank(GLOBAL_ADMIN);
        presale.setRounds(_newRounds);

        IPresale.RoundConfig[] memory _rounds = presale.rounds();

        for (uint256 i; i < _totalRounds; ++i) {
            assertEq(_rounds[i].tokenPrice, i * 10);
            assertEq(_rounds[i].tokensAllocated, i * 100);
        }

        assertEq(_rounds.length, _totalRounds);
    }

    function test_should_setCurrentRoundIndex() external {
        vm.warp(startDate + 1);

        vm.prank(ALICE);
        presale.purchaseDAI(2100 * USD_PRECISION);

        while (_newRounds.length != 0) {
            _newRounds.pop();
        }

        uint256[] memory _tokenPrices = new uint256[](3);
        _tokenPrices[0] = 70000000000000000;
        _tokenPrices[1] = 70000000000000000;
        _tokenPrices[2] = 80000000000000000;

        for (uint256 i; i < 3; ++i) {
            IPresale.RoundConfig memory _round =
                IPresale.RoundConfig({tokenPrice: _tokenPrices[i], tokensAllocated: 10_000 * PRECISION});
            _newRounds.push(_round);
        }

        vm.prank(GLOBAL_ADMIN);
        presale.setRounds(_newRounds);

        assertEq(presale.currentRoundIndex(), 2);
    }

    function test_rejects_whenNotOwner() external {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(ALICE);
        presale.setRounds(_newRounds);
    }

    function test_emits_RoundsUpdated() external assertEvent {
        vm.prank(GLOBAL_ADMIN);
        emit RoundsUpdated(rounds, _newRounds, GLOBAL_ADMIN);
        presale.setRounds(_newRounds);
    }
}

contract PresaleTest_purchase is PresaleTest {
    event Purchase(
        uint256 indexed roundIndex,
        address indexed asset,
        uint256 tokenPrice,
        uint256 amountAsset,
        uint256 amountUSD,
        uint256 tokensAllocated,
        address indexed sender
    );

    uint256[] private _purchaseAmountsUSD;
    uint256 private _totalCostUSD;
    uint256 private _totalAllocation;

    uint256 private _aliceEthBalance;
    uint256 private _withdrawToEthBalance;

    function setUp() public {
        _purchaseAmountsUSD = [700, 700, 800, 800, 900, 900, 200];
    }

    function test_success() external {
        _aliceEthBalance = ALICE.balance;
        _withdrawToEthBalance = address(config.withdrawTo).balance;

        vm.warp(startDate + 1);

        vm.prank(ALICE);
        presale.purchase{value: 2.5 ether}(); // 5k usd worth

        for (uint256 i; i < _purchaseAmountsUSD.length; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);
            uint256 _roundAllocation = _purchaseAmountsUSD[i] * (USD_PRECISION * PRECISION) / _round.tokenPrice;
            _totalAllocation += _roundAllocation;

            uint256 _tokenCostUSD = _roundAllocation * _round.tokenPrice / PRECISION;
            _totalCostUSD += _tokenCostUSD;
        }

        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
        assertEq(presale.userTokensAllocated(ALICE), _totalAllocation);

        assertEq(ALICE.balance, _aliceEthBalance - (_totalCostUSD / 2_000));
        assertEq(address(config.withdrawTo).balance, _withdrawToEthBalance + (_totalCostUSD / 2_000));
    }

    function test_rejects_whenPaused() external {
        vm.prank(GLOBAL_ADMIN);
        presale.pause();

        vm.expectRevert("Pausable: paused");

        vm.prank(ALICE);
        presale.purchase{value: 2.5 ether}();
    }

    function test_rejects_whenRaiseNotStarted() external {
        vm.warp(startDate - 1);

        vm.expectRevert("RAISE_NOT_STARTED");

        vm.prank(ALICE);
        presale.purchase{value: 2.5 ether}();
    }

    function test_rejects_whenRaiseEnded() external {
        vm.warp(endDate + 1);

        vm.expectRevert("RAISE_ENDED");

        vm.prank(ALICE);
        presale.purchase{value: 2.5 ether}();
    }

    function test_rejects_whenMinDepositAmount() external {
        //        vm.warp(startDate + 1);
        //
        //        vm.expectRevert("MIN_DEPOSIT_AMOUNT");
        //
        //        vm.prank(GLOBAL_ADMIN);
        //        presale.purchase{value: 1}();
    }

    function test_emits_Purchase() external assertEvent {
        vm.warp(startDate + 1);

        for (uint256 i; i < _purchaseAmountsUSD.length; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);
            uint256 _roundAllocation = _purchaseAmountsUSD[i] * (USD_PRECISION * PRECISION) / _round.tokenPrice;
            _totalAllocation += _roundAllocation;

            uint256 _tokenCostUSD = _roundAllocation * _round.tokenPrice / PRECISION;
            _totalCostUSD += _tokenCostUSD;

            emit Purchase(
                i,
                address(0),
                _round.tokenPrice,
                _tokenCostUSD * 2.5 ether / 5_000 ether,
                _tokenCostUSD,
                _roundAllocation,
                ALICE
            );
        }

        vm.prank(ALICE);
        presale.purchase{value: 2.5 ether}();
    }
}

contract PresaleTest_purchaseForAccount is PresaleTest {
    event Purchase(
        uint256 indexed roundIndex,
        address indexed asset,
        uint256 tokenPrice,
        uint256 amountAsset,
        uint256 amountUSD,
        uint256 tokensAllocated,
        address indexed sender
    );

    uint256[] private _purchaseAmountsUSD;
    uint256 private _totalCostUSD;
    uint256 private _totalAllocation;

    uint256 private _adminEthBalance;
    uint256 private _withdrawToEthBalance;

    function setUp() public {
        _purchaseAmountsUSD = [700, 700, 800, 800, 900, 900, 200];
    }

    function test_success() external {
        _adminEthBalance = GLOBAL_ADMIN.balance;
        _withdrawToEthBalance = address(config.withdrawTo).balance;

        vm.warp(startDate + 1);

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: 2.5 ether}(ALICE); // 5k usd worth

        for (uint256 i; i < _purchaseAmountsUSD.length; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);
            uint256 _roundAllocation = _purchaseAmountsUSD[i] * (USD_PRECISION * PRECISION) / _round.tokenPrice;
            _totalAllocation += _roundAllocation;

            uint256 _tokenCostUSD = _roundAllocation * _round.tokenPrice / PRECISION;
            _totalCostUSD += _tokenCostUSD;
        }

        assertEq(presale.totalRaisedUSD(), _totalCostUSD);
        assertEq(presale.userTokensAllocated(ALICE), _totalAllocation);

        assertEq(GLOBAL_ADMIN.balance, _adminEthBalance);
        assertEq(address(config.withdrawTo).balance, _withdrawToEthBalance);
    }

    function test_rejects_whenPaused() external {
        vm.prank(GLOBAL_ADMIN);
        presale.pause();

        vm.expectRevert("Pausable: paused");

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: 2.5 ether}(ALICE);
    }

    function test_rejects_whenRaiseNotStarted() external {
        vm.warp(startDate - 1);

        vm.expectRevert("RAISE_NOT_STARTED");

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: 2.5 ether}(ALICE);
    }

    function test_rejects_whenRaiseEnded() external {
        vm.warp(endDate + 1);

        vm.expectRevert("RAISE_ENDED");

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: 2.5 ether}(ALICE);
    }

    function test_rejects_whenMinDepositAmount() external {
        //        vm.warp(startDate + 1);
        //
        //        vm.expectRevert("MIN_DEPOSIT_AMOUNT");
        //
        //        vm.prank(GLOBAL_ADMIN);
        //        presale.purchase{value: 1}();
    }

    function test_emits_Purchase() external assertEvent {
        vm.warp(startDate + 1);

        for (uint256 i; i < _purchaseAmountsUSD.length; ++i) {
            IPresale.RoundConfig memory _round = presale.round(i);
            uint256 _roundAllocation = _purchaseAmountsUSD[i] * (USD_PRECISION * PRECISION) / _round.tokenPrice;
            _totalAllocation += _roundAllocation;

            uint256 _tokenCostUSD = _roundAllocation * _round.tokenPrice / PRECISION;
            _totalCostUSD += _tokenCostUSD;

            emit Purchase(
                i,
                address(0),
                _round.tokenPrice,
                _tokenCostUSD * 2.5 ether / 5_000 ether,
                _tokenCostUSD,
                _roundAllocation,
                ALICE
            );
        }

        vm.prank(GLOBAL_ADMIN);
        presale.purchase{value: 2.5 ether}(ALICE);
    }
}

contract PresaleTest_purchaseUSDC is PresaleTest {
    function test_success() external {}

    function test_rejects_whenPaused() external {}

    function test_rejects_whenRaiseNotStarted() external {}

    function test_rejects_whenRaiseEnded() external {}

    function test_rejects_whenMinDepositAmount() external {}

    function test_emits_Receipt() external {}
}

contract PresaleTest_purchaseDAI is PresaleTest {
    function test_success() external {}

    function test_rejects_whenPaused() external {}

    function test_rejects_whenRaiseNotStarted() external {}

    function test_rejects_whenRaiseEnded() external {}

    function test_rejects_whenMinDepositAmount() external {}

    function test_emits_Receipt() external {}
}

contract PresaleTest_allocate is PresaleTest {
    function test_success() external {}

    function test_rejects_whenPaused() external {}

    function test_rejects_whenRaiseNotStarted() external {}

    function test_rejects_whenRaiseEnded() external {}

    function test_rejects_whenMinDepositAmount() external {}

    function test_emits_Receipt() external {}
}

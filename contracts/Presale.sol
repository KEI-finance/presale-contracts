// SPDX-License-Identifier: UNLICENSED

pragma solidity =0.8.9;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "./IPresale.sol";

contract Presale is IPresale, Ownable2Step, ReentrancyGuard, Pausable {
    address public immutable override USDC;

    address public immutable override DAI;

    AggregatorV3Interface public immutable ORACLE;

    uint256 private immutable PRECISION = 1e18;
    uint256 private immutable ETH_TO_WEI_PRECISION = 1e10;
    uint256 private immutable USDC_TO_WEI_PRECISION = 1e12;

    uint48 private $startsAt;
    uint48 private $endsAt;

    Round[] private $rounds;
    uint256 private $currentRoundIndex;

    uint256 private $totalRaisedUSD;

    address payable public $withdrawTo;

    mapping(address => uint256) private $depositsUSD;
    mapping(address => uint256) private $tokensAllocated;

    mapping(uint256 => mapping(address => uint256)) private $roundDepositsUSD;
    mapping(uint256 => mapping(address => uint256)) private $roundTokensAllocated;

    constructor(
        uint48 startsAt_,
        uint48 endsAt_,
        address payable withdrawTo_,
        address oracle_,
        address usdc_,
        address dai_
    ) {
        _updateDates(startsAt_, endsAt_);
        _setWithdrawTo(withdrawTo_);

        ORACLE = AggregatorV3Interface(oracle_);
        USDC = usdc_;
        DAI = dai_;
    }

    function startsAt() external view override returns (uint48) {
        return $startsAt;
    }

    function endsAt() external view override returns (uint48) {
        return $endsAt;
    }

    function currentRoundIndex() external view override returns (uint256) {
        return $currentRoundIndex;
    }

    function rounds(uint256 roundIndex) external view override returns (Round memory) {
        return $rounds[roundIndex];
    }

    function totalRounds() external view override returns (uint256) {
        return $rounds.length;
    }

    function totalRaisedUSD() external view override returns (uint256) {
        return $totalRaisedUSD;
    }

    function raisedUSD(uint256 roundIndex) external view override returns (uint256) {
        return $rounds[roundIndex].totalRaisedUSD;
    }

    function roundDepositsUSD(uint256 roundIndex, address account) external view override returns (uint256) {
        return $roundDepositsUSD[roundIndex][account];
    }

    function roundTokensAllocated(uint256 roundIndex, address account) external view override returns (uint256) {
        return $roundTokensAllocated[roundIndex][account];
    }

    function depositsUSD(address account) external view override returns (uint256) {
        return $depositsUSD[account];
    }

    function tokensAllocated(address account) external view override returns (uint256) {
        return $tokensAllocated[account];
    }

    function ethPrice() public view returns (uint256) {
        (, int256 price,,,) = ORACLE.latestRoundData();
        return uint256(uint256(price) * ETH_TO_WEI_PRECISION);
    }

    function ethToUsd(uint256 amount) public view returns (uint256) {
        uint256 _ethPrice = ethPrice();
        uint256 _ethAmountInUsd = (_ethPrice * amount) / PRECISION;
        return _ethAmountInUsd;
    }

    function usdToTokens(uint256 roundIndex, uint256 amount) public view returns (uint256) {
        Round memory _round = $rounds[roundIndex];
        return (amount * _round.tokenAllocation) / _round.allocationUSD;
    }

    function updateDates(uint48 newStartsAt, uint48 newEndsAt) external override onlyOwner {
        _updateDates(newStartsAt, newEndsAt);
    }

    function setWithdrawTo(address payable account) external onlyOwner {
        _setWithdrawTo(account);
    }

    function setRounds(Round[] memory _rounds) external onlyOwner {
        if ($rounds.length > 0) {
            delete $rounds;
        }

        for (uint256 i; i < _rounds.length; ++i) {
            Round memory _round = _rounds[i];
            $rounds.push(_round);
            emit RoundSet(i, _round, _msgSender());
        }
    }

    function depositETH() public payable override whenNotPaused {
        uint256 amountUSD = ethToUsd(msg.value);

        $withdrawTo.transfer(msg.value);
        _sync($currentRoundIndex, address(0), amountUSD, _msgSender());
    }

    function depositUSDC(uint256 amount) external override whenNotPaused {
        address sender = _msgSender();

        IERC20(USDC).transferFrom(sender, $withdrawTo, amount);

        uint256 amountScaled = amount * USDC_TO_WEI_PRECISION;
        _sync($currentRoundIndex, USDC, amountScaled, sender);
    }

    function depositDAI(uint256 amount) external override whenNotPaused {
        address sender = _msgSender();

        IERC20(DAI).transferFrom(sender, $withdrawTo, amount);
        _sync($currentRoundIndex, DAI, amount, sender);
    }

    receive() external payable whenNotPaused {
        depositETH();
    }

    function _updateDates(uint48 _newStartsAt, uint48 _newEndsAt) private {
        uint48 _startsAt = $startsAt;
        uint48 _endsAt = $endsAt;

        require(block.timestamp <= _startsAt || _startsAt == 0, "PRESALE_STARTED");
        require(_newStartsAt <= _newEndsAt, "INVALID_DATES");

        emit DatesUpdated(_startsAt, _newStartsAt, _endsAt, _newEndsAt, _msgSender());

        $startsAt = _newStartsAt;
        $endsAt = _newEndsAt;
    }

    function _setWithdrawTo(address payable newWithdrawTo) private {
        require(newWithdrawTo != address(0), "INVALID_WITHDRAW_TO");

        emit WithdrawToUpdated($withdrawTo, newWithdrawTo, _msgSender());

        $withdrawTo = newWithdrawTo;
    }

    function _sync(uint256 roundIndex, address asset, uint256 amountUSD, address account) private {
        Round memory _round = $rounds[roundIndex];
        uint256 _availableAllocation = _round.allocationUSD - _round.totalRaisedUSD;
        uint256 _roundsLength = $rounds.length;

        uint256 _depositAmount = amountUSD;
        uint256 _currentRoundIndex = roundIndex;

        while (_availableAllocation > 0) {
            if (_depositAmount >= _availableAllocation) {
                _deposit(_currentRoundIndex, asset, _availableAllocation, account);

                if (_currentRoundIndex == _roundsLength - 1) {
                    uint256 _leftOver = _depositAmount - _availableAllocation;
                    _refund(asset, _leftOver, account);
                } else {
                    $currentRoundIndex += 1;
                    _currentRoundIndex = $currentRoundIndex;
                }

                _depositAmount -= _availableAllocation;

                _round = $rounds[_currentRoundIndex];
                _availableAllocation = _round.allocationUSD - _round.totalRaisedUSD;
            } else {
                _deposit(_currentRoundIndex, asset, _depositAmount, account);
                break;
            }
        }
    }

    function _deposit(uint256 roundIndex, address asset, uint256 amountUSD, address account) private {
        Round memory _round = $rounds[roundIndex];

        require(block.timestamp >= $startsAt, "RAISE_NOT_STARTED");
        require(block.timestamp <= $endsAt, "RAISE_ENDED");
        require(amountUSD >= _round.minDepositUSD && _round.minDepositUSD != 0, "MIN_DEPOSIT_AMOUNT");
        require(amountUSD + $roundDepositsUSD[roundIndex][account] <= _round.userCapUSD, "EXCEED_USER_CAP");

        uint256 tokenAllocation = usdToTokens(roundIndex, amountUSD);

        $rounds[roundIndex].totalRaisedUSD += amountUSD;

        $roundDepositsUSD[roundIndex][account] += amountUSD;
        $roundTokensAllocated[roundIndex][account] += tokenAllocation;

        $depositsUSD[account] += amountUSD;
        $tokensAllocated[account] += tokenAllocation;

        $totalRaisedUSD += amountUSD;

        emit Deposit(roundIndex, asset, amountUSD, account);
    }

    function _refund(address asset, uint256 amountUSD, address account) private {
        if (asset == address(0)) {
            uint256 amountInWei = amountUSD * PRECISION / ethPrice();
            payable(account).transfer(amountInWei);
        } else {
            IERC20(asset).transfer(account, amountUSD);
        }
    }
}

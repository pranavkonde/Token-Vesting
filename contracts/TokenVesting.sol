// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenVesting is Ownable {
    IERC20 public immutable token;

    struct VestingSchedule {
        address beneficiary;
        uint256 cliff;
        uint256 start;
        uint256 duration;
        uint256 totalAmount;
        uint256 releasedAmount;
        bool revoked;
    }

    mapping(address => VestingSchedule[]) public vestingSchedules;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 totalAmount,
        uint256 cliff,
        uint256 start,
        uint256 duration
    );
    event TokensReleased(address indexed beneficiary, uint256 amount, uint256 scheduleIndex);
    event VestingScheduleRevoked(address indexed beneficiary, uint256 scheduleIndex, uint256 unreleasedAmount);

    constructor(IERC20 _token) Ownable(msg.sender) {
        require(address(_token) != address(0), "Invalid token address");
        token = _token;
    }

    function createVestingSchedule(
        address _beneficiary,
        uint256 _cliff,
        uint256 _start,
        uint256 _duration,
        uint256 _totalAmount
    ) public onlyOwner {
        require(_beneficiary != address(0), "Vesting: Invalid beneficiary address");
        require(_duration > 0, "Vesting: Duration must be greater than 0");
        require(_totalAmount > 0, "Vesting: Total amount must be greater than 0");
        require(_start >= block.timestamp, "Vesting: Start time must be in the future or present");
        require(_cliff >= _start, "Vesting: Cliff must be after or at start time");

        vestingSchedules[_beneficiary].push(
            VestingSchedule({
                beneficiary: _beneficiary,
                cliff: _cliff,
                start: _start,
                duration: _duration,
                totalAmount: _totalAmount,
                releasedAmount: 0,
                revoked: false
            })
        );

        emit VestingScheduleCreated(_beneficiary, _totalAmount, _cliff, _start, _duration);
    }

    function calculateVestedAmount(address _beneficiary, uint256 _scheduleIndex)
        public
        view
        returns (uint256)
    {
        require(_scheduleIndex < vestingSchedules[_beneficiary].length, "Vesting: Invalid schedule index");
        VestingSchedule storage schedule = vestingSchedules[_beneficiary][_scheduleIndex];
        require(!schedule.revoked, "Vesting: Schedule has been revoked");

        uint256 currentTime = block.timestamp;

        if (currentTime < schedule.start || currentTime < schedule.cliff) {
            return 0;
        }

        uint256 elapsedTime = currentTime - schedule.start;

        if (elapsedTime >= schedule.duration) {
            return schedule.totalAmount - schedule.releasedAmount;
        }

        uint256 vestedSoFar = (schedule.totalAmount * elapsedTime) / schedule.duration;
        return vestedSoFar - schedule.releasedAmount;
    }

    function release(uint256 _scheduleIndex) public {
        require(_scheduleIndex < vestingSchedules[msg.sender].length, "Vesting: Invalid schedule index");
        VestingSchedule storage schedule = vestingSchedules[msg.sender][_scheduleIndex];
        require(msg.sender == schedule.beneficiary, "Vesting: Only beneficiary can release tokens");
        require(!schedule.revoked, "Vesting: Schedule has been revoked");

        uint256 amountToRelease = calculateVestedAmount(msg.sender, _scheduleIndex);
        require(amountToRelease > 0, "Vesting: No tokens available for release yet");

        schedule.releasedAmount += amountToRelease;
        token.transfer(schedule.beneficiary, amountToRelease);

        emit TokensReleased(schedule.beneficiary, amountToRelease, _scheduleIndex);
    }

    function revokeVestingSchedule(address _beneficiary, uint256 _scheduleIndex) public onlyOwner {
        require(_scheduleIndex < vestingSchedules[_beneficiary].length, "Vesting: Invalid schedule index");
        VestingSchedule storage schedule = vestingSchedules[_beneficiary][_scheduleIndex];
        require(!schedule.revoked, "Vesting: Schedule already revoked");

        schedule.revoked = true;
        uint256 unreleasedAmount = schedule.totalAmount - schedule.releasedAmount;

        emit VestingScheduleRevoked(_beneficiary, _scheduleIndex, unreleasedAmount);
    }

    function recoverERC20(address _tokenAddress, address _to) public onlyOwner {
        require(_tokenAddress != address(0), "Vesting: Invalid token address");
        require(_to != address(0), "Vesting: Invalid recipient address");
        require(_tokenAddress != address(token), "Vesting: Cannot recover vested token");

        IERC20 tokenToRecover = IERC20(_tokenAddress);
        tokenToRecover.transfer(_to, tokenToRecover.balanceOf(address(this)));
    }

    function recoverRBTC(address payable _to) public onlyOwner {
        require(_to != address(0), "Vesting: Invalid recipient address");
        (bool success, ) = _to.call{value: address(this).balance}("");
        require(success, "Vesting: RBTC transfer failed");
    }
} 
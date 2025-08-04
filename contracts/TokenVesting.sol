// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title TokenVesting
 * @dev A token holder contract that can release its token balance gradually like a
 * typical vesting scheme, with a cliff and vesting period.
 *
 * Unreleased tokens on revocation are returned to the contract owner's address to be
 * managed by the project treasury.
 */
contract TokenVesting is Ownable {
    IERC20 public immutable token;

    struct VestingSchedule {
        address beneficiary;
        uint64 cliff;      // Timestamp when cliff period ends
        uint64 start;      // Timestamp when vesting begins
        uint64 duration;   // Duration of the vesting period in seconds
        uint128 total;     // Total amount of tokens to be vested
        uint128 released;  // Amount of tokens released
        bool revoked;      // Whether the vesting was revoked
    }

    // Private mapping of beneficiary to their vesting schedules
    mapping(address => VestingSchedule[]) private _vestingSchedules;

    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 total,
        uint256 cliff,
        uint256 start,
        uint256 duration
    );
    event TokensReleased(address indexed beneficiary, uint256 amount, uint256 scheduleIndex);
    event VestingScheduleRevoked(address indexed beneficiary, uint256 scheduleIndex, uint256 unreleasedAmount);

    constructor(IERC20 _token) Ownable(msg.sender) {
        require(address(_token) != address(0), "TokenVesting: token is zero address");
        token = _token;
    }

    /**
     * @dev Creates a vesting schedule for a beneficiary.
     * @param beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param cliff duration in seconds of the cliff in which tokens will begin to vest
     * @param start the time (as Unix time) at which point vesting starts
     * @param duration duration in seconds of the period in which the tokens will vest
     * @param amount total amount of tokens to be vested
     */
    function createVestingSchedule(
        address beneficiary,
        uint64 cliff,
        uint64 start,
        uint64 duration,
        uint128 amount
    ) public onlyOwner {
        require(beneficiary != address(0), "TokenVesting: beneficiary is zero address");
        require(duration > 0, "TokenVesting: duration is 0");
        require(amount > 0, "TokenVesting: amount is 0");
        require(start >= uint64(block.timestamp), "TokenVesting: start is before current time");
        require(cliff >= start, "TokenVesting: cliff is before start");

        _vestingSchedules[beneficiary].push(
            VestingSchedule({
                beneficiary: beneficiary,
                cliff: cliff,
                start: start,
                duration: duration,
                total: amount,
                released: 0,
                revoked: false
            })
        );

        emit VestingScheduleCreated(beneficiary, amount, cliff, start, duration);
    }

    /**
     * @dev Returns the vesting schedule information for a beneficiary at a given index.
     * @return the vesting schedule structure information
     */
    function getVestingSchedule(address beneficiary, uint256 index) 
        external 
        view 
        returns (VestingSchedule memory) 
    {
        require(index < getVestingScheduleCount(beneficiary), "TokenVesting: index out of bounds");
        return _vestingSchedules[beneficiary][index];
    }

    /**
     * @dev Returns the number of vesting schedules associated with a beneficiary.
     * @return the number of vesting schedules
     */
    function getVestingScheduleCount(address beneficiary) 
        public 
        view 
        returns (uint256) 
    {
        return _vestingSchedules[beneficiary].length;
    }

    /**
     * @dev Calculates the amount of tokens that has already vested but hasn't been released yet.
     */
    function calculateVestedAmount(address beneficiary, uint256 scheduleIndex)
        public
        view
        returns (uint256)
    {
        require(scheduleIndex < getVestingScheduleCount(beneficiary), "TokenVesting: invalid schedule index");
        VestingSchedule storage schedule = _vestingSchedules[beneficiary][scheduleIndex];
        require(!schedule.revoked, "TokenVesting: schedule is revoked");

        uint256 currentTime = block.timestamp;

        if (currentTime < schedule.start || currentTime < schedule.cliff) {
            return 0;
        }

        uint256 elapsedTime = currentTime - schedule.start;

        if (elapsedTime >= schedule.duration) {
            return uint256(schedule.total) - uint256(schedule.released);
        }

        uint256 vestedAmount = (uint256(schedule.total) * elapsedTime) / uint256(schedule.duration);
        return vestedAmount - uint256(schedule.released);
    }

    /**
     * @dev Release vested tokens to beneficiary.
     */
    function release(uint256 scheduleIndex) public {
        require(scheduleIndex < getVestingScheduleCount(msg.sender), "TokenVesting: invalid schedule index");
        VestingSchedule storage schedule = _vestingSchedules[msg.sender][scheduleIndex];
        require(msg.sender == schedule.beneficiary, "TokenVesting: only beneficiary can release");
        require(!schedule.revoked, "TokenVesting: schedule is revoked");

        uint256 unreleased = calculateVestedAmount(msg.sender, scheduleIndex);
        require(unreleased > 0, "TokenVesting: no tokens are due");

        schedule.released = uint128(uint256(schedule.released) + unreleased);
        require(token.transfer(schedule.beneficiary, unreleased), "TokenVesting: transfer failed");

        emit TokensReleased(schedule.beneficiary, unreleased, scheduleIndex);
    }

    /**
     * @dev Revokes the vesting schedule for given beneficiary and index.
     * @notice Revoked tokens are returned to the contract owner's address.
     */
    function revokeVestingSchedule(address beneficiary, uint256 scheduleIndex) public onlyOwner {
        require(scheduleIndex < getVestingScheduleCount(beneficiary), "TokenVesting: invalid schedule index");
        VestingSchedule storage schedule = _vestingSchedules[beneficiary][scheduleIndex];
        require(!schedule.revoked, "TokenVesting: schedule is already revoked");

        schedule.revoked = true;

        uint256 unreleased = calculateVestedAmount(beneficiary, scheduleIndex);
        uint256 refund = uint256(schedule.total) - uint256(schedule.released) - unreleased;

        // Transfer vested but unreleased tokens to beneficiary
        if (unreleased > 0) {
            schedule.released = uint128(uint256(schedule.released) + unreleased);
            require(token.transfer(beneficiary, unreleased), "TokenVesting: transfer failed");
            emit TokensReleased(beneficiary, unreleased, scheduleIndex);
        }

        // Transfer unvested tokens back to owner
        if (refund > 0) {
            require(token.transfer(owner(), refund), "TokenVesting: transfer failed");
        }

        emit VestingScheduleRevoked(beneficiary, scheduleIndex, refund);
    }

    /**
     * @dev Emergency function to recover any ERC20 tokens sent to the contract by mistake
     * @notice Cannot be used to recover the vesting token
     */
    function recoverERC20(address tokenAddress, address to) public onlyOwner {
        require(tokenAddress != address(0), "TokenVesting: token is zero address");
        require(to != address(0), "TokenVesting: recipient is zero address");
        require(tokenAddress != address(token), "TokenVesting: cannot recover vesting token");

        IERC20 tokenToRecover = IERC20(tokenAddress);
        uint256 balance = tokenToRecover.balanceOf(address(this));
        require(tokenToRecover.transfer(to, balance), "TokenVesting: transfer failed");
    }

    /**
     * @dev Emergency function to recover any RBTC sent to the contract by mistake
     */
    function recoverRBTC(address payable to) public onlyOwner {
        require(to != address(0), "TokenVesting: recipient is zero address");
        uint256 balance = address(this).balance;
        (bool success, ) = to.call{value: balance}("");
        require(success, "TokenVesting: RBTC transfer failed");
    }
}
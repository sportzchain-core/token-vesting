// SPDX-License-Identifier: MIT
pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

/**
 * @title Contract for SportZchain token vesting
 *
 * @dev Contract which gives the ability to act as a pool of funds for allocating
 *   tokens to any number of other addresses. Token grants support the ability to vest over time in
 *   accordance a predefined vesting schedule. A given wallet can receive no more than one token grant.
 */
contract TokenVesting is Ownable, AccessControl, ReentrancyGuard, Initializable {
    // grantor role
    bytes32 public constant GRANTOR_ROLE = keccak256("GRANTOR_ROLE");
    using SafeERC20 for IERC20;

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyGrantor() {
        require(hasRole(GRANTOR_ROLE, msg.sender), "Caller is not a Grantor");
        _;
    }

    struct VestingSchedule{
        bool initialized;
        address beneficiary;       // beneficiary of tokens after they are released
        uint256 cliff;             // cliff period in seconds
        uint256 start;             // start time of the vesting period
        uint256 duration;          // duration of the vesting period in seconds
        uint256 slicePeriodSeconds; // duration of a slice period for the vesting in seconds
        bool  revocable;            // whether or not the vesting is revocable
        uint256 amountTotal;        // total amount of tokens to be released at the end of the vesting
        uint256 released;          // amount of tokens released
        bool revoked;               // whether or not the vesting has been revoked
        uint256 firstReleasePercent;   // percent to release after vesting start
        uint256 secondReleasePercent;   // percent to release after x days of vesting start
        uint256 secondReleaseTime;  // time for second release
    }

    // locked schedule
    VestingSchedule private lockedSchedule;

    // address of the ERC20 token
    IERC20 private _token;

    // array to hold the unique vesting ids
    bytes32[] private vestingSchedulesIds;

    // mapping between vesting ids and the vesting schedule
    mapping(bytes32 => VestingSchedule) private vestingSchedules;

    // total amount vested
    uint256 private vestingSchedulesTotalAmount;

    // count of how many vesting is mapped to an address
    mapping(address => uint256) private holdersVestingCount;

    // events
    event Released(uint256 amount);
    event Revoked();

    /**
    * @dev Reverts if no vesting schedule matches the passed identifier.
    */
    modifier onlyIfVestingScheduleExists(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true);
        _;
    }

    /**
    * @dev Reverts if the vesting schedule does not exist or has been revoked.
    */
    modifier onlyIfVestingScheduleNotRevoked(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true);
        require(vestingSchedules[vestingScheduleId].revoked == false);
        _;
    }

    function initialize(address token_, address owner_) public virtual initializer {
        __TokenVesting_init_unchained(token_, owner_);
    }

    function __TokenVesting_init_unchained(address token_, address owner_) internal onlyInitializing {
        _token = IERC20(token_);
        // set the owner as the admin & grantor
        _setupRole(DEFAULT_ADMIN_ROLE, owner_);
        _setupRole(GRANTOR_ROLE, owner_);
    }

    // @dev default no action functions
    receive() external payable {}

    // @dev default no action functions
    fallback() external payable {}

    /**
    * @dev Returns the number of vesting schedules associated to a beneficiary.
    *
    * @param _beneficiary - address of the beneficiary
    * @return the number of vesting schedules
    */
    function getVestingSchedulesCountByBeneficiary(address _beneficiary)
    external
    view
    returns(uint256){
        return holdersVestingCount[_beneficiary];
    }

    /**
    * @dev Returns the vesting schedule id at the given index.
    *
    * @param index - index of the vesting
    * @return the vesting id
    */
    function getVestingIdAtIndex(uint256 index)
    external
    view
    returns(bytes32){
        require(index < getVestingSchedulesCount(), "TokenVesting: index out of bounds");
        return vestingSchedulesIds[index];
    }

    /**
    * @notice Returns the vesting schedule information for a given holder and index.
    *
    * @param holder - Address of the holder
    * @param index - index of the vesting
    * @return the vesting schedule structure information
    */
    function getVestingScheduleByAddressAndIndex(address holder, uint256 index)
    external
    view
    returns(VestingSchedule memory){
        return getVestingSchedule(computeVestingScheduleIdForAddressAndIndex(holder, index));
    }


    /**
    * @notice Returns the total amount of vesting schedules.
    * @return the total amount of vesting schedules
    */
    function getVestingSchedulesTotalAmount()
    external
    view
    returns(uint256){
        return vestingSchedulesTotalAmount;
    }

    /**
    * Function to return the token
    *
    * @return Returns the address of the ERC20 token managed by the vesting contract.
    */
    function getToken()
    external
    view
    returns(address){
        return address(_token);
    }

    /**
    * @notice Creates a new vesting schedule for a beneficiary.
    *
    * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
    * @param _start start time of the vesting period
    * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
    * @param _duration duration in seconds of the period in which the tokens will vest
    * @param _slicePeriodSeconds duration of a slice period for the vesting in seconds
    * @param _revocable whether the vesting is revocable or not
    * @param _amount total amount of tokens to be released at the end of the vesting
    * @param _firstReleasePercent percent to release after vesting start
    * @param _secondReleasePercent percent to release after x days of vesting start
    * @param _secondReleaseTime time for second release
    * @param _fromLocked create vesting from locked tokens
    */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds,
        bool _revocable,
        uint256 _amount,
        uint256 _firstReleasePercent,
        uint256 _secondReleasePercent,
        uint256 _secondReleaseTime,
        bool _fromLocked
    )
    public
    onlyGrantor  {
        require(
            ((_fromLocked) ? lockedSchedule.amountTotal - lockedSchedule.released : this.getWithdrawableAmount()) >= _amount,
            "TokenVesting: cannot create vesting schedule because not sufficient tokens"
        );
        require(_duration > 0, "TokenVesting: duration must be > 0");
        require(_amount > 0, "TokenVesting: amount must be > 0");
        require(_slicePeriodSeconds >= 1, "TokenVesting: slicePeriodSeconds must be >= 1");
        require(_firstReleasePercent + _secondReleasePercent <= 100, "TokenVesting: release percent must be <= 100");

        // compute a unique id for the vesting schedule
        bytes32 vestingScheduleId = this.computeNextVestingScheduleIdForHolder(_beneficiary);

        // set the cliff from the start time
        uint256 cliff = _start + _cliff;

        // create the vesting schedule
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            true,
            _beneficiary,
            cliff,
            _start,
            _duration,
            _slicePeriodSeconds,
            _revocable,
            _amount,
            0,
            false,
            _firstReleasePercent,
            _secondReleasePercent,
            _secondReleaseTime
        );

        vestingSchedulesIds.push(vestingScheduleId);
        holdersVestingCount[_beneficiary] += 1;

        if(_fromLocked) {
            // update locked tokens
            lockedSchedule.amountTotal -= _amount;
        } else {
            // total amount that was vested
            vestingSchedulesTotalAmount = vestingSchedulesTotalAmount + _amount;
        }
    }

    /**
    * @notice Revokes the vesting schedule for given identifier.
    *
    * @param vestingScheduleId the vesting schedule identifier
    */
    function revoke(bytes32 vestingScheduleId)
    public
    onlyGrantor
    onlyIfVestingScheduleNotRevoked(vestingScheduleId){
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        require(vestingSchedule.revocable == true, "TokenVesting: vesting is not revocable");
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        if(vestedAmount > 0){
            release(vestingScheduleId, vestedAmount);
        }
        uint256 unreleased = vestingSchedule.amountTotal - vestingSchedule.released;
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount - unreleased;
        vestingSchedule.revoked = true;
    }


    /**
    * @notice Release vested amount of tokens.
    *
    * @param vestingScheduleId the vesting schedule identifier
    * @param amount the amount to release
    */
    function release(
        bytes32 vestingScheduleId,
        uint256 amount
    )
    public
    nonReentrant
    onlyIfVestingScheduleNotRevoked(vestingScheduleId) {
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        bool isBeneficiary = _msgSender() == vestingSchedule.beneficiary;
        bool isGrantor = hasRole(GRANTOR_ROLE, _msgSender());
        require(
            isBeneficiary || isGrantor,
            "TokenVesting: only beneficiary and grantor can release vested tokens"
        );
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        require(vestedAmount >= amount, "TokenVesting: cannot release tokens, not enough vested tokens");
        vestingSchedule.released = vestingSchedule.released + amount;
        address payable beneficiaryPayable = payable(vestingSchedule.beneficiary);
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount - amount;
        _token.safeTransfer(beneficiaryPayable, amount);
    }

    /**
    * @notice Release locked vested amount of tokens.
    *
    * @param amount the amount to release
    */
    function releaseLocked(
        uint256 amount
    )
    public
    onlyGrantor
    nonReentrant {
        uint256 vestedAmount = _computeReleasableAmount(lockedSchedule);
        require(vestedAmount >= amount, "TokenVesting: cannot release tokens, not enough vested tokens");
        lockedSchedule.released = lockedSchedule.released + amount;
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount - amount;
    }

    /**
    * @dev Returns the number of vesting schedules managed by this contract.
    * @return the number of vesting schedules
    */
    function getVestingSchedulesCount()
    public
    view
    returns(uint256){
        return vestingSchedulesIds.length;
    }

    /**
    * @notice Computes the vested amount of locked tokens.
    *
    * @return the vested amount
    */
    function computeLockedReleasableAmount()
    public
    view
    returns(uint256){
        return _computeReleasableAmount(lockedSchedule);
    }

    /**
    * @notice Computes the vested amount of tokens for the given vesting schedule identifier.
    *
    * @param vestingScheduleId - unique identifier of the vesting
    * @return the vested amount
    */
    function computeReleasableAmount(bytes32 vestingScheduleId)
    public
    onlyIfVestingScheduleNotRevoked(vestingScheduleId)
    view
    returns(uint256){
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        return _computeReleasableAmount(vestingSchedule);
    }

    /**
    * @notice Returns the vesting schedule information for a given identifier.
    *
    * @param vestingScheduleId - unique identifier of the vesting
    * @return the vesting schedule structure information
    */
    function getVestingSchedule(bytes32 vestingScheduleId)
    public
    view
    returns(VestingSchedule memory){
        return vestingSchedules[vestingScheduleId];
    }

    /**
    * @notice Returns the locked vesting schedule information.
    *
    * @return the vesting schedule structure information
    */
    function getLockedVestingSchedule()
    public
    view
    returns(VestingSchedule memory){
        return lockedSchedule;
    }

    /**
    * @notice Withdraw the specified amount if possible.
    *
    * @dev This function can be used to withdraw the available tokens
    * with this contract to the caller
    *
    * @param amount the amount to withdraw
    */
    function withdraw(uint256 amount)
    public
    onlyGrantor
    nonReentrant  {
        require(this.getWithdrawableAmount() >= amount, "TokenVesting: not enough withdrawable funds");
        _token.safeTransfer(msg.sender, amount);
    }

    /**
    * @notice Creates a new vesting schedule for a contract it self.
    *
    * @param _start start time of the vesting period
    * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
    * @param _duration duration in seconds of the period in which the tokens will vest
    * @param _slicePeriodSeconds duration of a slice period for the vesting in seconds
    */
    function lockWithdrawableAmount(
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _slicePeriodSeconds
    )
    public
    onlyGrantor
    nonReentrant {
        require(
            this.getWithdrawableAmount() > 0,
            "TokenVesting: withdrawable amount must be > 0"
        );
        require(_duration > 0, "TokenVesting: duration must be > 0");
        require(_slicePeriodSeconds >= 1, "TokenVesting: slicePeriodSeconds must be >= 1");

        // set the cliff from the start time
        uint256 cliff = _start + _cliff;

        // update the locked vesting schedule
        lockedSchedule.initialized = true;
        lockedSchedule.beneficiary = address(this);
        lockedSchedule.amountTotal += this.getWithdrawableAmount();
        lockedSchedule.cliff = cliff;
        lockedSchedule.start = _start;
        lockedSchedule.duration = _duration;
        lockedSchedule.slicePeriodSeconds = _slicePeriodSeconds;

        // total amount that was vested
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount + this.getWithdrawableAmount();
    }

    /**
    * @dev Returns the amount of tokens that can be withdrawn by the owner.
    * @return the amount of tokens
    */
    function getWithdrawableAmount()
    public
    view
    returns(uint256){
        return _token.balanceOf(address(this)) - vestingSchedulesTotalAmount;
    }

    /**
    * @dev Computes the next vesting schedule identifier for a given holder address.
    *
    * @param holder - address of the vesting holder
    */
    function computeNextVestingScheduleIdForHolder(address holder)
    public
    view
    returns(bytes32){
        return computeVestingScheduleIdForAddressAndIndex(holder, holdersVestingCount[holder]);
    }

    /**
    * @dev Returns the last vesting schedule for a given holder address.
    *
    * @param holder - address of the vesting holder
    */
    function getLastVestingScheduleForHolder(address holder)
    public
    view
    returns(VestingSchedule memory){
        return vestingSchedules[computeVestingScheduleIdForAddressAndIndex(holder, holdersVestingCount[holder] - 1)];
    }

    /**
    * @dev Computes the vesting schedule identifier for an address and an index.
    *
    *
    */
    function computeVestingScheduleIdForAddressAndIndex(address holder, uint256 index)
    public
    pure
    returns(bytes32){
        return keccak256(abi.encodePacked(holder, index));
    }

    /**
    * @dev calculate token percent
    *
    * @param amount - number of tokens
    * @param percent - percentage to calculate
    * @return the amount of tokens by percent
    */
    function _calculatePercentAmount(uint256 amount, uint256 percent) internal pure returns(uint256) {
        return (amount * percent / 100);
    }

    /**
    * @dev Computes the releasable amount of tokens for a vesting schedule.
    *
    * @param vestingSchedule - VestingSchedule data structure
    * @return the amount of releasable tokens
    */
    function _computeReleasableAmount(VestingSchedule memory vestingSchedule)
    internal
    view
    returns(uint256){
        uint256 currentTime = getCurrentTime();

        uint256 firstReleaseAmount = _calculatePercentAmount(vestingSchedule.amountTotal, vestingSchedule.firstReleasePercent);
        uint256 secondReleaseAmount = _calculatePercentAmount(vestingSchedule.amountTotal, vestingSchedule.secondReleasePercent);
        uint256 releasedAmount = vestingSchedule.released;

        if ((currentTime < vestingSchedule.cliff) || vestingSchedule.revoked == true) {
            // time is less than cliff or vesting is revoked
            return 0;
        } else if (currentTime >= vestingSchedule.start && firstReleaseAmount > releasedAmount) {
            // first percent release
            return firstReleaseAmount - releasedAmount;
        } else if (currentTime >= vestingSchedule.secondReleaseTime && secondReleaseAmount > releasedAmount) {
            // second percent release
            return firstReleaseAmount + secondReleaseAmount - releasedAmount;
        } else if (currentTime >= vestingSchedule.start + vestingSchedule.duration) {
            // time is greater than vesting durations
            return vestingSchedule.amountTotal - releasedAmount;
        } else {
            uint256 timeFromStart = currentTime - vestingSchedule.start;
            uint secondsPerSlice = vestingSchedule.slicePeriodSeconds;
            uint256 vestedSlicePeriods = timeFromStart / secondsPerSlice;
            uint256 vestedSeconds = vestedSlicePeriods * secondsPerSlice;
            uint256 vestedAmount = vestingSchedule.amountTotal * vestedSeconds / vestingSchedule.duration;
            vestedAmount = vestedAmount - releasedAmount;
            return vestedAmount;
        }
    }

    function getCurrentTime()
    internal
    virtual
    view
    returns(uint256){
        return block.timestamp;
    }

}
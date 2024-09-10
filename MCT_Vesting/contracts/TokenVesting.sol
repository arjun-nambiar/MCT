// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/**
 * @title MundoCrypto Token vesting
 */
contract MCTVesting is Ownable, ReentrancyGuard{
    using SafeMath for uint256;
    // using SafeERC20 library to handle token transfer.
    using SafeERC20 for IERC20;
    // initialize Struct for schedule a vesting
    struct VestingSchedule{
        bool initialized;
        // beneficiary of tokens after they are released
        address  beneficiary;
        // cliff period in seconds
        uint256  cliff;
        // start time of the vesting period
        uint256  start;
        // duration of the vesting period in seconds
        uint256  duration;
        // total amount of tokens to be released at the end of the vesting
        uint256 amountTotal;
        // amount of tokens released
        uint256  released;
    }

    // address of the ERC20 token
    IERC20 immutable private _token;

    //emit the event, when vesting is created
    event CreateVestingSchedule(
        bool initialized,
        address indexed beneficiary,
        uint256 cliff,
        uint256 start,
        uint256 duration,
        uint256 amountTotal
    );

    // initialize vesting schedule ID
    bytes32[] private vestingSchedulesIds;
    // Track the vesting schedules with ID
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    // total amount of vesting schedules.
    uint256 private vestingSchedulesTotalAmount;
   
    // Trigger event for when the benificiarry claim tokens
    event Released(uint256 amount);
    // Trigger the event, when owner recover the tokens from SC.
    event Withdraw(address indexed addr, uint256 amountTotal);

    /**
    * @dev Reverts if no vesting schedule matches the passed identifier.
    */
    modifier onlyIfVestingScheduleExists(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true);
        _;
    }

    /**
     * @dev Creates a vesting contract.
     * @param token_ address of the ERC20 token contract
     */
    constructor(address token_) {
        // check whether the token is zero address or not.
        // If the address is zero, revert.
        require(token_ != address(0x0));
        _token = IERC20(token_);
    }

    receive() external payable {}

    fallback() external payable {}

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
    * @dev Returns the address of the ERC20 token managed by the vesting contract.
    */
    function getToken()
    external
    view
    returns(address){
        return address(_token);
    }

     /**
    * @dev Computes the vesting schedule identifier for an address.
    */
    function computeVestingScheduleIdForAddress(address holder)
        public
        pure
        returns(bytes32){
        return keccak256(abi.encodePacked(holder));
    }

    /**
    * @notice Creates a new vesting schedule for a beneficiary.
    * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
    * @param _start start time of the vesting period
    * @param _cliff duration in seconds of the cliff in which tokens will begin to vest
    * @param _duration duration in seconds of the period in which the tokens will vest
    * @param _amountTotal total amount of tokens to be released at the end of the vesting
    */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _duration,
        uint256 _amountTotal
    )
        public
        onlyOwner{
        require(
            this.getWithdrawableAmount() >= _amountTotal,
            "TokenVesting: cannot create vesting schedule because not sufficient tokens"
        );
        require(_duration > 0, "TokenVesting: duration must be > 0");
        require(_amountTotal > 0, "TokenVesting: amount must be > 0");
        bytes32 vestingScheduleId =  this.computeVestingScheduleIdForAddress(_beneficiary);
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            true,
            _beneficiary,
            _cliff,
            _start,
            _duration,
            _amountTotal,
            0
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.add(_amountTotal);
        vestingSchedulesIds.push(vestingScheduleId);

        // Emit an event indicating that a schedule has been assigned.
        emit CreateVestingSchedule(
            true,
            _beneficiary,
            _cliff,
            _start,
            _duration,
            _amountTotal
        );
        
    }

   

    /**
    * @notice Withdraw the specified amount if possible.
    * @param amount the amount to withdraw
    */
    function withdraw(uint256 amount)
        public
        nonReentrant
        onlyOwner{
        require(this.getWithdrawableAmount() >= amount, "TokenVesting: not enough withdrawable funds");
        _token.safeTransfer(owner(), amount);
        emit Withdraw(owner(), amount);
    }

    /**
    * @notice Release vested amount of tokens.
    * @param vestingScheduleId the vesting schedule identifier
    * @param amount the amount to release
    */
    function release(
        bytes32 vestingScheduleId,
        uint256 amount
    )
        public
        nonReentrant
        {
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        bool isBeneficiary = msg.sender == vestingSchedule.beneficiary;
        bool isOwner = msg.sender == owner();
        require(
            isBeneficiary || isOwner,
            "TokenVesting: only beneficiary and owner can release vested tokens"
        );
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        require(vestedAmount >= amount, "TokenVesting: cannot release tokens, not enough vested tokens");
        vestingSchedule.released = vestingSchedule.released.add(amount);
        address payable beneficiaryPayable = payable(vestingSchedule.beneficiary);
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(amount);
        _token.safeTransfer(beneficiaryPayable, amount);

        emit Released(amount);
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
    * @notice Computes the vested amount of tokens for the given vesting schedule identifier.
    * @return the vested amount
    */
    function computeReleasableAmount(bytes32 vestingScheduleId)
        public
        view
        returns(uint256){
        VestingSchedule storage vestingSchedule = vestingSchedules[vestingScheduleId];
        return _computeReleasableAmount(vestingSchedule);
    }

    /**
    * @notice Returns the vesting schedule information for a given identifier.
    * @return the vesting schedule structure information
    */
    function getVestingSchedule(bytes32 vestingScheduleId)
        public
        view
        returns(VestingSchedule memory){
        return vestingSchedules[vestingScheduleId];
    }

    /**
    * @dev Returns the amount of tokens that can be withdrawn by the owner.
    * @return the amount of tokens
    */
    function getWithdrawableAmount()
        public
        view
        returns(uint256){
        return _token.balanceOf(address(this)).sub(vestingSchedulesTotalAmount);
    }

   
    /**
    * @dev Computes the releasable amount of tokens for a vesting schedule.
    * @return the amount of releasable tokens
    */
    function _computeReleasableAmount(VestingSchedule memory vestingSchedule)
    internal
    view
    returns(uint256){
        uint256 currentTime = getCurrentTime();
        if ((currentTime < vestingSchedule.start.add(vestingSchedule.cliff))) {
            return 0;
        } else if (currentTime >= vestingSchedule.start.add(vestingSchedule.cliff).add(vestingSchedule.duration)) {
            return vestingSchedule.amountTotal;
        } else {
            uint256 vestedAmount;
            vestedAmount = (vestingSchedule.amountTotal * (currentTime - (vestingSchedule.cliff + vestingSchedule.start))) / vestingSchedule.duration ;
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

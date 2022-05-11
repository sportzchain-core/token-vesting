const { expect } = require("chai");
const hre = require("hardhat");

describe("TokenVesting contract test", async function () {
  let TokenVestingCloneContract;
  let TokenVestingClone;
  let TokenContract;
  let Token;
  let owner;
  let addr1;

  let TOKEN_ADDRESS;
  let VESTING_CONTRACT;
  let VESTING1;
  let VESTING2;

  const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000';
  const GRANTER_ROLE = '0xd10feaa7fea55567e367a112bc53907318a50949442dfc0570945570c5af57cf';

  const THOUSAND_TOKENS = '1000000000000000000000';

  let ALL_VESTING_SCHEDULES = [];

  before(async function () {
    [owner, addr1] = await ethers.getSigners();

    /* TOKEN_CONTRCT */

    TokenContract = await ethers.getContractFactory("TestToken");

    Token = await TokenContract.deploy();

    TOKEN_ADDRESS = Token.address;

    /* VESTING_CONTRACT */

    VESTING_CONTRACT = await ethers.getContractFactory("TokenVesting");

    /* ------------------------------------------------------------------------------ */

    TokenVestingCloneContract = await ethers.getContractFactory("TokenVestingClone");

    TokenVestingClone = await TokenVestingCloneContract.deploy(TOKEN_ADDRESS);
  });

  describe("Deployment Using TokenVestingClone", function() {
    it("Should deploy new vesting contract", async function() {
        const tx1 = await TokenVestingClone.createNewVestingContract();
        const { gasUsed: createGasUsed, events } = await tx1.wait();
        const { address } = events.find(Boolean);
        // console.log(`deployed address: ${address}`);

        VESTING1 = await VESTING_CONTRACT.attach(
          address // The deployed contract address
        );

        // await expect(VESTING1.grantRole(GRANTER_ROLE , owner.address))
        // .to.emit(VESTING1, "RoleGranted")
        // .withArgs(GRANTER_ROLE, owner.address, owner.address);
    });

    it("Should throw error on create Vesting Schedule if contract has not enough token balance", async function() {
      let c_date = parseInt(Date.now() / 1000);
      let _beneficiary = addr1.address;
      let _start = c_date; // timestamp
      let _cliff = 5; // seconds
      let _duration = 5; // seconds
      let _slicePeriodSeconds = 5; // seconds
      let _revocable = false;
      let _amount = THOUSAND_TOKENS; // Tokens
      let _firstReleasePercent = 5; // percent
      let _secondReleasePercent = 10; // percent
      let _secondReleaseTime = c_date + 60; // timestamp

      await expect(
        VESTING1.createVestingSchedule(
          _beneficiary,
          _start,
          _cliff,
          _duration,
          _slicePeriodSeconds,
          _revocable,
          _amount,
          _firstReleasePercent,
          _secondReleasePercent,
          _secondReleaseTime
        )
      )
      .to.be.revertedWith("TokenVesting: cannot create vesting schedule because not sufficient tokens");
    });

    it("Should create new Vesting Schedule", async function() {
      await expect(Token.transfer(VESTING1.address, THOUSAND_TOKENS))
      .to.emit(Token, "Transfer")
      .withArgs(owner.address, VESTING1.address, THOUSAND_TOKENS);

      /*
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
          uint256 _secondReleaseTime
        )
      */

      let c_date = parseInt(Date.now() / 1000);
      let _beneficiary = addr1.address;
      let _start = c_date; // timestamp
      let _cliff = 60; // seconds
      let _duration = 60; // seconds
      let _slicePeriodSeconds = 60; // seconds
      let _revocable = false;
      let _amount = THOUSAND_TOKENS; // Tokens
      let _firstReleasePercent = 5; // percent
      let _secondReleasePercent = 10; // percent
      let _secondReleaseTime = c_date + 60; // timestamp

      expect(
        await VESTING1.createVestingSchedule(
          _beneficiary,
          _start,
          _cliff,
          _duration,
          _slicePeriodSeconds,
          _revocable,
          _amount,
          _firstReleasePercent,
          _secondReleasePercent,
          _secondReleaseTime
        )
      );

      ALL_VESTING_SCHEDULES.push({_beneficiary, _start, _cliff: _start + _cliff, _duration, _slicePeriodSeconds, _revocable, _amount, _firstReleasePercent, _secondReleasePercent, _secondReleaseTime});
    });

    it("Should get last Vesting Schedule by user", async function() {
      let data = await VESTING1.getLastVestingScheduleForHolder(addr1.address);

      let VestingSchedule = {
        _beneficiary: data.beneficiary,
        _start: Number(data.start),
        _cliff: Number(data.cliff),
        _duration: Number(data.duration),
        _slicePeriodSeconds: Number(data.slicePeriodSeconds),
        _revocable: data.revocable,
        _amount: data.amountTotal.toString(),
        _firstReleasePercent: Number(data.firstReleasePercent),
        _secondReleasePercent: Number(data.secondReleasePercent),
        _secondReleaseTime: Number(data.secondReleaseTime)
      };

      expect(VestingSchedule).to.deep.equal(ALL_VESTING_SCHEDULES[0]);
    });

    it("Should throw error on call release before duration", async function() {
      let VestingScheduleId = await VESTING1.computeVestingScheduleIdForAddressAndIndex(addr1.address, 0);
      // console.log('VestingScheduleId', VestingScheduleId)

      await expect(VESTING1.release(VestingScheduleId, THOUSAND_TOKENS))
        .to.be.revertedWith("TokenVesting: cannot release tokens, not enough vested tokens");
    });

    it("Should increase block time", async function() {
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [100],
      });

      await hre.network.provider.request({
        method: "evm_mine"
      });
    });
    it("Should release first percent tokens from vesting", async function() {
      let VestingScheduleId = await VESTING1.computeVestingScheduleIdForAddressAndIndex(addr1.address, 0);
      // console.log('VestingScheduleId', VestingScheduleId);

      let releasableAmount = await VESTING1.computeReleasableAmount(VestingScheduleId);

      let amount = Number(ALL_VESTING_SCHEDULES[0]._amount);
      let fPercent = ALL_VESTING_SCHEDULES[0]._firstReleasePercent;
      let cAmount = (amount * fPercent / 100).toString();

      // console.log('releasableAmount', releasableAmount)
      releasableAmount = releasableAmount.toString();

      expect(releasableAmount).to.equal(cAmount);

      // let getVestingSchedule = await VESTING1.getVestingSchedule(VestingScheduleId);
      // console.log(getVestingSchedule);

      await expect(VESTING1.release(VestingScheduleId, releasableAmount))
      .to.emit(Token, "Transfer")
      .withArgs(VESTING1.address, addr1.address, releasableAmount);
    });

    it("Should release second percent tokens from vesting", async function() {
      let VestingScheduleId = await VESTING1.computeVestingScheduleIdForAddressAndIndex(addr1.address, 0);
      // console.log('VestingScheduleId', VestingScheduleId);

      let releasableAmount = await VESTING1.computeReleasableAmount(VestingScheduleId);

      let amount = Number(ALL_VESTING_SCHEDULES[0]._amount);
      let sPercent = ALL_VESTING_SCHEDULES[0]._secondReleasePercent;
      let cAmount = (amount * sPercent / 100).toString();

      expect(releasableAmount).to.equal(cAmount);

      // let getVestingSchedule = await VESTING1.getVestingSchedule(VestingScheduleId);
      // console.log(getVestingSchedule);

      await expect(VESTING1.release(VestingScheduleId, releasableAmount))
      .to.emit(Token, "Transfer")
      .withArgs(VESTING1.address, addr1.address, releasableAmount);
    });

    it("Should release remaining tokens from vesting", async function() {
      let VestingScheduleId = await VESTING1.computeVestingScheduleIdForAddressAndIndex(addr1.address, 0);
      // console.log('VestingScheduleId', VestingScheduleId);

      let releasableAmount = await VESTING1.computeReleasableAmount(VestingScheduleId);

      let amount = Number(ALL_VESTING_SCHEDULES[0]._amount);
      let fPercent = ALL_VESTING_SCHEDULES[0]._firstReleasePercent;
      let sPercent = ALL_VESTING_SCHEDULES[0]._secondReleasePercent;

      let fAmount = (amount * fPercent / 100);
      let sAmount = (amount * sPercent / 100);
      let cAmount = (amount - fAmount - sAmount).toString();

      // console.log('releasableAmount', releasableAmount)
      releasableAmount = releasableAmount.toString();

      expect(releasableAmount).to.equal(cAmount);

      // let getVestingSchedule = await VESTING1.getVestingSchedule(VestingScheduleId);
      // console.log(getVestingSchedule);

      await expect(VESTING1.release(VestingScheduleId, releasableAmount))
      .to.emit(Token, "Transfer")
      .withArgs(VESTING1.address, addr1.address, releasableAmount);

      expect(await Token.balanceOf(addr1.address)).to.equal(THOUSAND_TOKENS);
    });

    it("Should deploy new vesting contract with 0 VestingSchedules", async function() {
        const tx1 = await TokenVestingClone.createNewVestingContract();
        const { gasUsed: createGasUsed, events } = await tx1.wait();
        const { address } = events.find(Boolean);
        // console.log(`deployed address: ${address}`);

        VESTING2 = await VESTING_CONTRACT.attach(
          address // The deployed contract address
        );

        expect(await VESTING2.getVestingSchedulesCount()).to.equal(0);
    });
  });
});
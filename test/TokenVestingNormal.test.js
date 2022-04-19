const { expect } = require("chai");
const hre = require("hardhat");

describe("TokenVesting contract test", async function () {
  let TokenVestingNormalContract;
  let TokenVestingNormal;
  let TokenContract;
  let Token;
  let owner;
  let addr1;
  let addr2;

  let TOKEN_ADDRESS;

  const DEFAULT_ADMIN_ROLE = '0x0000000000000000000000000000000000000000000000000000000000000000';
  const GRANTER_ROLE = '0xd10feaa7fea55567e367a112bc53907318a50949442dfc0570945570c5af57cf';

  const THOUSAND_TOKENS = '1000000000000000000000';

  let ALL_VESTING_SCHEDULES = [];

  before(async function () {
    [owner, addr1, addr2] = await ethers.getSigners();

    /* TOKEN_CONTRCT */

    TokenContract = await ethers.getContractFactory("MyToken");

    Token = await TokenContract.deploy();

    TOKEN_ADDRESS = Token.address;

    /* VESTING_CONTRACT */

    TokenVestingNormalContract = await ethers.getContractFactory("TokenVestingNormal");

    TokenVestingNormal = await TokenVestingNormalContract.deploy(TOKEN_ADDRESS);
  });

  describe("Create Vesting Schedule Using TokenVestingNormal", function() {
    it("Should grant role", async function() {
      await expect(TokenVestingNormal.grantRole(GRANTER_ROLE, owner.address))
      .to.emit(TokenVestingNormal, "RoleGranted")
      .withArgs(GRANTER_ROLE, owner.address, owner.address);
    });

    it("Should throw error on create Vesting Schedule if contract has not enough token balance", async function() {
      let _beneficiary = addr1.address;
      let _start = parseInt(Date.now() / 1000); // timestamp
      let _cliff = 5; // seconds
      let _duration = 5; // seconds
      let _slicePeriodSeconds = 5; // seconds
      let _revocable = false;
      let _amount = THOUSAND_TOKENS; // Tokens

      await expect(TokenVestingNormal.createVestingSchedule(_beneficiary, _start, _cliff, _duration, _slicePeriodSeconds, _revocable, _amount))
      .to.be.revertedWith("TokenVesting: cannot create vesting schedule because not sufficient tokens");
    });

    it("Should create new Vesting Schedule", async function() {
      await expect(Token.transfer(TokenVestingNormal.address, THOUSAND_TOKENS))
      .to.emit(Token, "Transfer")
      .withArgs(owner.address, TokenVestingNormal.address, THOUSAND_TOKENS);

      /*
        function createVestingSchedule(
          address _beneficiary,
          uint256 _start,
          uint256 _cliff,
          uint256 _duration,
          uint256 _slicePeriodSeconds,
          bool _revocable,
          uint256 _amount
        )
      */

      let _beneficiary = addr1.address;
      let _start = parseInt(Date.now() / 1000); // timestamp
      let _cliff = 60; // seconds
      let _duration = 60; // seconds
      let _slicePeriodSeconds = 60; // seconds
      let _revocable = false;
      let _amount = THOUSAND_TOKENS; // Tokens

      expect(await TokenVestingNormal.createVestingSchedule(_beneficiary, _start, _cliff, _duration, _slicePeriodSeconds, _revocable, _amount));

      ALL_VESTING_SCHEDULES.push({_beneficiary, _start, _cliff: _start + _cliff, _duration, _slicePeriodSeconds, _revocable, _amount});
    });

    it("Should get last Vesting Schedule by user", async function() {
      let data = await TokenVestingNormal.getLastVestingScheduleForHolder(addr1.address);

      let VestingSchedule = {
        _beneficiary: data.beneficiary,
        _start: Number(data.start),
        _cliff: Number(data.cliff),
        _duration: Number(data.duration),
        _slicePeriodSeconds: Number(data.slicePeriodSeconds),
        _revocable: data.revocable,
        _amount: data.amountTotal.toString()
      };

      expect(VestingSchedule).to.deep.equal(ALL_VESTING_SCHEDULES[0]);
    });

    it("Should throw error on call release before duration", async function() {
      let VestingScheduleId = await TokenVestingNormal.computeVestingScheduleIdForAddressAndIndex(addr1.address, 0);
      // console.log('VestingScheduleId', VestingScheduleId)

      await expect(TokenVestingNormal.release(VestingScheduleId, THOUSAND_TOKENS))
      .to.be.revertedWith("TokenVesting: cannot release tokens, not enough vested tokens");
    });

    it("Should release tokens from vesting", async function() {
      await hre.network.provider.request({
        method: "evm_increaseTime",
        params: [100],
      });

      await hre.network.provider.request({
        method: "evm_mine"
      });

      let VestingScheduleId = await TokenVestingNormal.computeVestingScheduleIdForAddressAndIndex(addr1.address, 0);
      // console.log('VestingScheduleId', VestingScheduleId);

      let releasableAmount = await TokenVestingNormal.computeReleasableAmount(VestingScheduleId);
      // console.log('releasableAmount', releasableAmount)
      releasableAmount = releasableAmount.toString();

      // let getVestingSchedule = await VESTING1.getVestingSchedule(VestingScheduleId);
      // console.log(getVestingSchedule);

      await expect(TokenVestingNormal.release(VestingScheduleId, releasableAmount))
      .to.emit(Token, "Transfer")
      .withArgs(TokenVestingNormal.address, addr1.address, releasableAmount);

      expect(await Token.balanceOf(addr1.address)).to.equal(THOUSAND_TOKENS);
    });
  });
});
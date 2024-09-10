const { expect } = require("chai");

describe("TokenVesting", function () {
  let Token;
  let testToken;
  let TokenVesting;
  let owner;
  let addr1;
  let addr2;
  let addrs;

  before(async function () {
    Token = await ethers.getContractFactory("Token");
    TokenVesting = await ethers.getContractFactory("MockTokenVesting");
  });
  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    testToken = await Token.deploy("MundoCrypto Token", "MCT", 1400000000000000000000000000);
    await testToken.deployed();
  });

  describe("Vesting MundoCrypto Token", function () {
    it("Should assign the total supply of tokens to the owner", async function () {
      const ownerBalance = await testToken.balanceOf(owner.address);
      expect(await testToken.totalSupply()).to.equal(ownerBalance);
    });

    it("Should vest tokens gradually", async function () {
      // deploy vesting contract
      const tokenVesting = await TokenVesting.deploy(testToken.address);
      await tokenVesting.deployed();
      expect((await tokenVesting.getToken()).toString()).to.equal(
        testToken.address
      );
      // send tokens to vesting contract
      await expect(testToken.transfer(tokenVesting.address, 1000))
        .to.emit(testToken, "Transfer")
        .withArgs(owner.address, tokenVesting.address, 1000);
      const vestingContractBalance = await testToken.balanceOf(
        tokenVesting.address
      );
      expect(vestingContractBalance).to.equal(1000);
      expect(await tokenVesting.getWithdrawableAmount()).to.equal(1000);

      const baseTime = 1659294559;
      const beneficiary = addr1;
      const startTime = baseTime;
      const cliff = 120;
      const duration = 600;
      const amount = 500000000000000000000;

      // create new vesting schedule
      await tokenVesting.createVestingSchedule(
        beneficiary.address,
        startTime,
        cliff,
        duration,
        amount
      );
      expect(await tokenVesting.getVestingSchedulesCount()).to.be.equal(1);
      expect(
        await tokenVesting.getVestingSchedulesCountByBeneficiary(
          beneficiary.address
        )
      ).to.be.equal(1);

      // compute vesting schedule id
      const vestingScheduleId =
        await tokenVesting.computeVestingScheduleIdForAddressAndIndex(
          beneficiary.address
        );

      // check that vested amount is 0
      expect(
        await tokenVesting.computeReleasableAmount(vestingScheduleId)
      ).to.be.equal(0);

      // check that only beneficiary can try to release vested tokens
      await expect(
        tokenVesting.connect(addr2).release(vestingScheduleId, 100)
      ).to.be.revertedWith(
        "TokenVesting: only beneficiary and owner can release vested tokens"
      );

      // check that beneficiary cannot release more than the vested amount
      await expect(
        tokenVesting.connect(beneficiary).release(vestingScheduleId, 100)
      ).to.be.revertedWith(
        "TokenVesting: cannot release tokens, not enough vested tokens"
      );

      // release 10 tokens and check that a Transfer event is emitted with a value of 10
      await expect(
        tokenVesting.connect(beneficiary).release(vestingScheduleId, 10000000000000000000)
      )
        .to.emit(testToken, "Transfer")
        .withArgs(tokenVesting.address, beneficiary.address, 10000000000000000000);


      // set current time after the end of the vesting period
      await tokenVesting.setCurrentTime(baseTime + duration + 1);


      // beneficiary release vested tokens (45)
      await expect(
        tokenVesting.connect(beneficiary).release(vestingScheduleId, 45)
      )
        .to.emit(testToken, "Transfer")
        .withArgs(tokenVesting.address, beneficiary.address, 45);

      // owner release vested tokens (45)
      await expect(tokenVesting.connect(owner).release(vestingScheduleId, 45))
        .to.emit(testToken, "Transfer")
        .withArgs(tokenVesting.address, beneficiary.address, 45);
      vestingSchedule = await tokenVesting.getVestingSchedule(
        vestingScheduleId
      );

      // check that the number of released tokens is 500
      expect(vestingSchedule.released).to.be.equal(500000000000000000000);

      // check that the vested amount is 0
      expect(
        await tokenVesting
          .connect(beneficiary)
          .computeReleasableAmount(vestingScheduleId)
      ).to.be.equal(0);

      /*
       * TEST SUMMARY
       * deploy vesting contract
       * send tokens to vesting contract
       * create new vesting schedule (500 tokens)
       * check that vested amount is 0
       * check that only beneficiary can try to release vested tokens
       * check that beneficiary cannot release more than the vested amount
       * release 10 tokens and check that a Transfer event is emitted with a value of 10
       * check that the released amount is 10
       * set current time after the end of the vesting period
       * check that the vested amount is 0
       */
    });

  });
});

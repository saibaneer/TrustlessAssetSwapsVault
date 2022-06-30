const { expect } = require("chai");
const { ethers } = require("hardhat");
const { assert } = require("chai");
const hre = require("hardhat");

describe("Trustless AssetLock", function () {
  let alice, bob;  
  let nonce, lock, dai, vault;
  
  let charlie = "0x0a4c79cE84202b03e95B7a692E5D728d83C44c76";
  let charlieSigner;

  before(async function () {
    [alice, bob] = await ethers.getSigners();
    await hre.network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [charlie],
    });
    charlieSigner = await ethers.provider.getSigner(charlie);
    let daiAddress = "0x6B175474E89094C44Da98b954EedeAC495271d0F";

    const TrustlessLock = await ethers.getContractFactory("AssetLockFactory");
    lock = await TrustlessLock.deploy();
    await lock.deployed();
    console.log("Trustless lock address is: ", lock.address)
    dai = await ethers.getContractAt("IERC20", daiAddress);
  });

  it("should allow a user to deposit funds", async function(){
    const deposit = ethers.utils.parseEther("6");
    await lock.connect(charlieSigner).createDeposit(dai.address, alice.address, {value: deposit});
    const DepositedEvent = lock.filters.Deposited;
    const event = await lock.queryFilter(DepositedEvent, "latest");
    expect(event[0].args.depositor).to.equal(charlie);
    expect(event[0].args.beneficiary).to.equal(alice.address);
    expect(event[0].args.token).to.equal(dai.address);
    nonce = event[0].args.nonce;
    console.log("Nonce is: ", nonce.toString())

    const item = await lock.userToIdToRequest(charlie, nonce.toString());
    // console.log(item)
    expect(item.creator).to.equal(charlie);
    expect(item.unlocker).to.equal(alice.address);
    expect(item.token).to.equal(dai.address);
    expect(item.lockedValue).to.equal(deposit);
  })

  it("should initiate WETH swap", async function () {
    
    await lock.connect(charlieSigner).initiateSwap(nonce.toString(), 1);

    const SwapEvent = lock.filters.Swapped();
    const swapped = await lock.queryFilter(SwapEvent, "latest")
    expect(swapped[0].args.caller).to.equal(charlie);
    expect(swapped[0].args.recipient).to.equal(alice.address);
    expect(swapped[0].args.token).to.equal(dai.address);

    const item = await lock.userToIdToRequest(charlie, nonce.toString())
    expect(item.creator).to.equal(charlie);
    expect(item.unlocker).to.equal(alice.address);
    expect(item.token).to.equal(dai.address);
    expect(item.lockedValue).to.equal(0);
    // address creator;
    //     address unlocker;
    //     address token;
    //     uint unlockTime;
    //     uint lockedValue;
    //     uint destinationTokenValue;
    
  });

  it("should NOT allow charlie withdraw before unlock timeout", async function(){
    try {
      await lock.connect(charlieSigner).withdraw(charlie, nonce.toString());
    } catch (error) {
      // console.log(error.message)
      assert(error.message.includes("Wait until timeout!"));
      return;
    }
    assert(false)
  })
  it("should allow unlocker to unlock funds within period", async function(){
    const unlockerDaiBalanceBefore = await dai.balanceOf(alice.address);
    console.log(
      "Alice's DAI balance before unlock is: ",
      unlockerDaiBalanceBefore.toString()
    );

    await lock.connect(alice).withdraw(charlie, nonce.toString());
    
   

    const unlockerDaiBalanceAfter = await dai.balanceOf(alice.address);
    console.log("Alice's DAI balance after unlock is: ", unlockerDaiBalanceAfter.toString());
    assert(unlockerDaiBalanceAfter.toString() > unlockerDaiBalanceBefore.toString());

    const WithdrawEvent = lock.filters.UnlockerWithdrew();
    const withdrew = await lock.queryFilter(WithdrawEvent, "latest");
    expect(withdrew[0].args.beneficiary).to.equal(alice.address);
    expect(withdrew[0].args.amount).to.equal(unlockerDaiBalanceAfter);
  })
  it("should allow creator to withdraw after timeout", async function(){
    const deposit = ethers.utils.parseEther("6");
    await lock.connect(bob).createDeposit(dai.address, alice.address, {value: deposit});
    const DepositedEvent = lock.filters.Deposited;
    const event = await lock.queryFilter(DepositedEvent, "latest");
    expect(event[0].args.depositor).to.equal(bob.address);
    expect(event[0].args.beneficiary).to.equal(alice.address);
    expect(event[0].args.token).to.equal(dai.address);
    nonce = event[0].args.nonce;

    const item = await lock.userToIdToRequest(bob.address, nonce.toString());
    // console.log(item)
    expect(item.creator).to.equal(bob.address);
    expect(item.unlocker).to.equal(alice.address);
    expect(item.token).to.equal(dai.address);
    expect(item.lockedValue).to.equal(deposit);
    
    const bobDaiBalanceBefore = await dai.balanceOf(bob.address);
    console.log("Bob's DAI balance before unlock is: ", bobDaiBalanceBefore.toString());

    await lock.connect(bob).initiateSwap(nonce.toString(), 1);

    await ethers.provider.send("evm_increaseTime", [2 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    await lock.connect(bob).withdraw(bob.address, nonce.toString());

    const bobDaiBalanceAfter = await dai.balanceOf(bob.address);
    console.log("Bob's DAI balance after unlock is: ", bobDaiBalanceAfter.toString());
    assert(bobDaiBalanceAfter.toString() > bobDaiBalanceBefore.toString());

    const WithdrawEvent = lock.filters.CreatorWithdrew();
    const withdrew = await lock.queryFilter(WithdrawEvent, "latest");
    expect(withdrew[0].args.owner).to.equal(bob.address);
    expect(withdrew[0].args.amount).to.equal(bobDaiBalanceAfter);
  })
});

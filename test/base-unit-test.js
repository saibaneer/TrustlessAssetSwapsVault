const { expect } = require("chai");
const { ethers } = require("hardhat");
const { assert } = require("chai");
const hre = require("hardhat");

describe("Trustless AssetLock", function () {
  let alice, bob;  
  let lock, dai, weth, vault;
  
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
    let wethAddress = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

    const TrustlessLock = await ethers.getContractFactory("AssetLockFactory");
    lock = await TrustlessLock.deploy();
    await lock.deployed();
    console.log("Trustless lock address is: ", lock.address)
    dai = await ethers.getContractAt("IERC20", daiAddress);
    weth = await ethers.getContractAt("IERC20", wethAddress);
  });

  it("should allow a user to deposit funds", async function(){
    const deposit = ethers.utils.parseEther("6");
    await lock.connect(charlieSigner).createDeposit(dai.address, alice.address, {value: deposit});
    const DepositedEvent = lock.filters.Deposited;
    const event = await lock.queryFilter(DepositedEvent, "latest");
    expect(event[0].args.depositor).to.equal(charlie);
    expect(event[0].args.beneficiary).to.equal(alice.address);
    expect(event[0].args.token).to.equal(dai.address);
  })

  it("should initiate WETH swap", async function () {
    
    await lock.connect(charlieSigner).initiateSwap(alice.address, dai.address, 1);

    const SwapEvent = lock.filters.Swapped();
    const swapped = await lock.queryFilter(SwapEvent, "latest")
    expect(swapped[0].args.caller).to.equal(charlie);
    vault = swapped[0].args.vault;

    
  });

  it("should NOT allow charlie withdraw before unlock timeout", async function(){
    try {
      await lock.connect(charlieSigner).withdraw(charlie, alice.address, dai.address);
    } catch (error) {
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

    const vaultDaiBalanceBefore = await dai.balanceOf(vault);
    console.log(
      "Vault's DAI balance before withdraw is: ",
      vaultDaiBalanceBefore.toString()
    );
    // await dai.approve(alice.address, vaultDaiBalanceBefore);
    // await dai.transferFrom(vault, alice.address, vaultDaiBalanceBefore);
    await lock.connect(alice).withdraw(charlie, alice.address, dai.address);
    
   

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
    
    const bobDaiBalanceBefore = await dai.balanceOf(bob.address);
    console.log("Bob's DAI balance before unlock is: ", bobDaiBalanceBefore.toString());

    await lock.connect(bob).initiateSwap(alice.address, dai.address, 1);

    await ethers.provider.send("evm_increaseTime", [2 * 60 * 60]);
    await ethers.provider.send("evm_mine");

    await lock.connect(bob).withdraw(bob.address, alice.address, dai.address);

    const bobDaiBalanceAfter = await dai.balanceOf(bob.address);
    console.log("Bob's DAI balance after unlock is: ", bobDaiBalanceAfter.toString());
    assert(bobDaiBalanceAfter.toString() > bobDaiBalanceBefore.toString());

    const WithdrawEvent = lock.filters.CreatorWithdrew();
    const withdrew = await lock.queryFilter(WithdrawEvent, "latest");
    expect(withdrew[0].args.owner).to.equal(bob.address);
    expect(withdrew[0].args.amount).to.equal(bobDaiBalanceAfter);
  })
});

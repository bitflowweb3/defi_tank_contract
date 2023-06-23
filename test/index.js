const { expect } = require("chai");
const bs58 = require("bs58");
const { ethers } = require("hardhat");
const { delay, fromBigNum, toBigNum, saveFiles, sign } = require("./utils.js");
const { parseUnits } = require("ethers/lib/utils.js");
var owner;
var userWallet;

var NFTTank, EnergyPool, TankToken = { address: "0xcb6460d56825ddc12229c7a7d94b6b26a9f9c867" }, RewardPool;
//static
var USDT = {
    token: { address: "0x1B27A9dE6a775F98aaA5B90B62a4e2A0B84DbDd9" },
    decimals: 6,
    price: 100000,  // 1DFTL = 0.1USDT
    maxNFT: 10000,
    maxPerWallet: 100
}
// var partner = {
//     token: { address: "0xAD522217E64Ec347601015797Dd39050A2a69694" },
//     decimals: 18,
//     price: 500000,  // 1DFTL = 0.5Pumpkin
//     maxNFT: 100,
//     maxPerWallet: 2
// }

const option = { gasPrice: parseUnits("0.2") }

// mode
var isDeploy = true;

describe("Create UserWallet", function () {
    it("Create account", async function () {
        [owner, userWallet] = await ethers.getSigners();
        // if (isDeploy) userWallet = { address: "0x00004A5Eb22A7316DF5c396Ca17E770c23B5E058" }
        const ownerBalance = await ethers.provider.getBalance(owner.address);
        const userBalance = await ethers.provider.getBalance(userWallet.address);
        console.log(owner.address, fromBigNum(ownerBalance), userWallet.address, fromBigNum(userBalance));
    });
});

describe("deploy contract", function () {

    it("test token", async function () {
        const Factory = await ethers.getContractFactory("TankToken");
        // initial supply 1e7 DFTL = 1e6 $ 
        if (isDeploy) {
            TankToken = await Factory.attach(TankToken.address)
        }
        // TankToken = await Factory.deploy(toBigNum(3000000));
        // await TankToken.deployed();
        if (!isDeploy) {
            USDT.token = await Factory.deploy(toBigNum(10000000));
            // partner.token = await Factory.deploy(toBigNum(10000000));
        }
    });

    it("NFTTank contract", async function () {
        const Factory = await ethers.getContractFactory("NFTTank");
        NFTTank = await Factory.deploy(
            "DeFiTank",
            "DFT",
            userWallet.address,
            "https://app.defitankland.com/api/tank"
        );
        await NFTTank.deployed();
    });

    it("EnergyPool contracts", async function () {
        const Factory = await ethers.getContractFactory("EnergyPool");
        EnergyPool = await Factory.deploy();
        await EnergyPool.deployed();
    });

    it("RewardPool contract", async function () {
        const Factory = await ethers.getContractFactory("RewardPool");
        RewardPool = await Factory.deploy(userWallet.address);
        await RewardPool.deployed();
    });

    it("config", async () => {
        var tx = await NFTTank.config(TankToken.address, RewardPool.address);
        await tx.wait();
        var tx = await EnergyPool.setTokens(NFTTank.address, TankToken.address)
        await tx.wait();
        var tx = await EnergyPool.setTreasuryAddress(RewardPool.address)
        await tx.wait();
        var tx = await TankToken.setMinter(EnergyPool.address, true)
        await tx.wait();
    })

    it("config", async () => {
        // reward rate : 30%, jackpot : 0%
        var tx = await RewardPool.config(TankToken.address, "300000", "0");
        await tx.wait();

        // daily reward = 360000 / 40 = 9000 DFTL = 1500 $
        var tx = await TankToken.approve(RewardPool.address, toBigNum(5000000));
        await tx.wait();
        var tx = await RewardPool.externalAddReward(toBigNum(135000));
        await tx.wait();
    })
    // it("add partner", async () => {
    //     if (!isDeploy) {
    //         var tx = await NFTTank.addPartner(USDT.token.address, USDT.decimals, USDT.price, USDT.maxNFT, USDT.maxPerWallet);
    //         await tx.wait();
    //     }
    // })
});

describe("admin setting", function () {
    it("NFTTank contract", async function () {
        const tankClasses = {
            prices: [toBigNum(300), toBigNum(500), toBigNum(500), toBigNum(700), toBigNum(700), toBigNum(900)],
            descriptions: ["tank0", "tank1", "tank2", "tank3", "tank4", "tank5"]
        }
        var tx = await NFTTank.addNewClasses(tankClasses.descriptions, tankClasses.prices);
        await tx.wait();
    })
});

if (!isDeploy) {
    const testRefCode = "0x626c756500000000000000000000000000000000000000000000000000000000";
    describe("NFTTank test", function () {
        it("reward check", async () => {
            let rewardAmount = await RewardPool.rewardPoolAmount();
            console.log("rewardAmount", fromBigNum(rewardAmount) / 100);
        })
        it("mint should be revert", async () => {
            await expect(NFTTank.mint("0", testRefCode)).to.be.revertedWith("ERC20: insufficient allowance");
            await TankToken.approve(NFTTank.address, toBigNum(100000));
            await expect(NFTTank.mint("6", testRefCode)).to.be.revertedWith("Invalid class type");
        })
        it("mint nft", async function () {
            const { price } = await NFTTank.classInfos("0");
            await expect(price).to.be.equal(toBigNum(300));
            await expect(async () => { await NFTTank.mint("0", testRefCode) }).to.changeTokenBalance(
                TankToken,
                owner,
                price.mul(-1)
            );
            await expect(async () => { await NFTTank.mints(["0", "1", "2", "3", "4", "5"], testRefCode) }).to.changeTokenBalance(
                TankToken,
                owner,
                toBigNum(3600).mul(-1)
            );
        })

        it("upgrade nft", async function () {
            // upgrade level to 10 level
            var signature = await sign({
                tokenId: "0",
                level: "10",
                signer: userWallet
            })
            await expect(NFTTank.upgrade("0", "10", signature))
                .to.emit(NFTTank, "LevelUpgrade")
                .withArgs("0", "10");;
        })
    });
    describe("NFT buy with partner test", function () {
        it("mint with USDT should be revert", async () => {
            await expect(NFTTank.mintWithTokens("0", testRefCode, USDT.token.address)).to.be.revertedWith("ERC20: insufficient allowance");
            await USDT.token.approve(NFTTank.address, toBigNum(100000));
        })
        it("mint with USDT nft", async function () {
            await expect(async () => { await NFTTank.mintWithTokens("0", testRefCode, USDT.token.address) }).to.changeTokenBalance(
                USDT.token,
                owner,
                toBigNum(30, 6).mul(-1)
            );
        })
    });

    describe("EnergyPool test", function () {
        it("stake should be revert", async () => {
            await expect(EnergyPool.stake("0", toBigNum(3001))).to.be.revertedWith("capacity limited");
            await expect(EnergyPool.stake("0", toBigNum(3000))).to.be.revertedWith("ERC20: insufficient allowance");
            await TankToken.approve(EnergyPool.address, toBigNum(10000000));
            // await expect(EnergyPool.stake("0", toBigNum(301))).to.be.revertedWith("capacity limited");
        })
        it("stake", async function () {
            await expect(async () => (await EnergyPool.stake("0", toBigNum(3000)))).to.changeTokenBalance(
                TankToken,
                RewardPool,
                toBigNum(300)
            );;
        });
        it("check balance", async () => {
            var poolBalance = await TankToken.balanceOf(EnergyPool.address);
            expect(poolBalance).to.be.equal(toBigNum(2700))
            // time pass
            await network.provider.send("evm_increaseTime", [3600 * 24 * 365])
            await network.provider.send("evm_mine");
            await EnergyPool.updatePool();

            var poolBalance = await TankToken.balanceOf(EnergyPool.address);
            console.log("poolBalance", fromBigNum(poolBalance));

            console.log("stake rate", fromBigNum(await EnergyPool.getRate(), 6) / 0.9);
        })
        it("unstake", async function () {
            await EnergyPool.unstake("0", toBigNum(3000));
            var poolBalance = await TankToken.balanceOf(EnergyPool.address);
            console.log("poolBalance", fromBigNum(poolBalance));
        });
    });

    describe("airDrop test", function () {
        it("airDrop", async function () {
            let players = Array(50).fill(userWallet.address);
            let classTypes = Array(50).fill("0");
            var tx = await NFTTank.airdrop(players, classTypes);
            await tx.wait();
        })
    })

    describe("rewardPool test", function () {
        it("rewardPool", async function () {
            let users = Array(50).fill(userWallet.address);
            let amounts = Array(50).fill(toBigNum("1"));
            var tx = await RewardPool.connect(userWallet).award(users, amounts);
            await tx.wait();
        })
    })
}

if (isDeploy)
    describe("Save contracts", function () {
        it("save abis", async function () {
            const abis = {
                NFTTank: artifacts.readArtifactSync("NFTTank").abi,
                EnergyPool: artifacts.readArtifactSync("EnergyPool").abi,
                TankToken: artifacts.readArtifactSync("TankToken").abi,
                RewardPool: artifacts.readArtifactSync("RewardPool").abi,
            };
            await saveFiles("abis.json", JSON.stringify(abis, undefined, 4));
        });
        it("save addresses", async function () {
            const addresses = {
                NFTTank: NFTTank.address,
                EnergyPool: EnergyPool.address,
                TankToken: TankToken.address,
                RewardPool: RewardPool.address,
                USDT: USDT.address
            };
            await saveFiles(
                "addresses.json",
                JSON.stringify(addresses, undefined, 4)
            );
        });
    });

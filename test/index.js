const { expect, use } = require("chai");
const bs58 = require("bs58");
const { ethers } = require("hardhat");
const { delay, fromBigNum, toBigNum, saveFiles, sign } = require("./utils.js");
const { parseUnits } = require("ethers/lib/utils.js");


// wallets
var owner;
var userWallet;

// contracts
var tankNFT, itemNFT, factoryNFT, factoryStaking, mainToken;

//static
var partnerInfo = {
    token: { address: "0x1B27A9dE6a775F98aaA5B90B62a4e2A0B84DbDd9" },
    decimals: 6,
    price: 100000,  // 1DFTL = 0.1partnerInfo
    maxNFT: 10000,
    maxPerWallet: 100
}

// tokenomics
const Tokenomics = {
    totalSupply: 3000000,
    initialPrice: 0.1,
    tankPrices: [
        300, 300, 500, 500, 700, 700
    ],
    guildPrice: [
        2000
    ]
}

const option = { gasPrice: parseUnits("0.2") }

// mode
var isDeploy = false;

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
        const Factory = await ethers.getContractFactory("Token");
        if (isDeploy) {
            mainToken = await Factory.attach(mainToken.address)
        }
        else {
            // initial supply 1e7 DFTL = 1e6 $ 
            mainToken = await Factory.deploy(toBigNum(Tokenomics.totalSupply));
            await mainToken.deployed();
        }
        if (!isDeploy) {
            partnerInfo.token = await Factory.deploy(toBigNum(10000000));
            // partner.token = await Factory.deploy(toBigNum(10000000));
        }
    });

    it("tankNFT contract", async function () {
        const Factory = await ethers.getContractFactory("PurchasableNFT");
        tankNFT = await Factory.deploy(
            "DeFiTank",
            "DFT",
            "https://app.defitankland.com/api/tank",
            mainToken.address
        );
        await tankNFT.deployed();
    });

    it("item NFT contract", async function () {
        const Factory = await ethers.getContractFactory("PurchasableNFT");
        itemNFT = await Factory.deploy(
            "DeFiTankLand Item",
            "DFTI",
            "https://app.defitankland.com/api/item",
            mainToken.address
        );
        await itemNFT.deployed();
    });

    it("factory NFT contract", async function () {
        const Factory = await ethers.getContractFactory("FactoryNFT");
        factoryNFT = await Factory.deploy(
            "DeFiTankLand Factory",
            "DFTF",
            "https://app.defitankland.com/api/factory",
            mainToken.address
        );
        await factoryNFT.deployed();
    });

    it("factory staking contract", async function () {
        const Factory = await ethers.getContractFactory("FactoryStakingPool");
        factoryStaking = await Factory.deploy(
            "DeFiTankLand Staking Token",
            "SDFTL",
            "https://app.defitankland.com/api/sDFTL",
            mainToken.address,
            factoryNFT.address
        );
        await factoryStaking.deployed();
    });

    it("add partner", async () => {
        if (!isDeploy) {
            var tx = await tankNFT.addPartner(partnerInfo.token.address, partnerInfo.price, partnerInfo.maxNFT, partnerInfo.maxPerWallet);
            await tx.wait();
        }
    })
});

describe("admin setting", function () {
    it("tankNFT contract", async function () {
        const tankClasses = {
            prices: [
                toBigNum(Tokenomics.tankPrices[0]),
                toBigNum(Tokenomics.tankPrices[1]),
                toBigNum(Tokenomics.tankPrices[2]),
                toBigNum(Tokenomics.tankPrices[3]),
                toBigNum(Tokenomics.tankPrices[4]),
                toBigNum(Tokenomics.tankPrices[5])
            ],
            descriptions: ["tank0", "tank1", "tank2", "tank3", "tank4", "tank5"]
        }
        var tx = await tankNFT.addNewClasses(tankClasses.descriptions, tankClasses.prices);
        await tx.wait();

        var tx = await factoryNFT.addNewClasses(["Guild"], [toBigNum(Tokenomics.guildPrice)]);
        await tx.wait();
    })
});

if (!isDeploy) {
    const testRefCode = "0x626c756500000000000000000000000000000000000000000000000000000000";
    describe("tankNFT test", function () {

        it("set admin to userwallet", async () => {
            await tankNFT.setAdmin(userWallet.address);
        })

        it("mint should be revert", async () => {
            await expect(tankNFT.mint("0", testRefCode)).to.be.revertedWith("ERC20: insufficient allowance");
            await mainToken.approve(tankNFT.address, toBigNum(100000));
            await expect(tankNFT.mint("6", testRefCode)).to.be.revertedWith("Invalid class type");
        })

        it("mint nft", async function () {
            const { price } = await tankNFT.classInfos("0");
            await expect(price).to.be.equal(toBigNum(Tokenomics.tankPrices[0]));
            await expect(async () => { await tankNFT.mint("0", testRefCode) }).to.changeTokenBalance(
                mainToken,
                owner,
                price.mul(-1)
            );
            await expect(async () => { await tankNFT.mints(["0", "1", "2", "3", "4", "5"], testRefCode) }).to.changeTokenBalance(
                mainToken,
                owner,
                toBigNum(3000).mul(-1)
            );
        })

        describe("NFT buy with partner test", function () {
            it("mint with partnerInfo should be revert", async () => {
                await expect(tankNFT.mintWithTokens("0", testRefCode, partnerInfo.token.address)).to.be.revertedWith("ERC20: insufficient allowance");
            })
            it("mint with partnerInfo nft", async function () {
                await partnerInfo.token.approve(tankNFT.address, toBigNum(100000));
                await expect(async () => { await tankNFT.mintWithTokens("0", testRefCode, partnerInfo.token.address) }).to.changeTokenBalance(
                    partnerInfo.token,
                    owner,
                    toBigNum(30, 6).mul(-1)
                );
            })
        });
    });

    describe("factory NFT test", function () {

        it("mint should not be revert", async () => {
            await mainToken.approve(factoryNFT.address, toBigNum(100000));
            await factoryNFT.mint("0", testRefCode);
        })

        it("upgrade should be revert", async () => {
            //     // upgrade level to 10 level
            var signature = await sign({
                tokenId: "0",
                level: "10",
                signer: userWallet
            })
            await expect(factoryNFT.upgrade("0", "10", signature))
                .to.be.revertedWith("Invalid signature");
        })

        it("upgrade should not be revert", async () => {
            //     // upgrade level to 10 level
            var signature = await sign({
                tokenId: "0",
                level: "1",
                signer: owner
            })
            await expect(factoryNFT.upgrade("0", "1", signature))
                .to.emit(factoryNFT, "LevelUp")
                .withArgs("0", "1");;
        })

    });

    describe("factoryStaking test", function () {
        it("stake should be revert", async () => {

            await expect(factoryStaking.stake("0", toBigNum(10001))).to.be.revertedWith("capacity is full!");
            await expect(factoryStaking.stake("0", toBigNum(3000))).to.be.revertedWith("ERC20: insufficient allowance");
            // await expect(factoryStaking.stake("0", toBigNum(301))).to.be.revertedWith("capacity limited");
        })

        it("stake", async function () {
            await mainToken.approve(factoryStaking.address, toBigNum(10000000));
            // admin receive 1.5% fee
            await expect(async () => (await factoryStaking.stake("0", toBigNum(3000)))).to.changeTokenBalance(
                mainToken,
                factoryStaking,
                toBigNum(2850)
            );
        });

        it("stake with other account", async function () {
            await mainToken.transfer(userWallet.address, toBigNum(1e6));
            await mainToken.connect(userWallet).approve(factoryStaking.address, toBigNum(10000000));
            await expect(async () => (await factoryStaking.connect(userWallet).stake("0", toBigNum(3000)))).to.changeTokenBalance(
                mainToken,
                factoryStaking,
                toBigNum(2850)
            );
        });

        it("reward test - full reward", async () => {
            await owner.sendTransaction({ to: factoryStaking.address, value: toBigNum(100) });
            await mainToken.transfer(factoryStaking.address, toBigNum(20000));
            var poolBalance = await mainToken.balanceOf(factoryStaking.address);
            expect(poolBalance).to.be.equal(toBigNum(2850 + 2850 + 20000))

            // check claimableAmount
            await factoryStaking.claimReward();
            var claimableAmounts = await factoryStaking.getClaimableAmounts(owner.address);
            console.log("claimableAmounts", fromBigNum(claimableAmounts.pendingReward), fromBigNum(claimableAmounts.pendingRewardETH));

            // one year time pass
            await network.provider.send("evm_increaseTime", [3600 * 24 * 365])
            await network.provider.send("evm_mine");
            await factoryStaking.updatePool();

            var poolBalance = await mainToken.balanceOf(factoryStaking.address);
            console.log("poolBalance", fromBigNum(poolBalance));

            // check claimableAmount
            var claimableAmounts = await factoryStaking.getClaimableAmounts(owner.address);
            console.log("claimableAmounts", fromBigNum(claimableAmounts.pendingReward), fromBigNum(claimableAmounts.pendingRewardETH));

            await factoryStaking.claimReward();

            var claimableAmounts = await factoryStaking.getClaimableAmounts(owner.address);
            console.log("claimableAmounts", fromBigNum(claimableAmounts.pendingReward), fromBigNum(claimableAmounts.pendingRewardETH));

            // console.log("stake rate", fromBigNum(await factoryStaking.getRate(), 6) / 0.9);
        })

        // it("check balance", async () => {
        //     var poolBalance = await mainToken.balanceOf(factoryStaking.address);
        //     expect(poolBalance).to.be.equal(toBigNum(2700))
        //     // time pass
        //     await network.provider.send("evm_increaseTime", [3600 * 24 * 365])
        //     await network.provider.send("evm_mine");
        //     await factoryStaking.updatePool();

        //     var poolBalance = await mainToken.balanceOf(factoryStaking.address);
        //     console.log("poolBalance", fromBigNum(poolBalance));

        //     console.log("stake rate", fromBigNum(await factoryStaking.getRate(), 6) / 0.9);
        // })
        // it("unstake", async function () {
        //     await factoryStaking.unstake("0", toBigNum(3000));
        //     var poolBalance = await mainToken.balanceOf(factoryStaking.address);
        //     console.log("poolBalance", fromBigNum(poolBalance));
        // });
    });

}

if (isDeploy)
    describe("Save contracts", function () {
        it("save abis", async function () {
            const abis = {
                tankNFT: artifacts.readArtifactSync("PurchasableNFT").abi,
                itemNFT: artifacts.readArtifactSync("PurchasableNFT").abi,
                factoryNFT: artifacts.readArtifactSync("FactoryNFT").abi,
                factoryStaking: artifacts.readArtifactSync("FactoryStakingPool").abi,
                ERC20: artifacts.readArtifactSync("ERC20").abi,
            };
            await saveFiles("abis.json", JSON.stringify(abis, undefined, 4));
        });
        it("save addresses", async function () {
            const addresses = {
                tankNFT: tankNFT.address,
                itemNFT: itemNFT.address,
                factoryNFT: factoryNFT.address,
                factoryStaking: factoryStaking.address,
                mainToken: mainToken.address
            };
            await saveFiles(
                "addresses.json",
                JSON.stringify(addresses, undefined, 4)
            );
        });
    });

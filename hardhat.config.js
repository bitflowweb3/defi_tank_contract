require("dotenv").config();
require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
// require("./tasks");
// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
    const accounts = await ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

// task("check-price", "", async (taskArgs, hre) => {
//     const [owner] = await ethers.getSigners();
//     const Factory = await ethers.getContractFactory("Marketplace");
//     const marketplace = await Factory.attach("0x19c82A352995424Ec6783D18a52c78220A7E60A9");
//     let data = await marketplace.orderByAssetId("0x5017a7f8B89b1eE16DEeE58A8a17Ba4e35060378", "5");
//     console.log(data);

// })

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
    networks: {
        localhost: {
            url: "http://127.0.0.1:8545",
        },
        ganache: {
            url: "http://127.0.0.1:7545",
        },
        fantom_test: {
            url: "https://rpc.testnet.fantom.network",
            accounts: [process.env.PRIVATEKEY, process.env.PRIVATEKEY1],
        },
        ethereum: {
            url: "https://main-light.eth.linkpool.io/",
            accounts: [process.env.PRIVATEKEY, process.env.PRIVATEKEY1],
        },
        bsc: {
            url: "https://bsc-dataseed1.ninicoin.io/",
            accounts: [process.env.PRIVATEKEY, process.env.PRIVATEKEY1],
        },
        matic: {
            url: "https://rpc-mainnet.matic.quiknode.pro",
            accounts: [process.env.PRIVATEKEY, process.env.PRIVATEKEY1],
        },
        fantom: {
            url: "https://rpc.ftm.tools/",
            accounts: [process.env.PRIVATEKEY, process.env.PRIVATEKEY1],
        },
        btc: {
            url: "https://rpc.bitcoinevm.co",
            accounts: [process.env.PRIVATEKEY, process.env.PRIVATEKEY1],
        },
        btc_test: {
            url: "https://test-rpc.bitcoinevm.co",
            accounts: [process.env.PRIVATEKEY, process.env.PRIVATEKEY1],
        },
        evmos_test: {
            url: "https://eth.bd.evmos.dev:8545",
            accounts: [process.env.PRIVATEKEY, process.env.PRIVATEKEY1]
        },
        evmos: {
            url: "https://eth.bd.evmos.org:8545",
            accounts: [process.env.PRIVATEKEY, process.env.PRIVATEKEY1]
        },
        arbitrum: {
            url: "https://arb1.arbitrum.io/rpc",
            accounts: [process.env.PRIVATEKEY, process.env.PRIVATEKEY1]
        },
        arbitrum_test: {
            url: "https://goerli-rollup.arbitrum.io/rpc",
            accounts: [process.env.PRIVATEKEY, process.env.PRIVATEKEY1]
        },
        goerli: {
            url: "https://goerli.blockpi.network/v1/rpc/public",
            accounts: [process.env.PRIVATEKEY, process.env.PRIVATEKEY1]
        }
    },
    etherscan: {
        // Your API key for Etherscan
        // Obtain one at https://etherscan.io/
        apiKey: "FI27Y8VM914JFI2PEZYFIMS52MQMHAB39X",
        additionalNetworks: {
            fantom: "3HMXDW64W5YNGASV2C84FDTJ2VHMW6J7WQ",
            fantom_test: "3HMXDW64W5YNGASV2C84FDTJ2VHMW6J7WQ",
        }
    },
    solidity: {
        compilers: [
            {
                version: "0.6.12",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
            {
                version: "0.8.10",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    mocha: {
        timeout: 200000,
    },
};

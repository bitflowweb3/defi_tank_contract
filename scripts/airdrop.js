
const fs = require('fs');

const path = require('path');
const { parse } = require('csv-parse');
const { saveFiles } = require('./utils');

const holderInfos = require("../resources/holders/holders.json")
const sholderInfos = require("../resources/holders/sortedholderInfos.json")
const filters = require("../resources/holders/filter.json")
const stakerInfos = require("../resources/holders/stakers.json")

const parseJson = () => {
    const csvFilePath = path.resolve(__dirname, '../resources/holders/holders.csv');

    const headers = ['HolderAddress', 'Balance', 'PendingBalanceUpdate'];

    const fileContent = fs.readFileSync(csvFilePath, { encoding: 'utf-8' });

    parse(fileContent, {
        delimiter: ',',
        columns: headers,
    }, (error, result) => {
        if (error) {
            console.error(error);
        }
        saveFiles("../resources/holders/holders.json", JSON.stringify(result, undefined, 4))
        console.log("Result", result);
    });
};

const sortInfos = () => {
    const sortedholderInfos = holderInfos.sort((a, b) => {
        return Number(b.Balance) - Number(a.Balance)
    })
    console.log("sortedholderInfos", sortedholderInfos);
    saveFiles("../resources/holders/sortedholderInfos.json", JSON.stringify(sortedholderInfos, undefined, 4))
}

const filterInfos = () => {
    var totalAmount = 0
    var filterholderInfos = sholderInfos.filter((i) => {
        if (Number(i.Balance) < 100) return false
        return !filters.includes(i.HolderAddress)
    })

    // add staker info
    var stakerInfo = stakerInfos.map((i) => {
        return {
            "HolderAddress": i.address,
            "Balance": (i.balance * 1.164 / 0.9).toFixed(0)
        }
    })
    filterholderInfos = [...filterholderInfos, ...stakerInfo];

    filterholderInfos = filterholderInfos.map((i) => {
        totalAmount += Number(Number(i.Balance).toFixed(0))
        return { "HolderAddress": i.HolderAddress, "Balance": Number(i.Balance).toFixed(0), "USD": Number((Number(i.Balance).toFixed(0) * 0.05).toFixed(0)) }
    })
    console.log("count", filterholderInfos.length, totalAmount, totalAmount * 0.05);
    // console.log("filterholderInfos", filterholderInfos);
    saveFiles("../resources/holders/filterholderInfos.json", JSON.stringify(filterholderInfos, undefined, 4))
}


filterInfos()
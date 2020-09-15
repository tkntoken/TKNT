import axios from 'axios';

global.network = process.env.NODE_ENV || 'development';
const testEnvironment = global.network;
import configFile from './config';

const URL = configFile.api[testEnvironment];

console.log("\nPointing to : " + URL)

const config = {
    headers : {
        "Content-Type" : "application/json"
    }
}

module.exports = {
    async addBlockchainInformation(params, bearerToken){
        return axios
        .post(`${URL}/api/app/addBlockchainInformation/`, params , addSecurityHeader(config, bearerToken))
        .then(res => {return res.data})
        .catch(error => {throw error});
    },
};


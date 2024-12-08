const Web3 = require('web3').Web3;
const web3 = new Web3('wss://rpc.blast.io');
const contractABI = require('./abi/AuraAbi.json');


const contractAddress = "0xb1a5700fa2358173fe465e6ea4ff52e36e88e2ad";
const contract = new web3.eth.Contract(contractABI, contractAddress);


const startEventListener = () => {
    console.log("Starting event listener for Approval events...");

    try {
        contract.events.Approval({})
            .on('data', (event) => {
                console.log("Approval event received:", event);
                const { owner, spender, value } = event.returnValues;
                console.log(`Owner: ${owner}, Spender: ${spender}, Value: ${value}`);
            })
            .on('error', (error) => {
                console.error("Error in event listener:", error);
                console.log("Reconnecting in 5 seconds...");
                setTimeout(startEventListener, 5000);
            });
    } catch (error) {
        console.error("Error setting up the event listener:", error);
    }
};

startEventListener();
const fs = require('fs');
const csv = require('csv-parser');

const WOBx_SWAP_TYPES = ['Swap Wob For Wobx', 'Swap Wobx For Wob'];

let transactions = [];

// Read and parse the CSV file
fs.createReadStream('wob-export-202406242200.csv')
  .pipe(csv())
  .on('data', (row) => {
    transactions.push({
      transactionHash: row['Transaction Hash'],
      blockno: row.Blockno,
      unixTimestamp: parseInt(row.UnixTimestamp, 10),
      dateTime: row['DateTime (UTC)'],
      from: row.From,
      to: row.To,
      quantity: parseFloat(row.Quantity.replace(/,/g, '')),
      method: row.Method
    });
  })
  .on('end', () => {
    console.log('CSV file successfully processed');
    processTransactions(transactions);
  });

function processTransactions(transactions) {
  transactions.sort((a, b) => a.unixTimestamp - b.unixTimestamp);

  let walletHoldings = {};

  transactions.forEach((tx) => {
    const timestamp = new Date(tx.unixTimestamp * 1000);

    // Ignore specific swap transactions
    if (WOBx_SWAP_TYPES.includes(tx.method)) {
      return;
    }

    if (tx.from !== '0x0000000000000000000000000000000000000000') {
      updateWalletHoldings(walletHoldings, tx.from, timestamp, tx.quantity, false);
    }

    updateWalletHoldings(walletHoldings, tx.to, timestamp, tx.quantity, true);
  });

 // console.log(walletHoldings);
}

function updateWalletHoldings(walletHoldings, wallet, timestamp, quantity, isInflow) {
  if (!walletHoldings[wallet]) {
    walletHoldings[wallet] = [];
  }

  if (isInflow) {
    walletHoldings[wallet].push({ timestamp, quantity });
  } else {
    let remainingQuantity = quantity;

    while (remainingQuantity > 0 && walletHoldings[wallet].length > 0) {
      let holding = walletHoldings[wallet][0];

      if (holding.quantity <= remainingQuantity) {
        let duration = timestamp - holding.timestamp;
        remainingQuantity -= holding.quantity;
        walletHoldings[wallet].shift();

        console.log(`Wallet ${wallet} held ${holding.quantity} tokens for ${duration / (1000 * 60)} minutes`);
      } else {
        let duration = timestamp - holding.timestamp;
        holding.quantity -= remainingQuantity;
        console.log(`Wallet ${wallet} held ${remainingQuantity} tokens for ${duration / (1000 * 60)} minutes`);
        remainingQuantity = 0;
      }
    }
  }
}
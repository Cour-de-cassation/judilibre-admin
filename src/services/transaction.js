const Elastic = require('../modules/elastic');

// TRANSACTION INTERFACES

async function toHistory(transactions) {
  const transactionsToIndex = transactions.map(fromElasticResultTotransaction);
  try {
    await indexTransactions(transactionsToIndex);
  } catch (e) {
    // TODO: Something has to be done on this error (reset the last action ? Send a mail ?)
    console.error(`${process.env.APP_ID}: Error creating inconsistencies`);
    console.error(`Transactions not created: ${JSON.stringify(transactions)}`);
    console.error(e);
  }
}

// TRANSACTION INSTRUCTIONS

async function indexTransactions(transactions) {
  return Elastic.client.bulk({
    body: transactions.flatMap((transaction) => [{ index: { _index: process.env.TRANSACTION_INDEX } }, transaction]),
  });
}

// DECISION FORMATS (INPUT)

function fromElasticResultTotransaction({ _id, result }) {
  return {
    id: _id,
    action: result,
    date: new Date(),
  };
}

// EXPORTS

module.exports = {
  toHistory,
};

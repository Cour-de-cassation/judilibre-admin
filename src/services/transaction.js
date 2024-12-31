const Elastic = require('../modules/elastic');

// TRANSACTION INTERFACES

async function toHistory(transactions) {
  const transactionsToIndex = transactions.map(fromElasticResultTotransaction);
  const {
    body: { items: transactionsItems },
  } = await indexTransactions(transactionsToIndex);
  return TransactionToHistoricized(transactionsItems, transactions);
}

// TRANSACTION INSTRUCTIONS

function indexTransactions(transactions) {
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

// DECISION FORMATS (OUTPUT)

function TransactionToHistoricized(transactionsItems, inputs) {
  return transactionsItems.map((item, iterator) => ({ item, input: inputs[iterator] }))
}

// EXPORTS

module.exports = {
  toHistory,
};

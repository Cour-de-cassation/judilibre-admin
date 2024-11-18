const Elastic = require('../modules/elastic');

async function toHistory(transactions) {
  const transactionsToIndex = transactions.map(fromElasticResultTotransaction);
  try {
    await indexTransactions(transactionsToIndex);
  } catch (e) {
    console.error();
  }
}

function fromElasticResultTotransaction({ _id, result }) {
  return {
    id: _id,
    action: result,
    date: new Date()
  };
}

async function indexTransactions(transactions) {
  return Elastic.client.bulk({
    body: transactions.flatMap(({ id, ...transaction }) => [
      { index: { _id: id, _index: process.env.TRANSACTION_INDEX } },
      transaction,
    ]),
  });
}

module.exports = {
  toHistory,
};

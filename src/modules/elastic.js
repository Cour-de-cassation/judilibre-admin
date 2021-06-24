require('./env');

class Elastic {
  constructor() {
    if (!process.env.WITHOUT_ELASTIC) {
      const { Client } = require('@elastic/elasticsearch');
      this.client = new Client({ node: `${process.env.ELASTIC_NODE}`, ssl: { rejectUnauthorized: false } });
    }
  }
}

module.exports = new Elastic();

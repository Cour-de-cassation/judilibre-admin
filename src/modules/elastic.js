require('./env');
const { Client } = require('@elastic/elasticsearch');

class Elastic {
  constructor() {
    this.client = new Client({ node: `${process.env.ELASTIC_NODE}`, ssl: { rejectUnauthorized: false }});
  }
}

module.exports = new Elastic();

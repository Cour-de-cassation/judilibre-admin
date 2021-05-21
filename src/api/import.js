const express = require('express');
const api = express.Router();
const Elastic = require('../modules/elastic');
const pathId = 'import';

api.get(`/${pathId}/:query`, async (req, res) => {
  res.header('Content-Type', 'application/json');
  res.send(JSON.stringify(await getImport(req.params.query)));
});

async function getImport(query) {
  return {
    path: pathId,
    query: query,
  };
}

module.exports = api;

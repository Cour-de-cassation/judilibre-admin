require('../modules/env');
const express = require('express');
const api = express.Router();
const Elastic = require('../modules/elastic');
const pathId = 'admin';

api.get(`/${pathId}/:query`, async (req, res) => {
  res.header('Content-Type', 'application/json');
  res.send(JSON.stringify(await getAdmin(req.params.query)));
});

async function getAdmin(query) {
  return {
    path: pathId,
    query: query,
  };
}

module.exports = api;

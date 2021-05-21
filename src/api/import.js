require('../modules/env');
const express = require('express');
const api = express.Router();
const Elastic = require('../modules/elastic');
const route = 'import';

api.post(`/${route}/:query`, async (req, res) => {
  try {
    const result = await postImport(req.params.query);
    res.status(200).json(result);
  } catch (e) {
    res.status(500).json({ route: route, message: 'Internal Server Error', error: e.message });
  }
});

async function postImport(query) {
  return {
    route: route,
    query: query,
  };
}

module.exports = api;

/*
var indexationStatus = 500
    if (req.body) {
      var index = req.body.index
      var decision = req.body.document
      if (decision && decision.pseudoText && decision.zoning && decision.zoning.zones) {
	  try {
		await indexDecision(index, decision)
		indexationStatus = 200
	  } catch (ignore) { }
      }
    }
    res.sendStatus(indexationStatus)
*/

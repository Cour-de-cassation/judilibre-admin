require('../modules/env');
const fs = require('fs');
const path = require('path');
const express = require('express');
const api = express.Router();
const { checkSchema, validationResult } = require('express-validator');
const Elastic = require('../modules/elastic');
const route = 'patch';
const patches = ['reset_particular_interest'];

api.get(
  `/${route}`,
  checkSchema({
    patch: {
      in: 'query',
      isString: true,
      toLowerCase: true,
      isIn: {
        options: [patches],
      },
      errorMessage: `The patch parameter is required and its value must be in [${patches}].`,
      optional: false,
    },
  }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ route: `${req.method} ${req.path}`, errors: errors.array() });
    }
    try {
      const result = await getPatch(req.query);
      if (result.errors) {
        return res.status(400).json({
          route: `${req.method} ${req.path}`,
          errors: result.errors,
        });
      }
      return res.status(200).json(result);
    } catch (e) {
      console.log(e.meta.body);
      console.error(e);
      return res.status(500).json({
        route: `${req.method} ${req.path}`,
        errors: [{ msg: 'Internal Server Error', error: JSON.stringify(e, e ? Object.getOwnPropertyNames(e) : null) }],
      });
    }
  },
);

async function getPatch(query) {
  const response = {
    route: `GET /${route}`,
    patch: query.patch,
    done: null,
    result: null,
  };
  switch (query.patch) {
    case 'reset_particular_interest':
      try {
        const updateResult = await Elastic.client.updateByQuery({
          index: process.env.ELASTIC_INDEX,
          refresh: true,
          body: {
            script: {
              lang: 'painless',
              source: 'ctx._source.particularInterest = false',
            },
          },
        });
        response.result = updateResult.body;
        response.done = true;
      } catch (e) {
        response.result = e;
        response.done = false;
      }
  }
  return response;
}

module.exports = api;

require('../modules/env');
const express = require('express');
const api = express.Router();
const { checkSchema, validationResult } = require('express-validator');
const Elastic = require('../modules/elastic');
const route = 'delete';

api.post(
  `/${route}`,
  checkSchema({
    id: {
      in: 'body',
      isString: true,
      errorMessage: `Request has no id.`,
      optional: false,
    },
  }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ route: `${req.method} ${req.path}`, errors: errors.array() });
    }
    try {
      const result = await postDelete(req.body);
      if (result.errors) {
        return res.status(400).json({
          route: `${req.method} ${req.path}`,
          errors: result.errors,
        });
      }
      return res.status(200).json(result);
    } catch (e) {
      return res.status(500).json({
        route: `${req.method} ${req.path}`,
        errors: [{ msg: 'Internal Server Error', error: JSON.stringify(e, e ? Object.getOwnPropertyNames(e) : null) }],
      });
    }
  },
);

api.post(
  `/${route}Many`,
  checkSchema({
    id: {
      in: 'body',
      toArray: true,
    },
    'id.*': {
      in: 'body',
      isString: true,
      errorMessage: `id  must be an array of strings.`,
      optional: false,
    },
  }),
  async (req, res) => {
    const t0 = new Date();
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ route: `${req.method} ${req.path}`, errors: errors.array() });
    }
    try {
      const result = await postDeleteMany(req.body.id);
      const t1 = new Date();
      result.took = t1.getTime() - t0.getTime();
      return res.status(200).json(result);
    } catch (e) {
      return res.status(500).json({
        route: `${req.method} ${req.path}`,
        errors: [{ msg: 'Internal Server Error', error: JSON.stringify(e, e ? Object.getOwnPropertyNames(e) : null) }],
      });
    }
  },
);

async function postDeleteMany(ids) {
  const response = {};
  for (let i = 0; i < ids.length; i++) {
    const id = ids[i];
    try {
      const result = await deleteDecision(id);
      if (result === true) {
        response[id] = true;
      } else {
        response[id] = false;
      }
    } catch (e) {
      response[id] = false;
      console.error(`${process.env.APP_ID}: Error in '${route}Many' API while processing decision ${id}`);
      console.error(e);
    }
  }
  return response;
}

async function postDelete(query) {
  let response = {};
  if (query && query.id) {
    response.id = query.id;
    try {
      const result = await deleteDecision(query.id);
      if (result === true) {
        response.deleted = true;
      } else {
        response.deleted = false;
        response.reason = result;
      }
    } catch (e) {
      response.deleted = false;
      response.reason = JSON.stringify(e, e ? Object.getOwnPropertyNames(e) : null);
      console.error(`${process.env.APP_ID}: Error in '${route}' API while processing decision ${query.id}`);
      console.error(e);
    }
  }
  return response;
}

async function deleteDecision(id) {
  const response = await Elastic.client.delete({
    id: id,
    index: process.env.ELASTIC_INDEX,
    refresh: true,
  });
  if (response && response.body && response.body.result === 'deleted') {
    return true;
  }
  return response;
}

module.exports = api;

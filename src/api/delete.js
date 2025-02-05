/**
 * TODO: Wich service use this ? I would like to use "DELETE" http verb to make a delete.
 */

require('../modules/env');
const express = require('express');
const api = express.Router();
const { checkSchema, validationResult } = require('express-validator');
const { toUnpublish } = require('../services/decision');

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
      const result = await toUnpublish([req.body.id]);
      if (!result.deleted) {
        return res.status(400).json({
          route: `${req.method} ${req.path}`,
          errors: result,
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
      const result = await toUnpublish(req.body.id);
      const response = {
        ...result,
        took: new Date().getTime() - t0.getTime(),
      };
      return res.status(200).json(response);
    } catch (e) {
      return res.status(500).json({
        route: `${req.method} ${req.path}`,
        errors: [{ msg: 'Internal Server Error', error: JSON.stringify(e, e ? Object.getOwnPropertyNames(e) : null) }],
      });
    }
  },
);

module.exports = api;

require('../modules/env');
const express = require('express');
const api = express.Router();
const { checkSchema, validationResult } = require('express-validator');
const route = 'import';
const { toPublish } = require('../services/decision');

api.post(
  `/${route}`,
  checkSchema({
    id: {
      in: 'body',
      isString: true,
      errorMessage: `Request has no id.`,
      optional: false,
    },
    decisions: {
      in: 'body',
      isArray: true,
      notEmpty: true,
      errorMessage: `Request has no decision.`,
      optional: false,
    },
    'decisions.*.chamber': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no chamber.`,
      optional: true,
    },
    'decisions.*.decision_date': {
      in: 'body',
      isISO8601: true,
      errorMessage: `Decision has no date.`,
      optional: false,
    },
    'decisions.*.id': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no id.`,
      optional: false,
    },
    'decisions.*.version': {
      in: 'body',
      isFloat: true,
      errorMessage: `Decision has no version number.`,
      optional: true,
    },
    'decisions.*.source': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no source.`,
      optional: false,
    },
    'decisions.*.sourceId': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no sourceId.`,
      optional: false,
    },
    'decisions.*.jurisdiction': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no jurisdiction.`,
      optional: false,
    },
    'decisions.*.number': {
      in: 'body',
      toArray: true,
    },
    'decisions.*.number.*': {
      in: 'body',
      isString: true,
      errorMessage: `Decision.number must be an array of strings.`,
      optional: false,
    },
    'decisions.*.publication': {
      in: 'body',
      toArray: true,
    },
    'decisions.*.publication.*': {
      in: 'body',
      isString: true,
      toLowerCase: true,
      errorMessage: `Decision.publication must be an array of strings.`,
      optional: true,
    },
    'decisions.*.solution': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no solution.`,
      optional: true,
    },
    'decisions.*.type': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no type.`,
      optional: true,
    },
    'decisions.*.text': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no text.`,
      optional: false,
    },
    'decisions.*.displayText': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no display text.`,
      optional: false,
    },
    'decisions.*.location': {
      in: 'body',
      isString: true,
      errorMessage: `Decision.location must be a string.`,
      optional: true,
    },
    'decisions.*.ecli': {
      in: 'body',
      isString: true,
      errorMessage: `Decision.ecli must be a string.`,
      optional: true,
    },
    'decisions.*.formation': {
      in: 'body',
      isString: true,
      errorMessage: `Decision.formation must be a string.`,
      optional: true,
    },
    'decisions.*.zones': {
      in: 'body',
      isObject: true,
      errorMessage: `Decision.zones must be an object.`,
      optional: true,
    },
    'decisions.*.nac': {
      in: 'body',
      isString: true,
      errorMessage: `Decision.nac must be a string.`,
      optional: true,
    },
    'decisions.*.portalis': {
      in: 'body',
      isString: true,
      errorMessage: `Decision.portalis must be a string.`,
      optional: true,
    },
    'decisions.*.update_date': {
      in: 'body',
      isISO8601: true,
      errorMessage: `Decision.update_date must be a ISO-8601 date (e.g. 2021-05-13).`,
      optional: true,
    },
    'decisions.*.visa': {
      in: 'body',
      isArray: true,
      errorMessage: `Decision.visa must be an array.`,
      optional: true,
    },
    'decisions.*.rapprochements': {
      in: 'body',
      isArray: true,
      errorMessage: `Decision.rapprochements must be an array.`,
      optional: true,
    },
    'decisions.*.contested': {
      in: 'body',
      isObject: true,
      errorMessage: `Decision.contested must be an object.`,
      optional: true,
    },
    'decisions.*.forward': {
      in: 'body',
      isObject: true,
      errorMessage: `Decision.forward must be an object.`,
      optional: true,
    },
    'decisions.*.timeline': {
      in: 'body',
      isArray: true,
      errorMessage: `Decision.timeline must be an array.`,
      optional: true,
    },
    'decisions.*.solution_alt': {
      in: 'body',
      isString: true,
      errorMessage: `Decision.solution_alt must be a string.`,
      optional: true,
    },
    'decisions.*.summary': {
      in: 'body',
      isString: true,
      errorMessage: `Decision.summary must be a string.`,
      optional: true,
    },
    'decisions.*.bulletin': {
      in: 'body',
      isString: true,
      errorMessage: `Decision.bulletin must be a string.`,
      optional: true,
    },
    'decisions.*.files': {
      in: 'body',
      isArray: true,
      errorMessage: `Decision.files must be an array.`,
      optional: true,
    },
    'decisions.*.themes': {
      in: 'body',
      isArray: true,
      errorMessage: `Decision.themes must be an array.`,
      optional: true,
    },
    'decisions.*.lowInterest': {
      in: 'body',
      isBoolean: true,
      toBoolean: true,
      errorMessage: `Decision.lowInterest must be a boolean.`,
      optional: true,
    },
    'decisions.*.partial': {
      in: 'body',
      isBoolean: true,
      toBoolean: true,
      errorMessage: `Decision.partial must be a boolean.`,
      optional: true,
    },
    'decisions.*.legacy': {
      in: 'body',
      isObject: true,
      errorMessage: `Decision.legacy must be an object.`,
      optional: true,
    },
    'decisions.*.decision_datetime': {
      in: 'body',
      isISO8601: true,
      errorMessage: `Decision has no datetime.`,
      optional: false,
    },
    'decisions.*.update_datetime': {
      in: 'body',
      isISO8601: true,
      errorMessage: `Decision.update_datetime must be a ISO-8601 full date (e.g. 2021-05-13T06:00:00Z).`,
      optional: true,
    },
    'decisions.*.titlesAndSummaries': {
      in: 'body',
      isArray: true,
      errorMessage: `Decision.titlesAndSummaries must be an Array.`,
      optional: true,
    },
    'decisions.*.particularInterest': {
      in: 'body',
      isBoolean: true,
      toBoolean: true,
      errorMessage: `Decision.particularInterest must be a boolean.`,
      optional: true,
    },
  }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ route: `${req.method} ${req.path}`, errors: errors.array() });
    }
    try {
      const result = await toPublish(req.body.decisions);
      return res.status(200).json(result);
    } catch (e) {
      return res.status(500).json({
        route: `${req.method} ${req.path}`,
        errors: [{ msg: 'Internal Server Error', error: JSON.stringify(e, e ? Object.getOwnPropertyNames(e) : null) }],
      });
    }
  },
);

module.exports = api;

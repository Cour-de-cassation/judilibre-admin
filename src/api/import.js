require('../modules/env');
const express = require('express');
const api = express.Router();
const { checkSchema, validationResult } = require('express-validator');
const Elastic = require('../modules/elastic');
const route = 'import';

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
      optional: false,
    },
    'decisions.*.decision_date': {
      in: 'body',
      isISO8601: true,
      errorMessage: `Decision has no date.`,
      optional: false,
    },
    'decisions.*.ecli': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no ECLI.`,
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
      isInt: true,
      errorMessage: `Decision has no version number.`,
      optional: false,
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
      isString: true,
      errorMessage: `Decision has no number.`,
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
      optional: false,
    },
    'decisions.*.solution': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no solution.`,
      optional: false,
    },
    'decisions.*.text': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no text.`,
      optional: false,
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
      errorMessage: `Decision.zone must be an object.`,
      optional: true,
    },
    'decisions.*.nac': {
      in: 'body',
      isString: true,
      errorMessage: `Decision.nac must be a string.`,
      optional: true,
    },
    'decisions.*.update_date': {
      in: 'body',
      isISO8601: true,
      errorMessage: `Decision.update_date must be a ISO-8601 date (e.g. 2021-05-13).`,
      optional: true,
    },
    'decisions.*.applied': {
      in: 'body',
      isArray: true,
      errorMessage: `Decision.applied must be an array.`,
      optional: true,
    },
    'decisions.*.rapprochements': {
      in: 'body',
      isArray: true,
      errorMessage: `Decision.rapprochements must be an array.`,
      optional: true,
    },
    'decisions.*.solution_alt': {
      in: 'body',
      isString: true,
      optional: true,
    },
    'decisions.*.summary': {
      in: 'body',
      isString: true,
      optional: true,
    },
    'decisions.*.bulletin': {
      in: 'body',
      isString: true,
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
  }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ route: `${req.method} ${req.path}`, errors: errors.array() });
    }
    try {
      const result = await postImport(req.body);
      if (result.errors) {
        return res.status(400).json({
          route: `${req.method} ${req.path}`,
          errors: result.errors,
        });
      }
      return res.status(200).json(result);
    } catch (e) {
      return res
        .status(500)
        .json({ route: `${req.method} ${req.path}`, errors: [{ msg: 'Internal Server Error', error: e.message }] });
    }
  },
);

async function postImport(query) {
  const response = {
    indexed: [],
    not_indexed: [],
  };
  query.decisions.array.forEach(async (decision) => {
    try {
      const result = await indexDecision(decision);
      if (result.indexed) {
        response.indexed.push(decision.sourceId);
      } else {
        response.not_indexed.push(decision.sourceId);
      }
    } catch (e) {
      response.not_indexed.push(decision.sourceId);
      console.error(
        `JUDILIBRE-${process.env.APP_ID}: Error in '${route}' API while processing decision ${decision.sourceId}`,
      );
      console.error(e);
    }
  });
  return response;
}

async function indexDecision(decision) {
  const document = {};
  document.version = decision.version;
  document.source = decision.source;
  document.text = decision.text;
  document.textExact = decision.text;
  document.chamber = decision.chamber;
  document.decision_date = decision.decision_date;
  document.ecli = decision.ecli;
  document.jurisdiction = decision.jurisdiction;
  document.number = decision.number.replace(/[^\w\d]/gm, '').trim();
  document.numberFull = decision.number;
  document.publication = decision.publication;
  document.solution = decision.solution;
  /*
  if (zones['introduction_subzonage']['juridiction']) {
    document.jurisdictionName = zones['introduction_subzonage']['juridiction']
  }
  if (zones['introduction_subzonage']['chambre']) {
    document.chamberName = zones['introduction_subzonage']['chambre']
  }
  if (zones['visa'] !== null) {
    document.visa = zones['visa']
  }
  */
  if (decision.formation) {
    document.formation = decision.formation;
  }
  if (decision.nac) {
    document.nac = decision.nac;
  }
  if (decision.update_date) {
    document.update_date = decision.update_date;
  }
  if (decision.applied) {
    document.applied = decision.applied;
  }
  if (decision.rapprochements) {
    document.rapprochements = decision.rapprochements;
  }
  if (decision.solution_alt) {
    document.solution_alt = decision.solution_alt;
  }
  if (decision.summary) {
    document.summary = decision.summary;
  }
  if (decision.bulletin) {
    document.bulletin = decision.bulletin;
  }
  if (decision.files) {
    document.files = decision.files;
  }
  if (decision.themes) {
    document.themes = decision.themes;
  }
  if (decision.zones) {
    document.zones = decision.zones;
    document.zoneExpose = [];
    if (decision.zones['expose du litige']) {
      for (let i = 0; i < decision.zones['expose du litige'].length; i++) {
        let start = decision.zones['expose du litige'][i].start;
        let end = decision.zones['expose du litige'][i].end;
        document.zoneExpose.push(decision.text.substring(start, end).trim());
      }
    }
    document.zoneMoyens = [];
    if (decision.zones['moyens']) {
      for (let i = 0; i < decision.zones['moyens'].length; i++) {
        let start = decision.zones['moyens'][i].start;
        let end = decision.zones['moyens'][i].end;
        document.zoneMoyens.push(decision.text.substring(start, end).trim());
      }
    }
    document.zoneMotivations = [];
    if (decision.zones['motivations']) {
      for (let i = 0; i < decision.zones['motivations'].length; i++) {
        let start = decision.zones['motivations'][i].start;
        let end = decision.zones['motivations'][i].end;
        document.zoneMotivations.push(decision.text.substring(start, end).trim());
      }
    }
    document.zoneDispositif = [];
    if (decision.zones['dispositif']) {
      for (let i = 0; i < decision.zones['dispositif'].length; i++) {
        let start = decision.zones['dispositif'][i].start;
        let end = decision.zones['dispositif'][i].end;
        document.zoneDispositif.push(decision.text.substring(start, end).trim());
      }
    }
    document.zoneAnnexes = [];
    if (decision.zones['moyens annexes']) {
      for (let i = 0; i < decision.zones['moyens annexes'].length; i++) {
        let start = decision.zones['moyens annexes'][i].start;
        let end = decision.zones['moyens annexes'][i].end;
        document.zoneAnnexes.push(decision.text.substring(start, end).trim());
      }
    }
  }

  const response = await Elastic.client.index({
    id: decision.id,
    index: process.env.ELASTIC_INDEX,
    body: document,
  });

  if (response && response.body && (response.body.result === 'created' || response.body.result === 'updated')) {
    return true;
  }
  return false;
}

module.exports = api;

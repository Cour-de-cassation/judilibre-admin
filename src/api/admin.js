/**
 * TODO: Is this really used ? Guess it could be deleted to simplify readability
 */

require('../modules/env');
const fs = require('fs');
const path = require('path');
const express = require('express');
const api = express.Router();
const { checkSchema, validationResult } = require('express-validator');
const Elastic = require('../modules/elastic');
const route = 'admin';
const commands = ['delete_all', 'refresh_template', 'show_template', 'show_all_templates', 'test'];

api.get(
  `/${route}`,
  checkSchema({
    command: {
      in: 'query',
      isString: true,
      toLowerCase: true,
      isIn: {
        options: [commands],
      },
      errorMessage: `The command parameter is required and its value must be in [${commands}].`,
      optional: false,
    },
  }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ route: `${req.method} ${req.path}`, errors: errors.array() });
    }
    try {
      const result = await getAdmin(req.query);
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

async function getAdmin(query) {
  const response = {
    route: `GET /${route}`,
    command: query.command,
    result: null,
  };
  switch (query.command) {
    case 'delete_all':
      /*
      try {
        const deleteResult = await Elastic.client.indices.delete({
          index: process.env.ELASTIC_INDEX,
        });
        response.result = deleteResult.body;
      } catch (e) {
        console.error(e);
        response.result = e;
      }
      */
      break;
    case 'refresh_template':
      try {
        const template = JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'config', 'template.json')));
        const templateTransaction = JSON.parse(
          fs.readFileSync(path.join(__dirname, '..', 'config', 'template_transaction.json')),
        );
        const refreshResult = await Elastic.client.indices.putTemplate({
          name: 't_judilibre',
          create: false,
          body: template,
        });
        const refreshResultTransaction = await Elastic.client.indices.putTemplate({
          name: 't_transaction',
          create: false,
          body: templateTransaction,
        });
        response.result = [refreshResult.body, refreshResultTransaction.body];
      } catch (e) {
        console.error(e);
        response.result = e;
      }
      break;
    case 'show_template':
      let expected = null;
      let actual = {
        body: null,
      };
      let error = null;
      try {
        expected = [
          JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'config', 'template.json'))),
          JSON.parse(fs.readFileSync(path.join(__dirname, '..', 'config', 'template_transaction.json'))),
        ];
        actual = await Promise.all([
          Elastic.client.indices.getTemplate({
            name: 't_judilibre',
          }),
          Elastic.client.indices.getTemplate({
            name: 't_transaction',
          }),
        ]);
      } catch (e) {
        console.error(e);
        error = e;
      }
      response.result = {
        expected: expected,
        actual: actual.map(_ => _.body),
        error: error,
      };
      break;
    case 'show_all_templates':
      let allTemplates = {
        body: null,
      };
      let allTemplatesError = null;
      try {
        allTemplates = await Elastic.client.indices.getTemplate({
          name: '*',
        });
      } catch (e) {
        console.error(e);
        allTemplatesError = e;
      }
      response.result = {
        templates: allTemplates.body,
        error: allTemplatesError,
      };
      break;
    case 'test':
      try {
        const ping = await Elastic.client.ping({});
        if (ping.body === true && ping.statusCode === 200) {
          response.result = 'disponible';
        } else {
          response.result = 'indisponible';
        }
      } catch (e) {
        console.error(e);
        response.result = 'indisponible';
      }
      break;
  }
  return response;
}

module.exports = api;

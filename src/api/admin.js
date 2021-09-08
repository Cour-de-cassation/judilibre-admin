require('../modules/env');
const fs = require('fs');
const path = require('path');
const express = require('express');
const api = express.Router();
const { checkSchema, validationResult } = require('express-validator');
const Elastic = require('../modules/elastic');
const route = 'admin';
const commands = ['delete_all', 'refresh_template', 'test'];

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
      return res
        .status(500)
        .json({ route: `${req.method} ${req.path}`, errors: [{ msg: 'Internal Server Error', error: e.message }] });
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
      const deleteResult = await Elastic.client.indices.delete({
        index: process.env.ELASTIC_INDEX,
      });
      response.result = deleteResult.body;
      break;
    case 'refresh_template':
      const template = JSON.parse(fs.readFileSync(path.join(__dirname, '..', '..', 'elastic', 'template-medium.json')));
      const refreshResult = await Elastic.client.indices.putTemplate({
        name: 't_judilibre',
        create: false,
        body: template,
      });
      response.result = refreshResult.body;
      break;
    case 'test':
      const ping = await Elastic.client.ping({});
      if (ping.body === true && ping.statusCode === 200) {
        response.result = 'disponible';
      } else {
        response.result = 'indisponible';
      }
      break;
  }
  return response;
}

module.exports = api;

require('../modules/env');
const express = require('express');
const api = express.Router();
const { toPublish } = require('../services/decision');
const joi = require('joi');

const route = 'import';

const zoneSchema = joi.array().items(
  joi.object({
    start: joi.number().precision(0).required(),
    end: joi.number().precision(0).required(),
  }),
);

const importInputSchema = joi.object({
  id: joi.string().required().messages({ id: 'Request has no id.' }),
  decisions: joi
    .array()
    .min(1)
    .items(
      joi.object({
        chamber: joi.string().messages({ 'decision.chamber': 'Decision chamber must be a string.' }),
        decision_date: joi
          .string()
          .isoDate()
          .required()
          .messages({ 'decision.decision_date': 'Decision has no date.' }),
        id: joi.string().required().messages({ 'decision.id': 'Decision has no id.' }),
        version: joi.number().messages({ 'decision.version': 'Decision version number must be a number.' }),
        source: joi.string().required().messages({ 'decision.source': 'Decision has no source.' }),
        sourceId: joi.string().required().messages({ 'decision.sourceId': 'Decision has no sourceId.' }),
        jurisdiction: joi.string().required().messages({ 'decision.jurisdiction': 'Decision has no jurisdiction.' }),
        number: joi
          .array()
          .min(1)
          .items(joi.string())
          .required()
          .messages({ 'decision.number': 'Decision.number must be an array of strings.' }),
        publication: joi
          .array()
          .items(joi.string().lowercase())
          .messages({ 'decision.publication': 'Decision.publication must be an array of lowercase strings.' }),
        solution: joi.string().messages({ 'decision.solution': 'Decision solution must be a string.' }),
        type: joi.string().messages({ 'decision.type': 'Decision type must be a string.' }),
        text: joi.string().required().messages({ 'decision.text': 'Decision has no text.' }),
        displayText: joi.string().required().messages({ 'decision.displayText': 'Decision has no display text.' }),
        location: joi.string().messages({ 'decision.location': 'Decision.location must be a string.' }),
        ecli: joi.string().messages({ 'decision.ecli': 'Decision.ecli must be a string.' }),
        formation: joi.string().messages({ 'decision.formation': 'Decision.formation must be a string.' }),
        zones: joi.object({
          introduction: zoneSchema.messages({
            'decision.introduction':
              'Decision.zones.introduction must be an array of including start and end as integer.',
          }),
          expose: zoneSchema.messages({
            'decision.expose': 'Decision.zones.expose must be an array of including start and end as integer.',
          }),
          moyens: zoneSchema.messages({
            'decision.moyens': 'Decision.zones.moyens must be an array of including start and end as integer.',
          }),
          motivations: zoneSchema.messages({
            'decision.motivations': 'Decision.zones.motivations must be an array of including start and end as integer.',
          }),
          dispositif: zoneSchema.messages({
            'decision.dispositif': 'Decision.zones.dispositif must be an array of including start and end as integer.',
          }),
          annexes: zoneSchema.messages({
            'decision.annexes': 'Decision.zones.annexes must be an array of including start and end as integer.',
          }),
        }),
        nac: joi.string().messages({ 'decision.nac': 'Decision.nac must be a string.' }),
        portalis: joi.string().messages({ 'decision.portalis': 'Decision.portalis must be a string.' }),
        update_date: joi
          .string()
          .isoDate()
          .messages({ 'decision.update_date': 'Decision.update_date must be a ISO-8601 date (e.g. 2021-05-13).' }), // example is not iso date
        visa: joi.array(),
        rapprochements: joi.array(),
        contested: joi.object(),
        forward: joi.object(),
        timeline: joi.array(),
        solution_alt: joi.string().messages({ 'decision.solution_alt': 'Decision.solution_alt must be a string.' }),
        summary: joi.string().messages({ 'decision.summary': 'Decision.summary must be a string.' }),
        bulletin: joi.string().messages({ 'decision.bulletin': 'Decision.bulletin must be a string.' }),
        files: joi.array(),
        themes: joi.array(),
        lowInterest: joi.boolean().messages({ 'decision.lowInterest': 'Decision.lowInterest must be a boolean.' }), // toBoolean: true ?
        partial: joi.boolean().messages({ 'decision.partial': 'Decision.partial must be a boolean.' }), // toBoolean: true ?
        legacy: joi.object(),
        decision_datetime: joi
          .string()
          .isoDate()
          .required()
          .messages({ 'decision.decision_datetime': 'Decision has no datetime.' }),
        update_datetime: joi
          .string()
          .isoDate()
          .messages({
            'decision.update_datetime':
              'Decision.update_datetime must be a ISO-8601 full date (e.g. 2021-05-13T06:00:00Z).',
          }),
        titlesAndSummaries: joi.array(),
        particularInterest: joi
          .boolean()
          .messages({ 'decision.particularInterest': 'Decision.particularInterest must be a boolean.' }),
      }),
    )
    .required()
    .messages({ 'decisions': 'Request has no decision'}),
});

api.post(`/${route}`, async (req, res) => {
  try {
    const body = await importInputSchema.validateAsync(req.body, { abortEarly: false });
    const result = await toPublish(body);
    return res.status(200).json(result);
  } catch (e) {
    if (joi.isError(e)) return res.status(400).json({ route: `${req.method} ${req.path}`, errors: e });
    return res.status(500).json({
      route: `${req.method} ${req.path}`,
      errors: [{ msg: 'Internal Server Error', error: JSON.stringify(e, e ? Object.getOwnPropertyNames(e) : null) }],
    });
  }
});

module.exports = api;

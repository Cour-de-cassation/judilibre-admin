require('../modules/env');
const express = require('express');
const api = express.Router();
const { checkSchema, validationResult } = require('express-validator');
// const Elastic = require('../modules/elastic');
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
    'decisions.*.creation_date': {
      in: 'body',
      isISO8601: true,
      errorMessage: `Decision has no creation date.`,
      optional: false,
    },
    'decisions.*.ecli': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no ECLI.`,
      optional: false,
    },
    'decisions.*.formation': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no formation.`,
      optional: false,
    },
    'decisions.*.id': {
      in: 'body',
      isString: true,
      errorMessage: `Decision has no id.`,
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
      isString: true,
      errorMessage: `Decision has no publication.`,
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
  }),
  async (req, res) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ route: `${req.method} ${req.path}`, errors: errors.array() });
    }
    try {
      const result = await postImport(req.body);
      return res.status(200).json(result);
    } catch (e) {
      return res
        .status(500)
        .json({ route: `${req.method} ${req.path}`, errors: [{ msg: 'Internal Server Error', error: e.message }] });
    }
  },
);

async function postImport(query) {
  return {
    route: `POST /${route}`,
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
/*
async function indexDecision(index, decision) {
	const document = {}
	try {
		const zones = decision.zoning
		document.mongoId = decision._id
		document.version = decision._version
		document.sourceId = decision.sourceId
		document.sourceName = decision.sourceName.toLowerCase()
		document.zoning = decision.zoning
		if (decision.jurisdictionCode) {
			document.jurisdictionCode = decision.jurisdictionCode.toUpperCase()
		}
		if (zones['introduction_subzonage'] && zones['introduction_subzonage']['juridiction']) {
			document.jurisdictionName = zones['introduction_subzonage']['juridiction']
		}
		if (zones['introduction_subzonage'] && zones['introduction_subzonage']['pourvoi'] && zones['introduction_subzonage']['pourvoi'].length && zones['introduction_subzonage']['pourvoi'][0]) {
			let cleanedAppealNumber = zones['introduction_subzonage']['pourvoi'][0].split(/^\w\s/)[1]
			if (cleanedAppealNumber) {
				document.appealNumberFull = cleanedAppealNumber
				document.appealNumber = cleanedAppealNumber.replace(/[^\w\d]/gm, '').trim()
			}
		}
		if (decision.chamberId) {
			document.chamberId = decision.chamberId.toUpperCase()
		}
		if (zones['introduction_subzonage'] && zones['introduction_subzonage']['chambre']) {
			document.chamberName = zones['introduction_subzonage']['chambre']
		}
		if (decision.registerNumber) {
			document.registerNumber = decision.registerNumber
		}
		if (zones['introduction_subzonage'] && zones['introduction_subzonage']['formation']) {
			document.formation = zones['introduction_subzonage']['formation'].toUpperCase()
		}
		/ *
		if (zones['introduction_subzonage'] && zones['introduction_subzonage']['publication']) {
			document.pubCategory = zones['introduction_subzonage']['publication']
		}
		* /
		if (decision.pubCategory) {
			document.pubCategory = decision.pubCategory.toUpperCase()
		}
		const dDecision = new Date(decision.dateDecision)
		let day = dDecision.getDate()
		if (day < 10) {
			day = '0' + day
		}
		let month = dDecision.getMonth() + 1
		if (month < 10) {
			month = '0' + month
		}
		document.dateDecision = day + '/' + month + '/' + dDecision.getFullYear()
		if (decision.solution) {
			document.solution = decision.solution
		}
		document.fulltext = decision.pseudoText
		document.zoneExpose = []
		if (zones['zones'] && zones['zones']['expose du litige'] && zones['zones']['expose du litige'].length) {
			for (let i = 0; i < zones['zones']['expose du litige'].length; i++) {
				let start = zones['zones']['expose du litige'][i].start
				let end = zones['zones']['expose du litige'][i].end
				document.zoneExpose.push(decision.pseudoText.substring(start, end).trim())
			}
		} else if (zones['zones'] && zones['zones']['expose du litige'] && zones['zones']['expose du litige'].start && zones['zones']['expose du litige'].end) {
			let start = zones['zones']['expose du litige'].start
			let end = zones['zones']['expose du litige'].end
			document.zoneExpose.push(decision.pseudoText.substring(start, end).trim())
		}
		document.zoneMoyens = []
		if (zones['zones'] && zones['zones']['moyens'] && zones['zones']['moyens'].length) {
			for (let i = 0; i < zones['zones']['moyens'].length; i++) {
				let start = zones['zones']['moyens'][i].start
				let end = zones['zones']['moyens'][i].end
				document.zoneMoyens.push(decision.pseudoText.substring(start, end).trim())
			}
		} else if (zones['zones'] && zones['zones']['moyens'] && zones['zones']['moyens'].start && zones['zones']['moyens'].end) {
			let start = zones['zones']['moyens'].start
			let end = zones['zones']['moyens'].end
			document.zoneMoyens.push(decision.pseudoText.substring(start, end).trim())
		}
		document.zoneMotivation = []
		if (zones['zones'] && zones['zones']['motivations'] && zones['zones']['motivations'].length) {
			for (let i = 0; i < zones['zones']['motivations'].length; i++) {
				let start = zones['zones']['motivations'][i].start
				let end = zones['zones']['motivations'][i].end
				document.zoneMotivation.push(decision.pseudoText.substring(start, end).trim())
			}
		} else if (zones['zones'] && zones['zones']['motivations'] && zones['zones']['motivations'].start && zones['zones']['motivations'].end) {
			let start = zones['zones']['motivations'].start
			let end = zones['zones']['motivations'].end
			document.zoneMotivation.push(decision.pseudoText.substring(start, end).trim())
		}
		document.zoneDispositif = []
		if (zones['zones'] && zones['zones']['dispositif'] && zones['zones']['dispositif'].length) {
			for (let i = 0; i < zones['zones']['dispositif'].length; i++) {
				let start = zones['zones']['dispositif'][i].start
				let end = zones['zones']['dispositif'][i].end
				document.zoneDispositif.push(decision.pseudoText.substring(start, end).trim())
			}
		} else if (zones['zones'] && zones['zones']['dispositif'] && zones['zones']['dispositif'].start && zones['zones']['dispositif'].end) {
			let start = zones['zones']['dispositif'].start
			let end = zones['zones']['dispositif'].end
			document.zoneDispositif.push(decision.pseudoText.substring(start, end).trim())
		}
		document.zoneAnnexes = []
		if (zones['zones'] && zones['zones']['moyens annexes'] && zones['zones']['moyens annexes'].length) {
			for (let i = 0; i < zones['zones']['moyens annexes'].length; i++) {
				let start = zones['zones']['moyens annexes'][i].start
				let end = zones['zones']['moyens annexes'][i].end
				document.zoneAnnexes.push(decision.pseudoText.substring(start, end).trim())
			}
		} else if (zones['zones'] && zones['zones']['moyens annexes'] && zones['zones']['moyens annexes'].start && zones['zones']['moyens annexes'].end) {
			let start = zones['zones']['moyens annexes'].start
			let end = zones['zones']['moyens annexes'].end
			document.zoneAnnexes.push(decision.pseudoText.substring(start, end).trim())
		}
		if (decision.analysis) {
			if (decision.analysis.summary) {
				document.summary = decision.analysis.summary
			}
			if (decision.analysis.title) {
				document.title = decision.analysis.title
			}
		}
		if (zones['visa'] !== null) {
			document.visa = zones['visa']
		}
		const repindex = await client.index({
			id: decision._id,
			index: index,
			body: document
		})
		return true
	} catch (e) {
		return false
	}
}
*/

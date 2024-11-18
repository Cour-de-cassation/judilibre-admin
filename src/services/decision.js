const Elastic = require('../modules/elastic');
const { toHistory } = require('./transaction');

async function toPublish(decisions) {
  const decisionsToIndex = decisions.map(fromPayloadToDecision);
  const items = await indexDecisions(decisionsToIndex);
  toHistory(items.map(({ index }) => index)); // Warn: not controlled by API flux
  return fromIndexingToResponse(items);
}

function fromPayloadToDecision(decisionPayload) {
  // TODO: zones elements as array && zones.introduction elements with start and end should be validated by express schema validator
  // TODO: it should be safer with typescript
  const textZone = (zones) =>
    zones && Array.isArray(zones) && zones.map((zone) => decisionPayload.text.substring(start, end).trim());

  return {
    ...decisionPayload,
    number: decisionPayload.number.map((item) => item.replace(/[^\w\d]/gm, '').trim()),
    numberFull: decisionPayload.number,
    rapprochements: { value: decisionPayload.rapprochements },
    fileType: decisionPayload.files?.map((file) => {
      const type = file.type ? parseInt(type, 10) : -1;
      const codes = {
        1: 'prep_rapp',
        2: 'prep_avis',
        3: 'prep_oral',
        4: 'comm_comm',
        5: 'comm_note',
        6: 'comm_lett',
        7: 'comm_trad',
        8: 'comm_nora',
      };
      return codes[type] ? [codes[type]] : [];
    }),
    ...(decisionPayload.zones
      ? {
          zoneIntroduction: textZone(decisionPayload.zones['introduction']),
          zoneExpose: textZone(decisionPayload.zones['expose']),
          zoneMoyens: textZone(decisionPayload.zones['moyens']),
          zoneMotivations: textZone(decisionPayload.zones['motivations']),
          zoneDispositif: textZone(decisionPayload.zones['dispositif']),
          zoneAnnexes: textZone(decisionPayload.zones['annexes']),
        }
      : {}),
  };
}

function fromIndexingToResponse(indexingDecisions) {
  return indexingDecisions.reduce(
    (acc, { index: indexingDecision }) => {
      const error = indexingDecision.error;
      if (error) {
        console.error(
          `${process.env.APP_ID}: Error in 'publish' API while processing decision ${indexingDecision._id}`,
        ); // TODO: precise route ?
        console.error(error);
        return {
          indexed: acc.indexed,
          not_indexed: [
            ...acc.not_indexed,
            {
              id: indexingDecision._id,
              reason: JSON.stringify(error, error ? Object.getOwnPropertyNames(error) : null),
            },
          ],
        };
      } else if (indexingDecision.result !== 'updated' && indexingDecision.result !== 'created')
        return {
          indexed: acc.indexed,
          not_indexed: [...acc.not_indexed, { id: indexingDecision._id, reason: indexingDecision.result }],
        };
      else return { indexed: [...acc.indexed, indexingDecision._id], not_indexed: acc.not_indexed };
    },
    { indexed: [], not_indexed: [] },
  );
}

async function indexDecisions(decisions) {
  const { body } = await Elastic.client.bulk({
    body: decisions.flatMap(({ id, ...decision }) => [
      { index: { _id: id, _index: process.env.ELASTIC_INDEX } },
      decision,
    ]),
  });
  return body.items;
}

module.exports = {
  toPublish,
};

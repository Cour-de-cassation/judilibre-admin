const Elastic = require('../modules/elastic');
const { toHistory } = require('./transaction');

// DECISION INTERFACES

async function toPublish(decisions) {
  const decisionsToIndex = decisions.map(fromPayloadToDecision);
  const items = await indexDecisions(decisionsToIndex);
  toHistory(items.map(({ index }) => index)); // Warn: not controlled by API flux
  return fromIndexingToResponse(items);
}

async function toUnpublish(idDecisions) {
  const items = await deleteDecisions(idDecisions);
  toHistory(items.map(({ delete: action }) => action)); // Warn: not controlled by API flux
  return fromDeletingToResponse(items);
}

// DECISION INSTRUCTIONS

async function indexDecisions(decisions) {
  const { body } = await Elastic.client.bulk({
    body: decisions.flatMap(({ id, ...decision }) => [
      { index: { _id: id, _index: process.env.ELASTIC_INDEX } },
      decision,
    ]),
  });
  return body.items;
}

async function deleteDecisions(ids) {
  console.log(ids);
  const { body } = await Elastic.client.bulk({
    body: ids.map((id) => ({ delete: { _id: id, _index: process.env.ELASTIC_INDEX } })),
  });
  return body.items;
}

// DECISION FORMATS (INPUT)

function fromPayloadToDecision(decisionPayload) {
  // TODO: zones elements as array && zones.introduction elements with start and end should be validated by express schema validator
  // TODO: it should be safer with typescript
  const textZone = (zones) =>
    zones && Array.isArray(zones) && zones.map(({ start, end }) => decisionPayload.text.substring(start, end).trim());

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

// DECISION FORMATS (OUTPUT)

function fromIndexingToResponse(indexingDecisions) {
  return indexingDecisions.reduce(
    (acc, { index: indexingDecision }) => {
      const error = indexingDecision.error;
      if (error) {
        return {
          indexed: acc.indexed,
          not_indexed: [
            ...acc.not_indexed,
            {
              id: indexingDecision._id,
              reason: fromErrorToResponse(error, 'indexing', indexingDecision._id),
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

function fromDeletingToResponse(deletingDecisions) {
  return deletingDecisions.map(({ delete: deletingDecision }) => {
    const error = deletingDecision.error;
    if (error) {
      return {
        id: deletingDecision._id,
        deleted: false,
        reason: fromErrorToResponse(error, 'deleting', deletingDecision._id),
      };
    } else {
      return {
        id: deletingDecision._id,
        deleted: deletingDecision.result === 'deleted',
        reason: deletingDecision.result,
      };
    }
  });
}

function fromErrorToResponse(e, action, id) {
  console.error(`${process.env.APP_ID}: Error while '${action}' decision ${id}`);
  console.error(e);
  return JSON.stringify(e, e ? Object.getOwnPropertyNames(e) : null);
}

// EXPORTS

module.exports = {
  toPublish,
  toUnpublish,
};

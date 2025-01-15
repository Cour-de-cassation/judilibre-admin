const Elastic = require('../modules/elastic');
const { toHistory } = require('./transaction');

// DECISION INTERFACES

async function toPublish(decisions) {
  const decisionsToIndex = decisions.map(fromPayloadToDecision);
  const { indexed, notIndexed } = await indexDecisions(decisionsToIndex);
  try {
    const transactionItems = indexed.length > 0 ? await toHistory(indexed) : [];
    return fromIndexingToResponse(indexed, notIndexed, transactionItems);
  } catch (e) {
    console.error(e)
    return fromIndexingToResponse(indexed, notIndexed, []);
  }
}

async function toUnpublish(idDecisions) {
  const items = await deleteDecisions(idDecisions);
  const deleted = items.filter(({ deleted }) => deleted);
  try {
    const transactionItems = await toHistory(deleted.map(({ action }) => action));
    return fromDeletingToResponse(items, transactionItems);
  } catch (e) {
    console.error(e)
    return fromDeletingToResponse(items, []);
  }
}

// DECISION INSTRUCTIONS

async function indexDecisions(decisions) {
  const {
    body: { items },
  } = await Elastic.client.bulk({
    body: decisions.flatMap(({ id, ...decision }) => [
      { index: { _id: id, _index: process.env.ELASTIC_INDEX } },
      decision,
    ]),
  });

  return items.reduce(
    (acc, { index }) => {
      return !index.error && (index.result === 'updated' || index.result === 'created')
        ? { ...acc, indexed: [...acc.indexed, index] }
        : { ...acc, notIndexed: [...acc.notIndexed, index] };
    },
    {
      indexed: [],
      notIndexed: [],
    },
  );
}

async function deleteDecisions(ids) {
  const {
    body: { items },
  } = await Elastic.client.bulk({
    body: ids.map((id) => ({ delete: { _id: id, _index: process.env.ELASTIC_INDEX } })),
  });

  return items.map(({ delete: action }) =>
    action.error
      ? {
          action,
          deleted: false,
          reason: fromErrorToResponse(action.error, 'deleting', action._id),
        }
      : { action, deleted: action.result === 'deleted', reason: action.result },
  );
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

function fromIndexingToResponse(indexedItems, notIndexedItems, loggedItems) {
  return {
    indexed: indexedItems.map((index) => index._id),
    not_indexed: notIndexedItems.map((item) =>
      item.error
        ? { id: item.index._id, reason: fromErrorToResponse(item.error, 'indexing', item.index._id) }
        : { id: item.index._id, reason: item.index.result },
    ),
    transaction_not_historicized: indexedItems.filter((index) => {
      const loggedItem = loggedItems.find(({ input }) => input === index);
      const error = loggedItem?.item?.index?.error ?? "Unknown Server Error";
      if (error) console.error(`${process.env.APP_ID}: Error while historicize decision ${JSON.stringify(error)}`);
      return !!error;
    }),
  };
}

function fromDeletingToResponse(deletingDecisions, loggedItems = []) {
  // Cause of technical debt: should be removed to have only one response format:
  if (deletingDecisions.length === 1)
    return {
      id: deletingDecisions[0].action._id,
      deleted: deletingDecisions[0].deleted,
      reason: deletingDecisions[0].reason,
      transaction_not_historicized: deletingDecisions.filter(({ action }) => {
        const loggedItem = loggedItems.find(({ input }) => input === action);
        const error = loggedItem?.item?.delete?.error ?? "Unknown Server Error";
        if (error) console.error(`${process.env.APP_ID}: Error while historicize decision ${JSON.stringify(error)}`);
        return !!error;
      }),
    };

  return deletingDecisions.reduce(
    (acc, { action, deleted, reason }) => ({
      ...acc,
      [action._id]: { deleted, reason },
      transaction_not_historicized: deletingDecisions.filter(({ action }) => {
        const loggedItem = loggedItems.find(({ input }) => input === action);
        const error = loggedItem?.item?.delete?.error ?? "Unknown Server Error";
        if (error) console.error(`${process.env.APP_ID}: Error while historicize decision ${JSON.stringify(error)}`);
        return !!error;
      }),
    }),
    {},
  );
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

const apis = [];

apis.push(require('./admin'));
apis.push(require('./import'));
apis.push(require('./delete'));
apis.push(require('./healthcheck'));
apis.push(require('./patch'));

module.exports = apis;

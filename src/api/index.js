const apis = [];

apis.push(require('./admin'));
apis.push(require('./import'));
apis.push(require('./delete'));
apis.push(require('./healthcheck'));

module.exports = apis;

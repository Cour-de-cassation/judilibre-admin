const apis = [];

apis.push(require('./admin'));
apis.push(require('./import'));
apis.push(require('./delete'));

module.exports = apis;

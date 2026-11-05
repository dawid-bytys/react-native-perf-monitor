const Module = require('node:module');

const CONFIG_PLUGINS_REQUEST = 'expo/config-plugins';
const configPluginsPath = require.resolve(CONFIG_PLUGINS_REQUEST);
const originalResolveFilename = Module._resolveFilename;

Module._resolveFilename = function (request, ...rest) {
  if (request === CONFIG_PLUGINS_REQUEST) {
    return configPluginsPath;
  }

  return originalResolveFilename.call(this, request, ...rest);
};

module.exports = require('../app.plugin.js');

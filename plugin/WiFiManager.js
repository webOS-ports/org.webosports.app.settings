__WiFiManager = {};
__WiFiManager.powered = false;

navigator.WiFiManager = {};

navigator.WiFiManager.onenabled = null;
navigator.WiFiManager.ondisabled = null;
navigator.WiFiManager.onstatuschange = null;
navigator.WiFiManager.onnetworkschange = null;
navigator.WiFiManager.connectionInfoUpdate = null;

__WiFiManager.setPowered = function(powered) {
    __WiFiManager.powered = powered;

    _webOS.execWithoutCallback("WiFiManager", "setPowered", [powered]);

    if (powered && typeof navigator.WiFiManager.onenabled === 'function')
        navigator.WiFiManager.onenabled();
    else if (!powered && typeof navigator.WiFiManager.ondisabled === 'function')
        navigator.WiFiManager.ondisabled();
}

__WiFiManager.networksChanged = function(networks) {
    if (typeof navigator.WiFiManager.onnetworkschange === 'function')
      navigator.WiFiManager.onnetworkschange(networks);
}

Object.defineProperty(navigator.WiFiManager, "enabled", {
  get: function() { return __WiFiManager.enabled; },
  set: function(value) { __WiFiManager.setPowered(value); }
});

navigator.WiFiManager.retrieveNetworks = function(succesCallback, errorCallback) {
    _webOS.exec(succesCallback, errorCallback, "WiFiManager", "retrieveNetworks");
}

navigator.WiFiManager.connectNetwork = function(network, succesCallback, errorCallback) {
    _webOS.exec(succesCallback, errorCallback, "WiFiManager", "connectNetwork", [JSON.stringify(network)]);
}

navigator.WiFiManager.setNetworkOption = function(path, key, value) {
    _webos.execWithoutCallback("WiFiManager", "setNetworkOption", [path, key, value]);
}

navigator.WiFiManager.disconnectNetwork = function(path) {
    _webOS.execWithoutCallback("WiFiManager", "disconnectNetwork", [path]);
}

navigator.WiFiManager.removeNetwork = function(path) {
    _webOS.execWithoutCallback("WiFiManager", "removeNetwork", [path]);
}

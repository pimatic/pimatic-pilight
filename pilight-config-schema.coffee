# #pilight configuration options
module.exports = {
  title: "pilight config"
  type: "object"
  properties:
    host:
      description: "The ip or host to connect to the piligt-daemon, you must disabled ssdp to use this."
      type: "string"
      default: "127.0.0.1"
    port:
      description: "port to connect to the piligt-daemon, you must disabled ssdp to use this."
      type: "integer"
      format: "port"
      default: 5000
    timeout:
      description: "timeout for requests"
      type: "integer"
      default: 6000
    debug:
      description: "print out debug info with debug log level"
      type: "boolean"
      default: false
    ssdp:
      description: "enable ssdp"
      type: "boolean"
      default: true
    enableHeartbeat:
      description: """if enabled pimatic sends a heatbeat in the defined interval to check if the connection
        to the pilight-daemon is still alive.
        """
      type: "boolean"
      default: true
    heartbeatInterval:
      description: "The interval in ms the heartbeat is sent to the pilight-daemon"
      type: "integer"
      default: 20000
    minTemperature:
      description: "temperature values (in °C) below this value will be discarded"
      type: "number"
      default: -10
    maxTemperature:
      description: "temperature values (in °C) above this value will be discarded"
      type: "number"
      default: 100
    maxTemperatureDelta:
      description: "temperature changes per second above this value (in °C/s) will be discarded"
      type: "number"
      default: 0.5 # in 10 seconds +-5°C
    minHumidity:
      description: "humidity values (in %) below this value will be discarded"
      type: "number"
      default: 0
    maxHumidity:
      description: "humidity values (in %) above this value will be discarded"
      type: "number"
      default: 100
    maxHumidityDelta:
      description: "humidity changes per second above this value (in %/s) will be discarded"
      type: "number"
      default: 1.0 # in 10 seconds +-10%
}
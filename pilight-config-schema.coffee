# #pilight configuration options

# Defines a `node-convict` config-schema and exports it.
module.exports =
  host:
    doc: "The ip or host to connect to the piligt-daemon"
    format: String
    default: "127.0.0.1"
  port:
    doc: "port to connect to the piligt-daemon"
    format: "port"
    default: 5000
  timeout:
    doc: "timeout for requests"
    format: Number
    default: 6000
  debug:
    doc: "print out debug info with debug log level"
    format: Boolean
    default: false
  ssdp:
    doc: "enable ssdp"
    format: Boolean
    default: false
  enableHeartbeat:
    doc: """if enabled pimatic sends a heatbeat in the defined interval to check if the connection
      to the pilight-daemon is still alive.
      """
    format: Boolean
    default: true
  heartbeatInterval:
    doc: "The interval in ms the heartbeat is sent to the pilight-daemon"
    format: "nat"
    default: 20000
  minTemperature:
    doc: "temperature values (in °C) below this value will be discarded"
    format: Number
    default: -10
  maxTemperature:
    doc: "temperature values (in °C) above this value will be discarded"
    format: Number
    default: 100
  maxTemperatureDelta:
    doc: "temperature changes per second above this value (in °C/s) will be discarded"
    format: Number
    default: 0.5 # in 10 seconds +-5°C
  minHumidity:
    doc: "humidity values (in %) below this value will be discarded"
    format: Number
    default: 0
  maxHumidity:
    doc: "humidity values (in %) above this value will be discarded"
    format: Number
    default: 100
  maxHumidityDelta:
    doc: "humidity changes per second above this value (in %/s) will be discarded"
    format: Number
    default: 1.0 # in 10 seconds +-10%
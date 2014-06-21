module.exports = {
  title: "pimatic device config schemas"
  PilightSwitch: {
    title: "PilightSwitch config options"
    type: "object"
    properties:
      inPilightConfig:
        description: ""
        type: "boolean"
      location:
        description: ""
        type: "string"
      device:
        description: ""
        type: "string"
      lastState:
        description: ""
        type: "boolean"   
        default: false
  }
  PilightDimmer: {
    title: "PilightDimmer config options"
    type: "object"
    properties:
      inPilightConfig:
        description: ""
        type: "boolean"
      location:
        description: ""
        type: "string"
      device:
        description: ""
        type: "string"
      minDimlevel:
        description: ""
        type: "number"
      maxDimlevel:
        description: ""
        type: "number"
      lastDimlevel:
        description: ""
        type: "number"
        default: 0
  }
  PilightTemperatureSensor: {
    title: "PilightTemperatureSensor config options"
    type: "object"
    properties:
      inPilightConfig:
        description: ""
        type: "boolean"
      location:
        description: ""
        type: "string"
      device:
        description: ""
        type: "string"
      hasTemperature:
        description: ""
        type: "boolean"
      hasHumidity:
        description: ""
        type: "boolean"
      deviceDecimals:
        description: ""
        type: "integer"
      lastTemperature:
        description: ""
        type: "number"
        default: 0
      lastHumidity:
        description: ""
        type: "number"
        default: 0
  }
  PilightShutter: {
    title: "PilightShutter config options"
    type: "object"
    properties:
      inPilightConfig:
        description: ""
        type: "boolean"
      location:
        description: ""
        type: "string"
      device:
        description: ""
        type: "string"
      lastPosition:
        description: ""
        type: "string"
        default: 'stopped'
  }
  PilightContact: {
    title: "PilightContact config options"
    type: "object"
    properties:
      inPilightConfig:
        description: ""
        type: "boolean"
      location:
        description: ""
        type: "string"
      device:
        description: ""
        type: "string"
      lastContactState:
        description: ""
        type: "boolean"
        default: off
  }
}
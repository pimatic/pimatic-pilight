module.exports =
  PilightSwitch:
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
  PilightDimmer:
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
  PilightTemperatureSensor:
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
      type: "number"
    lastTemperature:
      description: ""
      type: "number"
      default: 0
    lastHumidity:
      description: ""
      type: "number"
      default: 0
  PilightShutter:
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
  PilightContact:
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
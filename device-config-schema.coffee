module.exports = {
  title: "pimatic device config schemas"
  PilightSwitch: {
    title: "PilightSwitch config options"
    type: "object"
    extensions: ["xConfirm", "xLink", "xOnLabel", "xOffLabel"]
    properties:
      inPilightConfig:
        description: ""
        type: "boolean"
        options:
          hidden: yes
      location:
        description: ""
        type: "string"
        options:
          hidden: yes
      device:
        description: ""
        type: "string"
        options:
          hidden: yes
      lastState:
        description: ""
        type: "boolean"   
        default: false
        options:
          hidden: yes
  }
  PilightDimmer: {
    title: "PilightDimmer config options"
    type: "object"
    extensions: ["xLink"]
    properties:
      inPilightConfig:
        description: ""
        type: "boolean"
        options:
          hidden: yes
      location:
        description: ""
        type: "string"
        options:
          hidden: yes
      device:
        description: ""
        type: "string"
        options:
          hidden: yes
      minDimlevel:
        description: ""
        type: "number"
        options:
          hidden: yes
      maxDimlevel:
        description: ""
        type: "number"
        options:
          hidden: yes
      lastDimlevel:
        description: ""
        type: "number"
        default: 0
        options:
          hidden: yes
  }
  PilightTemperatureSensor: {
    title: "PilightTemperatureSensor config options"
    type: "object"
    extensions: ["xLink"]
    properties:
      inPilightConfig:
        description: ""
        type: "boolean"
        options:
          hidden: yes
      location:
        description: ""
        type: "string"
        options:
          hidden: yes
      device:
        description: ""
        type: "string"
        options:
          hidden: yes
      hasTemperature:
        description: ""
        type: "boolean"
        options:
          hidden: yes
      hasHumidity:
        description: ""
        type: "boolean"
        options:
          hidden: yes
      deviceDecimals:
        description: ""
        type: "integer"
        options:
          hidden: yes
      lastTemperature:
        description: ""
        type: "number"
        default: 0
        options:
          hidden: yes
      lastHumidity:
        description: ""
        type: "number"
        default: 0
        options:
          hidden: yes
  }
  PilightShutter: {
    title: "PilightShutter config options"
    type: "object"
    extensions: ["xLink"]
    properties:
      inPilightConfig:
        description: ""
        type: "boolean"
        options:
          hidden: yes
      location:
        description: ""
        type: "string"
        options:
          hidden: yes
      device:
        description: ""
        type: "string"
        options:
          hidden: yes
      lastPosition:
        description: ""
        type: "string"
        default: 'stopped'
        options:
          hidden: yes
  }
  PilightContact: {
    title: "PilightContact config options"
    type: "object"
    extensions: ["xLink"]
    properties:
      inPilightConfig:
        description: ""
        type: "boolean"
        options:
          hidden: yes
      location:
        description: ""
        type: "string"
        options:
          hidden: yes
      device:
        description: ""
        type: "string"
        options:
          hidden: yes
      lastContactState:
        description: ""
        type: "boolean"
        default: off
        options:
          hidden: yes
  }
  PilightXbmc: {
    title: "PilightXbmc device config schemas"
    type: "object"
    extensions: ["xLink"]
    properties:
      inPilightConfig:
        description: ""
        type: "boolean"
        options:
          hidden: yes
      location:
        description: ""
        type: "string"
        options:
          hidden: yes
      device:
        description: ""
        type: "string"
        options:
          hidden: yes
      lastMediaState:
        description: ""
        type: "boolean"
        options:
          hidden: yes
  }
}

module.exports = (env) ->
  spawn = require("child_process").spawn
  util = require 'util'

  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'

  EverSocket = require("eversocket").EverSocket


  class PilightPlugin extends env.plugins.Plugin
    framework: null
    config: null
    state: "unconnected"
    pilightConfig: null
    client: null

    init: (@app, @framework, @config) =>
      conf = convict require("./pilight-config-shema")
      conf.load config
      conf.validate()
      @config = conf.get ""

      @client = new EverSocket(
        reconnectWait: 3000
        timeout: @config.timeout
        reconnectOnTimeout: true
      )

      @client.on "reconnect", =>
        env.logger.info "connected to pilight-daemon"
        @sendWelcome()

      @client.on "data", (data) =>
        for msg in data.toString().split "\n"
          if msg.length isnt 0
            @onReceive JSON.parse msg

      @client.on "end", =>
        @state = "unconnected"

      @client.on "error", (err) =>
        env.logger.error "Error on connection to pilight-daemon: #{err}"
        env.logger.debug err.stack
      
      @client.connect(
        @config.port,
        @config.host
      )
      return

    sendWelcome: ->
      @state = "welcome"
      @send { message: "client gui" }

    send: (jsonMsg) ->
      success = false
      if @state isnt "unconnected"
        env.logger.debug("pilight send: ", JSON.stringify(jsonMsg, null, " ")) if @config.debug
        @client.write JSON.stringify(jsonMsg) + "\n", 'utf8'
        success = true
      return success

    sendState: (id, jsonMsg) ->
      deferred = Q.defer()

      success = @send jsonMsg
      if success

        event = "state callback #{id}"
        onStateCallback = null

        # register a timeout if we dont get a awnser from pilight-daemon
        onTimeout = => 
          @removeListener event, onStateCallback
          deferred.reject new Error "Request to pilight-daemon timeout"
          return

        receiveTimeout = setTimeout onTimeout, @config.timeout

        # if we get a awnser this function get called:
        onStateCallback = (state) =>
          clearTimeout receiveTimeout
          @removeListener event, onStateCallback
          deferred.resolve()

        @on event, onStateCallback

      else
        deferred.reject new Error "Could not send request to pilight-daemon"
      return deferred.promise

    onReceive: (jsonMsg) ->
      env.logger.debug("pilight received: ", JSON.stringify(jsonMsg, null, " ")) if @config.debug
      switch @state
        when "welcome"
          if jsonMsg.message is "accept client"
            @state = "connected"
            @send { message: "request config" }
        else
          if jsonMsg.config?
            @onReceiveConfig jsonMsg.config
          else if jsonMsg.origin?
            # {
            #  "origin": "config",
            #  "type": 1,
            #  "devices": {
            #   "work": [
            #    "lampe"
            #   ]
            #  },
            #  "values": {
            #   "state": "off"
            #  }
            if jsonMsg.origin is 'config'
              for location, devices of jsonMsg.devices
                for device in devices
                  id = "pilight-#{location}-#{device}"
                  switch jsonMsg.type
                    when 1
                      @updateSwitch id, jsonMsg
                    when 3
                      @updateSensor id, jsonMsg
      return

    updateSwitch: (id, jsonMsg) ->
      actuator = @framework.getDeviceById id
      if actuator?
        state = (if jsonMsg.values.state is 'on' then on else off)
        actuator._setState state
        @emit "state callback #{id}", state
      return

    updateSensor: (id, jsonMsg) ->
      sensor = @framework.getDeviceById id
      if sensor?
        sensor.setValues jsonMsg.values

    onReceiveConfig: (config) ->
      # iterate ´config = { living: { name: "Living", ... }, ...}´
      for location, devices of config
        #   location = "tv"
        #   device = { name: "Living", order: "1", protocol: [ "kaku_switch" ], ... }
        # iterate ´devices = { tv: { name: "TV", ...}, ... }´
        for device, deviceProbs of devices
          if typeof deviceProbs is "object"
            id = "pilight-#{location}-#{device}"
            deviceProbs.location = location
            deviceProbs.device = device
            switch deviceProbs.type
              when 1
                @actuatorConfigReceive id, deviceProbs
              when 3
                @sensorConfigReceived id, deviceProbs
              else
                env.logger.warn "Unimplemented pilight device type: #{device.type}" 
      return

    actuatorConfigReceive: (id, deviceProbs) ->
      actuator = @framework.getDeviceById id
      if actuator?
        if actuator instanceof PilightSwitch
          actuator.updateFromPilightConfig deviceProbs
        else
          env.logger.error "actuator should be an PilightSwitch"
      else
        actuator = new PilightSwitch id, deviceProbs
        @framework.registerDevice actuator
        actuatorConfig = actuator.getActuatorConfig()
        if @framework.isDeviceInConfig id
          @framework.updateDeviceConfig actuatorConfig
        else
          @framework.addDeviceToConfig actuatorConfig

    sensorConfigReceived: (id, deviceProbs) ->
      sensor = @framework.getDeviceById id
      if sensor?
        if sensor instanceof PilightTemperatureSensor
          sensor.updateFromPilightConfig deviceProbs
        else 
          env.logger.error "sensor should be an PilightTemperatureSensor"
      else
        sensor = new PilightTemperatureSensor id, deviceProbs
        @framework.registerDevice sensor
        sensorConfig = sensor.getSensorConfig()
        if @framework.isDeviceInConfig id
          @framework.updateDeviceConfig sensorConfig
        else
          @framework.addDeviceToConfig sensorConfig


    createDevice: (config) =>
      return switch config.class
        when 'PilightSwitch'
          @framework.registerDevice new PilightSwitch config.id, deviceProbs =
            name: config.name
            location: config.location
            device: config.device
            state: if config.lastState is on then 'on' else 'off'
          true
        when 'PilightTemperatureSensor'
          @framework.registerDevice new PilightTemperatureSensor config.id, deviceProbs =
            name: config.name
            location: config.location
            device: config.device
            humidity: config.lastHumidity
            temperature: config.lastTemperature
            settings: config.settings
          true
        else false

  plugin = new PilightPlugin

  class PilightSwitch extends env.devices.PowerSwitch
    probs: null

    constructor: (@id, @probs) ->
      @updateFromPilightConfig(probs)

    # Run the pilight-send executable.
    changeStateTo: (state) ->
      if @state is state
        return Q.fcall => true

      jsonMsg =
        message: "send"
        code:
          location: @probs.location
          device: @probs.device
          state: if state then "on" else "off"

      return plugin.sendState @id, jsonMsg

    updateFromPilightConfig: (@probs) ->
      assert probs?
      @name = probs.name
      @_setState (if probs.state is 'on' then on else off)

    _setState: (state) ->
      if state is @state then return
      super state
      if plugin.framework.isDeviceInConfig @id
        plugin.framework.updateDeviceConfig @getActuatorConfig()

    getActuatorConfig: () ->
      return config =
        id: @id
        class: 'PilightSwitch'
        inPilightConfig: true
        name: @name
        location: @probs.location
        device: @probs.device
        lastState: @_state

  class PilightTemperatureSensor extends env.devices.TemperatureSensor
    temperature: null
    humidity: null

    constructor: (@id, @probs) ->
      @updateFromPilightConfig probs
      if probs.humidity
        @attributes.humidity =
          desciption: "the messured humidity"
          type: Number
          unit: '%'

    updateFromPilightConfig: (@probs) ->
      @name = probs.name
      @setValues
        temperature: @probs.temperature
        humidity: @probs.humidity

    setValues: (values) ->
      if values.temperature?
        @temperature = values.temperature/(@probs.settings.decimals*10)
        @emit "temperature", @temperature
      if values.humidity?
        @humidity = values.humidity/(@probs.settings.decimals*10)
        @emit "humidity", @humidity
      if plugin.framework.isDeviceInConfig @id
        plugin.framework.updateDeviceConfig @getSensorConfig()
      return

    getSensorConfig: () ->
      return config =
        id: @id
        class: 'PilightTemperatureSensor'
        inPilightConfig: true
        name: @name
        location: @probs.location
        device: @probs.device
        lastTemperature: @probs.temperature
        lastHumidity: @probs.humidity
        settings: @probs.settings

    getTemperature: -> Q(@temperature)
    getHumidity: -> Q(@humidity)

  return plugin
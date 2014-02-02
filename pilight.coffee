module.exports = (env) ->
  spawn = require("child_process").spawn
  util = require 'util'
  ssdp = require("node-ssdp")

  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'

  EverSocket = env.EverSocket or require("eversocket").EverSocket

  class PilightClient extends EverSocket

    constructor: (options) ->
      @debug = options.debug
      delete options.debug
      super(options)

      @on "end", =>
        @state = "unconnected"

      @.on "reconnect", =>
        env.logger.info "connected to pilight-daemon"
        @sendWelcome()

      @on "data", (data) =>
        for msg in data.toString().split "\n"
          if msg.length isnt 0
            @onReceive JSON.parse msg

      @on "error", (err) =>
        env.logger.error "Error on connection to pilight-daemon: #{err}"
        env.logger.debug err.stack

    sendWelcome: ->
      @state = "welcome"
      @send { message: "client gui" }

    send: (jsonMsg) ->
      success = false
      if @state isnt "unconnected"
        env.logger.debug("pilight send: ", JSON.stringify(jsonMsg, null, " ")) if @debug
        @write JSON.stringify(jsonMsg) + "\n", 'utf8'
        success = true
      return success

    onReceive: (jsonMsg) ->
      env.logger.debug("pilight received: ", JSON.stringify(jsonMsg, null, " ")) if @debug
      switch @state
        when "welcome"
          # message: "accept client"
          if jsonMsg.message is "accept client"
            @state = "connected"
            @send { message: "request config" }
        when "connected"
          switch 
            when jsonMsg.config?
              @emit "config", jsonMsg
            when jsonMsg.origin?
              @emit "update", jsonMsg
      return

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

      @client = new PilightClient(
        reconnectWait: 3000
        timeout: @config.timeout
        debug: @config.debug
      )
      
      if @config.ssdp
        ssdpClient = new ssdp(log: true, logLevel: "trace")
        ssdpPilightFound = false

        ssdpClient.on "advertise-alive", inAdvertisement = (headers) =>
          #we got an ssdp notify
          if ssdpPilightFound
            env.logger.debug "got another ssdp notify after we already found pilight"
            return
          env.logger.debug "SSDP notify: Location = #{headers['LOCATION']} SERVER = #{headers['SERVER']}"
          searchResult = headers['LOCATION'].split ":"
          hostValue = searchResult[0]
          portValue = parseInt searchResult[1]

          if portValue != 0
            env.logger.info "pilight: found pilight server #{hostValue}:#{portValue}, trying to connect"
            @client.connect(
              portValue,
              hostValue
            )
            @client.setReconnectOnTimeout true
            ssdpPilightFound = true
          else
            env.logger.error "received port is not a number"

        searchSSDP = () =>
          if ssdpPilightFound is not true
            #searching for pilight ssdp
            env.logger.info "pilight: trying to find pilight via SSDP"
            ssdpClient.search "urn:schemas-upnp-org:service:pilight:1"
            #try searching again in 1s
            setTimeout(searchSSDP,5000)
          else
            env.logger.debug "pilight: skipping ssdp, already found pilight"

        searchSSDP()

      else
        #not using ssdp, connectin normally
        @client.connect(
          @config.port,
          @config.host
        )
        @client.setReconnectOnTimeout true

      @client.on "config", onReceiveConfig = (json) =>
        config = json.config

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
              @handleDeviceInConfig(id, deviceProbs)
        return

      @client.on "update", onReceivedOrigin = (jsonMsg) =>
        if jsonMsg.origin is 'config'
          for location, devices of jsonMsg.devices
            for device in devices
              id = "pilight-#{location}-#{device}"  
              @emit "update #{id}", jsonMsg
        return

    handleDeviceInConfig: (id, deviceProbs) =>
      getClassFromType = (type) =>
        switch type
          when 1 then [PilightSwitch, "PilightSwitch"]
          when 2 then [PilightDimmer, "PilightDimmer"]
          when 3 then [PilightTemperatureSensor, "PilightTemperatureSensor"]
          else [null, null]

      [Class, ClassName] = getClassFromType deviceProbs.type
      unless Class?
        env.logger.warn "Unimplemented pilight device type: #{deviceProbs.type}" 
        return
      actuator = @framework.getDeviceById id
      if actuator?
        unless actuator instanceof Class
          env.logger.error "expected #{id} to be an #{Class}"
          return
      else 
        config = 
          id: id
          name: deviceProbs.name
          class: ClassName
          inPilightConfig: true
          location: deviceProbs.location
          device: deviceProbs.device
          settings: {}
        if deviceProbs.humidity then config.settings.humidity = 1
        if deviceProbs.temperature then config.settings.temperature = 1
        actuator = new Class config
        @framework.registerDevice actuator
        @framework.addDeviceToConfig config
      actuator.updateFromPilightConfig deviceProbs


    sendState: (id, jsonMsg) ->
      deferred = Q.defer()
      success = @client.send jsonMsg
      if success
        event = "update #{id}"
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

    createDevice: (config) =>
      return switch config.class
        when 'PilightSwitch'
          @framework.registerDevice new PilightSwitch config
          true
        when 'PilightDimmer'
          @framework.registerDevice new PilightDimmer config, 
          true
        when 'PilightTemperatureSensor'
          @framework.registerDevice new PilightTemperatureSensor config, 
          true
        else false

  plugin = new PilightPlugin

  class PilightSwitch extends env.devices.PowerSwitch
    probs: null

    constructor: (@config) ->
      assert @config.id?
      assert @config.name?
      assert @config.location?
      assert @config.device?
      assert (if @config.lastState? then typeof @config.lastState is "boolean" else true) 

      @id = config.id
      @name = config.name
      if config.lastState?
        @_state = config.lastState
      super()
      plugin.on "update #{@id}", (msg) =>
        unless msg.values?.state?
          env.logger.error "wrong message from piligt daemon received:", msg
          return
        assert msg.values.state is 'on' or msg.values.state is 'off'
        state = (if msg.values.state is 'on' then on else off)
        @._setState state

    # Run the pilight-send executable.
    changeStateTo: (state) ->
      if @_state is state
        return Q true

      jsonMsg =
        message: "send"
        code:
          location: @config.location
          device: @config.device
          state: if state then "on" else "off"

      return plugin.sendState @id, jsonMsg

    updateFromPilightConfig: (probs) ->
      assert probs?
      @name = probs.name
      @_setState (if probs.state is 'on' then on else off)

    _setState: (state) ->
      if state is @_state then return
      super state
      @config.lastState = state
      plugin.framework.saveConfig()

  class PilightDimmer extends env.devices.DimmerActuator

    constructor: (@config) ->
      assert @config.id?
      assert @config.name?
      assert @config.location?
      assert @config.device?

      @id = config.id
      @name = config.name
      if config.lastDimlevel?
        @_dimlevel= config.lastDimlevel
      super()
      plugin.on "update #{@id}", (msg) =>
        unless msg.values?.dimlevel? or msg.values?.state?
          env.logger.error "wrong message from piligt daemon received:", msg
          return
        unless msg.values.dimlevel? 
          msg.values.dimlevel = (if msg.values.state is 'on' then 100 else 0)
        dimlevel = msg.values.dimlevel
        @_setDimlevel dimlevel

    # Run the pilight-send executable.
    changeDimlevelTo: (dimlevel) ->
      assert not isNaN(dimlevel) 
      dimLevel = parseFloat(dimLevel)
      if @_dimlevel is dimlevel then return Q()
      jsonMsg =
        message: "send"
        code:
          location: @config.location
          device: @config.device
          state: (if dimlevel > 0 then "on" else "off")
        values: 
          dimlevel: dimlevel.toString()

      return plugin.sendState @id, jsonMsg

    updateFromPilightConfig: (probs) ->
      assert probs?
      assert probs.dimlevel?
      assert not isNaN(probs.dimlevel)  
      probs.dimlevel = parseFloat(probs.dimlevel)
      @name = probs.name
      @_setDimlevel probs.dimlevel

    _setDimlevel: (dimlevel) ->
      if dimlevel is @_dimlevel then return
      super dimlevel
      @config.lastDimlevel = dimlevel
      plugin.framework.saveConfig()

  class PilightTemperatureSensor extends env.devices.TemperatureSensor
    temperature: null
    humidity: null

    constructor: (@config) ->
      assert @config.id?
      assert @config.name?
      assert @config.settings?

      @id = @config.id
      @name = @config.name
      if @config.lastTemperature?
        @temperature = @config.lastTemperature
      if @config.lastHumidity?
        @humidity = @config.lastHumidity

      if @config.settings.humidity
        @attributes.humidity =
          description: "the messured humidity"
          type: Number
          unit: '%'
      super()
      plugin.on "update #{@id}", (msg) =>
        unless msg.values?
          env.logger.error "wrong message from piligt daemon received:", msg
          return
        @setValues msg.values

    updateFromPilightConfig: (probs) ->
      @name = probs.name
      @config.settings = probs.settings
      @setValues
        temperature: probs.temperature
        humidity: probs.humidity

    setValues: (values) ->
      assert not isNaN(@config.settings.decimals)
      if values.temperature?
        @temperature = values.temperature/Math.pow(10, @config.settings.decimals)
        @emit "temperature", @temperature
        @config.lastTemperature = @temperature

      if values.humidity?
        @humidity = values.humidity/Math.pow(10, @config.settings.decimals)
        @emit "humidity", @humidity
        @config.lastHumidity = @humidity
      plugin.framework.saveConfig()
      return

    getTemperature: -> Q(@temperature)
    getHumidity: -> Q(@humidity)

  # For testing...
  plugin.PilightSwitch = PilightSwitch
  plugin.PilightDimmer = PilightDimmer
  plugin.PilightTemperatureSensor = PilightTemperatureSensor

  return plugin
module.exports = (env) ->
  spawn = require("child_process").spawn
  util = require 'util'

  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'
  _ = env.require 'lodash'

  EverSocket = env.EverSocket or require("eversocket").EverSocket
  SSDP = env.SSDP or require("node-ssdp")

  class PilightClient extends EverSocket

    buffer: ''

    constructor: (options) ->
      @_state = "unconnected"
      @debug = options.debug
      @enableHeartbeat = options.enableHeartbeat
      @heartbeatInterval = options.heartbeatInterval
      @heartbeatTimeoutTime = options.timeout
      delete options.debug
      delete options.enableHeartbeat
      delete options.heartbeatInterval
      super(options)


      @on "end", =>
        @_state = "unconnected"

      @.on "reconnect", =>
        env.logger.info "connected to pilight-daemon"
        @sendWelcome()
        @startHeartbeat() if @enableHeartbeat

      @on "data", (data) =>
        # https://github.com/pimatic/pimatic/issues/65
        @buffer += data.toString().replace(/\0/g, '')
        if @buffer[@buffer.length-2] is "\n" or @buffer[@buffer.length-1] is "\n"
          messages = @buffer[..-2]
          for msg in messages.split "\n"
            if msg.length isnt 0
              if msg is "BEAT"
                @onBeat()
              else
                jsonMsg = null
                try
                  jsonMsg = JSON.parse msg
                catch e
                  env.logger.error "error parsing pilight response: #{e} in \"#{msg}\""
                if jsonMsg? then @onReceive(jsonMsg)
          @buffer = ''

      lastError = null

      @on "error", (err) =>
        if err.message? and lastError? and err.message is lastError.message
          if @debug
            env.logger.debug "supressed repeated error #{err}"
            env.logger.debug err.stack
          return
        env.logger.error "Error on connection to pilight-daemon: #{err}"
        env.logger.debug err.stack
        lastError = err

    sendWelcome: ->
      @send { message: "client gui" }

    send: (jsonMsg) ->
      env.logger.debug("pilight send: ", JSON.stringify(jsonMsg, null, " ")) if @debug
      @write JSON.stringify(jsonMsg) + "\n", 'utf8'
      return true

    onReceive: (jsonMsg) ->
      env.logger.debug("pilight received: ", JSON.stringify(jsonMsg, null, " ")) if @debug
      switch 
        when jsonMsg.message is "accept client"
          @_state = "connected"
          @send { message: "request config" }
        when jsonMsg.config?
          @emit "config", jsonMsg
        when jsonMsg.origin?
          @emit "update", jsonMsg
      return

    startHeartbeat: ->
      env.logger.debug "startHeartbeat", @heartbeatInterval
      if @heartbeatTimeout
        clearTimeout @heartbeatTimeout
        delete @heartbeatTimeout

      sendHeartbeat = =>
        env.logger.debug("sending HEART to pilight-daemon") if @debug
        try
          @write "HEART\n", 'utf8'
        catch e
          env.logger.warn "Could not send heartbeat to pilight-daemon: #{e.message}"
          @heartbeatTimeout = setTimeout(sendHeartbeat, @heartbeatInterval)

        deferred = Q.defer()
        # If we get a beat back then resolve the promise
        @once 'beat', deferred.resolve
        # and set a timeout:
        promise = deferred.promise.timeout(
          @heartbeatTimeoutTime, 
          "heartbeat to pilight-daemon timedout after #{@heartbeatTimeoutTime}ms."
        ).catch( (e) =>
          env.logger.warn(e.message)
        ).finally(=> 
          # In case of a timeout and in case of an resolve, send next heartbeat
          setTimeout(sendHeartbeat, @heartbeatInterval) 
        )

      @heartbeatTimeout = setTimeout(sendHeartbeat, @heartbeatInterval)

    onBeat: =>
      env.logger.debug("got BEAT from pilight-daemon") if @debug
      @emit "beat"



  class PilightPlugin extends env.plugins.Plugin

    init: (@app, @framework, @config) =>
      conf = convict require("./pilight-config-schema")
      conf.load config
      conf.validate()
      @config = conf.get ""

      @client = new PilightClient(
        reconnectWait: 3000
        timeout: @config.timeout
        debug: @config.debug
        enableHeartbeat: @config.enableHeartbeat
        heartbeatInterval: @config.heartbeatInterval
      )
      
      if @config.ssdp
        ssdpClient = new SSDP(log: true, logLevel: "error")
        ssdpPilightFound = false

        ssdpClient.on "advertise-alive", inAdvertisement = (headers) =>
          #we got an ssdp notify
          if ssdpPilightFound
            env.logger.debug "got another ssdp notify after we already found pilight"
            return
          env.logger.debug(
            "SSDP notify: Location = #{headers['LOCATION']} SERVER = #{headers['SERVER']}"
          )
          searchResult = headers['LOCATION'].split ":"
          hostValue = searchResult[0]
          portValue = parseInt searchResult[1]

          if portValue != 0
            env.logger.info (
              "pilight: found pilight server #{hostValue}:#{portValue}, trying to connect"
            )
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
        @pilightVersion = json.version[0].split('.')
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
      getClassFromType = (deviceProbs) =>
        switch deviceProbs.type
          when 1 
            if deviceProbs.settings?.states isnt "opened,closed"
              [PilightSwitch, "PilightSwitch"]
            else
              [PilightContact, "PilightContact"]
          when 2 then [PilightDimmer, "PilightDimmer"]
          when 3 then [PilightTemperatureSensor, "PilightTemperatureSensor"]
          when 5 then [PilightShutter, "PilightShutter"]
          else [null, null]

      [Class, ClassName] = getClassFromType deviceProbs
      unless Class?
        env.logger.warn "Unimplemented pilight device type: #{deviceProbs.type}" 
        return
      actuator = @framework.getDeviceById id
      if actuator?
        unless actuator instanceof Class
          env.logger.error "expected #{id} to be an #{ClassName}"
          return
      else 
        config = {
          id: id
          name: deviceProbs.name
          class: ClassName
          inPilightConfig: true
          location: deviceProbs.location
          device: deviceProbs.device
          settings: {}
        }
        if deviceProbs.humidity then config.settings.humidity = 1
        if deviceProbs.temperature then config.settings.temperature = 1
        actuator = new Class config
        @framework.registerDevice actuator
        @framework.addDeviceToConfig config
      actuator.updateFromPilightConfig deviceProbs


    sendState: (id, jsonMsg, expectAck = yes) ->
      deferred = Q.defer()
      success = @client.send jsonMsg
      if success
        if expectAck
          # We wait for a feedback of pilight
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
          deferred.resolve()
      else
        deferred.reject new Error "Could not send request to pilight-daemon"
      return deferred.promise

    createDevice: (config) =>
      return switch config.class
        when 'PilightSwitch'
          @framework.registerDevice new PilightSwitch config
          true
        when 'PilightDimmer'
          @framework.registerDevice new PilightDimmer config
          true
        when 'PilightTemperatureSensor'
          @framework.registerDevice new PilightTemperatureSensor config
          true
        when 'PilightShutter'
          @framework.registerDevice new PilightShutter config
          true
        when 'PilightContact'
          @framework.registerDevice new PilightContact config
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
        @_setState state

    # Run the pilight-send executable.
    changeStateTo: (state) ->
      jsonMsg = {
        message: "send"
        code:
          location: @config.location
          device: @config.device
          state: if state then "on" else "off"
      }
      return plugin.sendState(@id, jsonMsg, (@_state isnt state))

    updateFromPilightConfig: (probs) ->
      assert probs?
      @name = probs.name
      @_setState (if probs.state is 'on' then on else off)

    _setState: (state) ->
      if state is @_state then return
      super state
      @config.lastState = state
      plugin.framework.saveConfig()

  class PilightContact extends env.devices.ContactSensor
    probs: null

    constructor: (@config) ->
      assert @config.id?
      assert @config.name?
      assert @config.location?
      assert @config.device?
      assert (
        if @config.lastContactState? 
        then typeof @config.lastContactState is "boolean" else true
      ) 

      @id = config.id
      @name = config.name
      if config.lastContactState?
        @_contact = config.lastContactState
      super()
      plugin.on "update #{@id}", (msg) =>
        unless msg.values?.state?
          env.logger.error "wrong message from piligt daemon received:", msg
          return
        assert msg.values.state is 'closed' or msg.values.state is 'opened'
        state = (if msg.values.state is 'closed' then on else off)
        @_setContact(state)

    updateFromPilightConfig: (probs) ->
      assert probs?
      @name = probs.name
      @_setContact (if probs.state is 'closed' then on else off)


  class PilightShutter extends env.devices.ShutterController
    probs: null

    constructor: (@config) ->
      assert @config.id?
      assert @config.name?
      assert @config.location?
      assert @config.device?
      assert (
        if @config.lastPosition? 
        then @config.lastPosition in ['down', 'up']
        else true
      ) 

      @id = config.id
      @name = config.name
      if config.lastPosition?
        @_position = config.lastPosition
      super()
      plugin.on "update #{@id}", (msg) =>
        unless msg.values?.state?
          env.logger.error "wrong message from piligt daemon received:", msg
          return
        assert msg.values.state is 'up' or msg.values.state is 'down'
        position = msg.values.state
        @_setPosition(position)

    moveToPosition: (position) ->
      assert position in ['up', 'down']
      jsonMsg = {
        message: "send"
        code:
          location: @config.location
          device: @config.device
          state: position
      }
      return plugin.sendState(@id, jsonMsg, (@_position isnt position))


    updateFromPilightConfig: (probs) ->
      assert probs?
      @name = probs.name
      @_setPosition(probs.state)

  class PilightDimmer extends env.devices.DimmerActuator

    constructor: (@config) ->
      assert @config.id?
      assert @config.name?
      assert @config.location?
      assert @config.device?

      @id = config.id
      @name = config.name
      if config.lastDimlevel?
        @_dimlevel = config.lastDimlevel
        @_state = (config.lastDimlevel > 0)
      super()
      plugin.on "update #{@id}", (msg) =>
        unless msg.values?.dimlevel? or msg.values?.state?
          env.logger.error "wrong message from piligt daemon received:", msg
          return

        if msg.values.dimlevel?
          dimlevel = @_normalizePilightDimlevel(msg.values.dimlevel)
          @_setDimlevel dimlevel
        else if msg.values.state is 'off'
          @_setDimlevel 0
        
    # Run the pilight-send executable.
    changeDimlevelTo: (dimlevel) ->
      assert not isNaN(dimlevel) 
      dimlevel = parseFloat(dimlevel)

      implizitState = (if dimlevel > 0 then "on" else "off")
      jsonMsg = {
        message: "send"
        code:
          location: @config.location
          device: @config.device
          values: 
            dimlevel: (
              if plugin.pilightVersion? and plugin.pilightVersion[0] is "2"
                # pilight 2.1 => Send dimlevel as string
                @_toPilightDimlevel(dimlevel).toString()
              else
                # pilight >2.1 => send dimlevel as number
                @_toPilightDimlevel(dimlevel)
            )
      }

      result1 = plugin.sendState(@id, jsonMsg, (@_dimlevel isnt dimlevel))
    
      if implizitState isnt @_state
        jsonMsg = {
          message: "send"
          code:
            location: @config.location
            device: @config.device
            state: implizitState
        }
        result2 = plugin.sendState(@id, jsonMsg, no)

      return if result2? then Q.all([result1, result2]) else result1
    updateFromPilightConfig: (probs) ->
      assert probs?
      assert probs.dimlevel?
      assert not isNaN(probs.dimlevel)  
      probs.dimlevel = parseFloat(probs.dimlevel)
      @probs = probs
      @name = probs.name
      @_setDimlevel @_normalizePilightDimlevel(probs.dimlevel)

    _setDimlevel: (dimlevel) ->
      if dimlevel is @_dimlevel then return
      super dimlevel
      @config.lastDimlevel = dimlevel
      plugin.framework.saveConfig()

    _normalizePilightDimlevel: (dimlevel) ->
      max = @probs?.settings?.max
      # if not set assume max dimlevel is 15
      unless max? then max = 15
      max = parseInt(max, 10)
      # map it to 0...100
      ndimlevel = 100.0/15.0 * dimlevel
      # and round to nearest 0, 5, 10,...
      remainder = ndimlevel % 5
      ndimlevel = Math.floor(ndimlevel / 5)*5 + (if remainder >= 2.5 then 5 else 0)
      return ndimlevel

    _toPilightDimlevel: (dimlevel) ->
      dimlevel = Math.round(dimlevel / 100.0 * 15.0)
      return dimlevel



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
        @attributes = _.clone @attributes
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

    checkValue: (name, currentTime, value) ->
      isValid = yes
      upperName = name.substr(0,1).toUpperCase() + name.substring(1)
      lastTime = @["_last#{upperName}Time"]
      lastValue = @["_last#{upperName}Value"]
      unless plugin.config["min#{upperName}"] <= value <= plugin.config["max#{upperName}"]
        isValid = no
        env.logger.info "discarding out of range #{name} from pilight: #{value}"
      else if lastTime?
        deltaTime = (currentTime - lastTime)/1000.0
        deltaValue = value - lastValue
        delta = Math.abs(deltaValue/deltaTime)
        env.logger.debug "#{name} delta is #{delta}" if plugin.debug
        if delta > plugin.config["max#{upperName}Delta"]
          isValid = no
          env.logger.info "discarding #{name} above max delta from pilight: #{value}"
      if isValid
        @["_last#{upperName}Time"] = currentTime
        @["_last#{upperName}Value"] = value
      return isValid


    setValues: (values) ->
      assert not isNaN(@config.settings.decimals)
      currentTime = (new Date()).getTime()
      if values.temperature?
        temperature = values.temperature/Math.pow(10, @config.settings.decimals)
        isValid = @checkValue("temperature", currentTime, temperature)
        if isValid
          @temperature = temperature
          @emit "temperature", temperature
          @config.lastTemperature = temperature
      if values.humidity?
        humidity = values.humidity/Math.pow(10, @config.settings.decimals)
        isValid = @checkValue("humidity", currentTime, humidity)
        if isValid
          @humidity = humidity
          @emit "humidity", humidity
          @config.lastHumidity = humidity
      plugin.framework.saveConfig()
      return

    getTemperature: -> Q(@temperature)
    getHumidity: -> Q(@humidity)

  # For testing...
  plugin.PilightSwitch = PilightSwitch
  plugin.PilightDimmer = PilightDimmer
  plugin.PilightTemperatureSensor = PilightTemperatureSensor

  return plugin

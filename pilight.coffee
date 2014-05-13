module.exports = (env) ->
  util = require 'util'

  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'
  _ = env.require 'lodash'
  events = env.require 'events'

  net = env.test?.net or require("net")
  SSDP = env.SSDP or require("node-ssdp-lite")

  class PilightClient extends events.EventEmitter

    constructor: (@config) ->
      @debug = config.debug

      lastError = null
      createSocket = ( (options) =>
        @socket = net.connect(options)
        hadConnection = false
        @socket.on('connect', onConnect = =>
          hadConnection = true
          env.logger.info "connected to pilight-daemon"
          @sendWelcome()
          @startHeartbeat() if @config.enableHeartbeat
        )

        buffer = ''
        @socket.on("data", (data) =>
          # https://github.com/pimatic/pimatic/issues/65
          buffer += data.toString().replace(/\0/g, '')
          if buffer[buffer.length-2] is "\n" or buffer[buffer.length-1] is "\n"
            messages = buffer[..-2]
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
            buffer = ''
        )

        @socket.on("error", (err) =>
          if err.message? and lastError? and err.message is lastError.message
            if @debug
              env.logger.debug "supressed repeated error #{err}"
              env.logger.debug err.stack
          else
            env.logger.error "Error on connection to pilight-daemon: #{err}"
            env.logger.debug err.stack
            lastError = err
        )

        @socket.on('close', =>
          env.logger.warn "Lost connection to pilight-daemon" if hadConnection
          hadConnection = false
          if @heartbeatTimeout
            clearTimeout @heartbeatTimeout
            delete @heartbeatTimeout
        )
      )
      
      if @config.ssdp
        ssdpClient = new SSDP(log: true, logLevel: "error")
        ssdpPilightFound = false

        # only print search  message the first time
        searchSSDP = (printSearchMessage = yes) =>
          if ssdpPilightFound is not true
            #searching for pilight ssdp
            env.logger.info "pilight: trying to find pilight via SSDP" if printSearchMessage
            ssdpClient.search "urn:schemas-upnp-org:service:pilight:1"
            #try searching again in 5s
            setTimeout((=> searchSSDP(no) ),5000)
          else
            env.logger.debug "pilight: skipping ssdp, already found pilight"

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
            createSocket(
              port: portValue,
              host: hostValue
            )
            ssdpPilightFound = true
            @socket.on('close', =>
              ssdpPilightFound = false
              @socket.destroy()
              @socket = null

              searchSSDP()
            )
          else
            env.logger.error "received port is not a number"

        searchSSDP()
      else
        #not using ssdp, connectin normally
        connectDirectly = =>
          createSocket(
            port: @config.port,
            host: @config.host
          )
          @socket.on('close', =>
            @socket.destroy()
            @socket = null
            setTimeout(connectDirectly, 10000)
          )
        connectDirectly()
    sendWelcome: ->
      @send { message: "client gui" }

    send: (jsonMsg) ->
      env.logger.debug("pilight send: ", JSON.stringify(jsonMsg, null, " ")) if @debug
      if @socket?
        @socket.write JSON.stringify(jsonMsg) + "\n", 'utf8'
        return true
      else
        return false

    onReceive: (jsonMsg) ->
      env.logger.debug("pilight received: ", JSON.stringify(jsonMsg, null, " ")) if @debug
      switch 
        when jsonMsg.message is "accept client"
          @send { message: "request config" }
        when jsonMsg.config?
          @emit "config", jsonMsg
        when jsonMsg.origin?
          @emit "update", jsonMsg
      return

    startHeartbeat: ->
      env.logger.debug "startHeartbeat", @config.heartbeatInterval
      if @heartbeatTimeout
        clearTimeout @heartbeatTimeout
        delete @heartbeatTimeout

      sendHeartbeat = =>
        env.logger.debug("sending HEART to pilight-daemon") if @debug
        if @socket?
          try
            @socket.write("HEART\n", 'utf8')
          catch e
            env.logger.warn "Could not send heartbeat to pilight-daemon: #{e.message}"
            @heartbeatTimeout = setTimeout(sendHeartbeat, @config.heartbeatInterval)
        else
          return
        deferred = Q.defer()
        # If we get a beat back then resolve the promise
        @once 'beat', deferred.resolve
        # and set a timeout:
        promise = deferred.promise.timeout(
          @config.timeout, 
          "heartbeat to pilight-daemon timedout after #{@config.timeout}ms."
        ).catch( (e) =>
          env.logger.warn(e.message)
        ).finally(=> 
          # In case of a timeout and in case of an resolve, send next heartbeat
          @heartbeatTimeout = setTimeout(sendHeartbeat, @config.heartbeatInterval) 
        )

      @heartbeatTimeout = setTimeout(sendHeartbeat, @config.heartbeatInterval)

    onBeat: =>
      env.logger.debug("got BEAT from pilight-daemon") if @debug
      @emit "beat"



  class PilightPlugin extends env.plugins.Plugin

    init: (@app, @framework, @config) =>
      conf = convict require("./pilight-config-schema")
      conf.load config
      conf.validate()
      @config = conf.get ""

      @client = new PilightClient(@config)
      


      @client.on "config", onReceiveConfig = (json) =>
        config = json.config
        @pilightVersion = json.version?[0].split('.')
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
          when 1, 4
            isContact = (
              deviceProbs.settings?.states is "opened,closed" or 
              deviceProbs.state in ['closed', 'opened']
            )
            if isContact
              [PilightContact, "PilightContact"]
            else
              [PilightSwitch, "PilightSwitch"]
          when 2 then [PilightDimmer, "PilightDimmer"]
          when 3 then [PilightTemperatureSensor, "PilightTemperatureSensor"]
          when 5 then [PilightShutter, "PilightShutter"]
          else [null, null]

      [Class, ClassName] = getClassFromType deviceProbs
      unless Class?
        env.logger.warn "Unimplemented pilight device type: #{deviceProbs.type}" 
        return

      config = {
        id: id
        name: deviceProbs.name
        class: ClassName
        inPilightConfig: true
        location: deviceProbs.location
        device: deviceProbs.device
      }
      # do some remapping for properites:
      # http://wiki.pilight.org/doku.php/changes_features_fixes?rev=1396735707
      # Temperature devices:
      if deviceProbs.settings?.humidity or deviceProbs['gui-show-humidity'] #old and new
        config.hasHumidity = yes
        deviceProbs['gui-show-humidity'] = yes
      if deviceProbs.settings?.temperature or deviceProbs['gui-show-temperature'] #old and new
        config.hasTemperature = yes
        deviceProbs['gui-show-temperature'] = yes
      if deviceProbs.settings?.decimals? #old
        config.deviceDecimals = parseInt(deviceProbs.settings.decimals, 10)
        deviceProbs['device-decimals'] = config.deviceDecimals
      if deviceProbs['device-decimals']? #new
        config.deviceDecimals = deviceProbs['device-decimals']
      # Dimmer devices
      if deviceProbs.min? #old
        config.minDimlevel = parseInt(deviceProbs.min, 10)
      if deviceProbs.settings?.min? #old
        config.minDimlevel = parseInt(deviceProbs.settings.min, 10)
        deviceProbs['dimlevel-minimum'] = config.minDimlevel
      if deviceProbs['dimlevel-minimum']? #new
        config.minDimlevel = parseInt(deviceProbs['dimlevel-minimum'], 10)

      if deviceProbs.max? #old
        config.maxDimlevel = parseInt(deviceProbs.max, 10)
      if deviceProbs.settings?.max? #old
        config.maxDimlevel = parseInt(deviceProbs.settings.max, 10)
        deviceProbs['dimlevel-maximum'] = config.maxDimlevel
      if deviceProbs['dimlevel-maximum']? #new
        config.maxDimlevel = parseInt(deviceProbs['dimlevel-maximum'], 10)

      actuator = @framework.getDeviceById id
      if actuator?
        unless actuator instanceof Class
          env.logger.error "expected #{id} to be an #{ClassName}"
          return
      else 
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

      handleLegacyConfig = (config) =>
        if config.settings
          # TemperatureSensor
          if config.settings.temperature?
            config.hasTemperature = !!(config.settings.temperature)
          if config.settings.humidity?
            config.hasHumidity = !!(config.settings.humidity)
          if config.settings.decimals?
            config.deviceDecimals = parseInt(config.settings.decimals, 10)
          # Dimmer
          if config.settings.min?
            config.minDimlevel = parseInt(config.settings.min, 10)
          else
            config.minDimlevel = 0
          if config.settings.max?
            config.maxDimlevel = parseInt(config.settings.max, 10)
          else
            config.maxDimlevel = 15
          # Delete settings
          delete config.settings

      return switch config.class
        when 'PilightSwitch'
          handleLegacyConfig(config)
          @framework.registerDevice new PilightSwitch config
          true
        when 'PilightDimmer'
          handleLegacyConfig(config)
          @framework.registerDevice new PilightDimmer config
          true
        when 'PilightTemperatureSensor'
          handleLegacyConfig(config)
          @framework.registerDevice new PilightTemperatureSensor config
          true
        when 'PilightShutter'
          handleLegacyConfig(config)
          @framework.registerDevice new PilightShutter config
          true
        when 'PilightContact'
          handleLegacyConfig(config)
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
        then @config.lastPosition in ['down', 'up', 'stopped']
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
        @_lastPilightPosition = position

    moveToPosition: (position) ->
      assert position in ['up', 'down']
      jsonMsg = {
        message: "send"
        code:
          location: @config.location
          device: @config.device
          state: position
      }
      return plugin.sendState(@id, jsonMsg, (@_lastPilightPosition isnt position)).then( =>
        @_setPosition(position)
      )

    stop: () ->
      if @_position is 'stopped' then return Q()
      jsonMsg = {
        message: "send"
        code:
          location: @config.location
          device: @config.device
          state: @_position
      }
      return plugin.sendState(@id, jsonMsg, no).then( =>
        @_setPosition('stopped')
      )

    updateFromPilightConfig: (probs) ->
      assert probs?
      @name = probs.name
      @_setPosition(probs.state)
      @_lastPilightPosition = probs.state

  class PilightDimmer extends env.devices.DimmerActuator

    constructor: (@config) ->
      assert @config.id?
      assert @config.name?
      assert @config.location?
      assert @config.device?
      assert @config.minDimlevel?
      assert @config.maxDimlevel?

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
          @_lastPilightDimlevel = parseFloat(msg.values.dimlevel)
          dimlevel = @_normalizePilightDimlevel(@_lastPilightDimlevel )
          @_setDimlevel dimlevel
        else if msg.values.state is 'off'
          @_setDimlevel 0
        else if msg.values.state is 'on'
          if @_lastPilightDimlevel?
            @_setDimlevel @_normalizePilightDimlevel(@_lastPilightDimlevel)
        
    # Run the pilight-send executable.
    changeDimlevelTo: (dimlevel) ->
      dimlevel = parseFloat(dimlevel)
      assert not isNaN(dimlevel) 

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
      @config.minDimlevel = probs['dimlevel-minimum'] if probs['dimlevel-minimum']?
      @config.maxDimlevel = probs['dimlevel-maximum'] if probs['dimlevel-maximum']?
      probs.dimlevel = parseFloat(probs.dimlevel)
      assert not isNaN(probs.dimlevel)
      @_lastPilightDimlevel = probs.dimlevel
      @_setDimlevel @_normalizePilightDimlevel(probs.dimlevel)

    _setDimlevel: (dimlevel) ->
      if dimlevel is @_dimlevel then return
      super dimlevel
      @config.lastDimlevel = dimlevel
      plugin.framework.saveConfig()

    _normalizePilightDimlevel: (dimlevel) ->
      max = parseInt(@config.maxDimlevel, 10)
      # map it to 0...100
      ndimlevel = 100.0/max * dimlevel
      # and round to nearest 0, 5, 10,...
      remainder = ndimlevel % 5
      ndimlevel = Math.floor(ndimlevel / 5)*5 + (if remainder >= 2.5 then 5 else 0)
      return ndimlevel

    _toPilightDimlevel: (dimlevel) ->
      max = parseInt(@config.maxDimlevel, 10)
      dimlevel = Math.round(dimlevel / 100.0 * max)
      return dimlevel

  class PilightTemperatureSensor extends env.devices.TemperatureSensor
    temperature: null
    humidity: null

    constructor: (@config) ->
      assert @config.id?
      assert @config.name?

      @id = @config.id
      @name = @config.name
      if @config.lastTemperature?
        @temperature = @config.lastTemperature
      if @config.lastHumidity?
        @humidity = @config.lastHumidity

      if @config.hasHumidity
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
      @config.deviceDecimals = probs['device-decimals'] if probs['device-decimals']?
      @config.hasHumidity = (probs['gui-show-humidity'] is yes)
      @config.hasTemperature = (probs['gui-show-temperature'] is yes)
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
      @config.deviceDecimals = parseFloat(@config.deviceDecimals)
      assert(not isNaN(@config.deviceDecimals))

      currentTime = (new Date()).getTime()
      if values.temperature?
        temperature = values.temperature/Math.pow(10, @config.deviceDecimals)
        isValid = @checkValue("temperature", currentTime, temperature)
        if isValid
          @temperature = temperature
          @emit "temperature", temperature
          @config.lastTemperature = temperature
      if values.humidity?
        humidity = values.humidity/Math.pow(10, @config.deviceDecimals)
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

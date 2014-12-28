module.exports = (env) ->

  sinon = env.require 'sinon'
  assert = env.require "cassert"
  proxyquire = env.require 'proxyquire'
  Promise = env.require 'bluebird'
  declapi = env.require 'decl-api'
  events = require 'events'

  describe "pimatic-pilight", ->

    # env.test =
    #   net:
    #     connect: (options) =>
    #       class SocketDummy extends require('events').EventEmitter
    #         constructor: ({port, host}) -> 
    #           env.test.net.connectCalled = true
    #           assert host?
    #           assert port? and not isNaN port
    #       return new SocketDummy(options)
    # env.SSDP = =>

    # pilightPlugin = require('pimatic-pilight') env

    # framework = new events.EventEmitter()
    # framework.deviceManager = {
    #   deviceClasses: {}
    #   registerDeviceClass: (name, op) -> @deviceClasses[name] = op
    #   addDeviceByConfig: (deviceConfig) ->
    #     classInfo = @deviceClasses[deviceConfig.class]
    #     unless classInfo?
    #       throw new Error("Unknown device class \"#{deviceConfig.class}\"")
    #     warnings = []
    #     classInfo.prepareConfig(deviceConfig) if classInfo.prepareConfig?
    #     declapi.checkConfig(classInfo.configDef.properties, deviceConfig, warnings)
    #     for w in warnings
    #       env.logger.warn("Device configuration of #{deviceConfig.id}: #{w}")
    #     deviceConfig = declapi.enhanceJsonSchemaWithDefaults(classInfo.configDef, deviceConfig)
    #     device = classInfo.createCallback(deviceConfig)
    #     @addDeviceToConfig(deviceConfig)
    #     @registerDevice(device)
    #     framework.saveConfig()
    #     return device
    # }
    # pilightSwitch = null
    # pilightDimmer = null
    # pilightTemperatureSensor = null

    describe "PilightPlugin", ->
      describe '#init()', ->
        it "should connect", ->
          # schema = require('../pilight-config-schema')
          # pluginConfig = declapi.enhanceJsonSchemaWithDefaults(schema, {
          #   timeout: 1000
          #   debug: false
          #   ssdp: no
          #   host: 'localhost'
          #   port: 123
          # });
          # pilightPlugin.init(null, framework, pluginConfig)
          # framework.emit 'after init', {}
          # assert env.test.net.connectCalled
          
        it "should send welcome", ->
          # pilightPlugin.client.socket.write = (data) ->
          #   @writeCalled = true
          #   msg = JSON.parse data
          #   assert msg.message is "client gui" 

          # pilightPlugin.client.socket.emit "connect"
          # assert pilightPlugin.client.socket.writeCalled

      describe "#onReceive()", ->
        it "should request config", ->
          # pilightPlugin.client.socket.writeCalled = false
          # pilightPlugin.client.socket.write = (data) ->
          #   @writeCalled = true
          #   msg = JSON.parse data
          #   assert msg.message is "request config" 

          # pilightPlugin.client.socket.emit 'data', JSON.stringify(
          #   message: "accept client"
          # ) + "\n"

          # assert pilightPlugin.client.socket.writeCalled 

        it "should create a PilightSwitch", ->
          # sampleConfigMsg =
          #   config:
          #     living:
          #       name: "Living"
          #       order: 1
          #       bookshelve:
          #         type: 1
          #         name: "Book Shelve Light"
          #         protocol: ["kaku_switch"]
          #         id: [
          #           id: 1234
          #           unit: 0
          #         ]
          #         state: "off"
          #   version: [
          #     "2.0"
          #     "2.0"
          #   ]

          # framework.deviceManager.getDeviceByIdCalled = false
          # framework.deviceManager.getDeviceById = (id) ->
          #   assert id is "pilight-living-bookshelve"
          #   @getDeviceByIdCalled = true
          #   return null

          # framework.deviceManager.registerDeviceCalled = false
          # framework.deviceManager.registerDevice = (device) ->
          #   @registerDeviceCalled = true
          #   assert device?
          #   assert device instanceof pilightPlugin.PilightSwitch
          #   pilightSwitch = device
          #   assert pilightSwitch._constructorCalled
          #   assert pilightSwitch.config.device is "bookshelve"
          #   assert pilightSwitch.config.location is "living"

          # framework.deviceManager.addDeviceToConfigCalled = false
          # framework.deviceManager.addDeviceToConfig = (config) ->
          #   @addDeviceToConfigCalled = true
          #   assert config?

          # framework.deviceManager.saveConfigCalled = false
          # framework.saveConfig = () ->
          #   @saveConfigCalled = true
          #   assert pilightSwitch._state is false

          # pilightPlugin.client.socket.emit 'data', JSON.stringify(sampleConfigMsg) + '\n'

          # assert framework.deviceManager.getDeviceByIdCalled
          # assert framework.deviceManager.registerDeviceCalled
          # assert framework.deviceManager.addDeviceToConfigCalled
          # assert framework.saveConfigCalled

        it "should create a PilightDimmer", ->
          # sampleConfigMsg =
          #   config:
          #     living:
          #       name: "Living"
          #       dimmer:
          #         type: 2
          #         name: "Dimmer"
          #         protocol: ["generic_dimmer"]
          #         id: [id: 1234]
          #         state: "on"
          #         dimlevel: 10
          #         min: 0
          #         max: 15
          #   version: [
          #     "2.0"
          #     "2.0"
          #   ]

          # framework.deviceManager.getDeviceByIdCalled = false
          # framework.deviceManager.getDeviceById = (id) ->
          #   assert id is "pilight-living-dimmer"
          #   @getDeviceByIdCalled = true
          #   return null

          # framework.deviceManager.registerDeviceCalled = false
          # framework.deviceManager.registerDevice = (device) ->
          #   @registerDeviceCalled = true
          #   assert device?
          #   assert device instanceof pilightPlugin.PilightDimmer
          #   pilightDimmer = device
          #   assert pilightDimmer._constructorCalled
          #   assert pilightDimmer.config.device is "dimmer"
          #   assert pilightDimmer.config.location is "living"

          # framework.deviceManager.addDeviceToConfigCalled = false
          # framework.deviceManager.addDeviceToConfig = (config) ->
          #   @addDeviceToConfigCalled = true
          #   assert config?

          # framework.saveConfigCalled = false
          # framework.saveConfig = () ->
          #   @saveConfigCalled = true

          # pilightPlugin.client.socket.emit 'data', JSON.stringify(sampleConfigMsg) + '\n'

          # assert framework.deviceManager.getDeviceByIdCalled
          # assert framework.deviceManager.registerDeviceCalled
          # assert framework.deviceManager.addDeviceToConfigCalled
          # assert framework.saveConfigCalled

          # assert pilightDimmer._dimlevel is 65 # 15 => 100% so 10 => 65%
          # assert pilightDimmer._state is on

        it "should create a PilightTemperatureSensor", ->
          # sampleConfigMsg =
          #   config:
          #    living:
          #     name: "Living"
          #     weather:
          #       type: 3
          #       name: "Weather"
          #       protocol: ["generic_weather"]
          #       id: [id: 100]
          #       temperature: 2300
          #       humidity: 7600
          #       battery: 0
          #       settings: 
          #         decimals: 2
          #         temperature: 1
          #         humidity: 0
          #   version: [
          #     "2.0"
          #     "2.0"
          #   ]

          # framework.deviceManager.getDeviceByIdCalled = false
          # framework.deviceManager.getDeviceById = (id) ->
          #   assert id is "pilight-living-weather"
          #   @getDeviceByIdCalled = true
          #   return null

          # framework.deviceManager.registerDeviceCalled = false
          # framework.deviceManager.registerDevice = (device) ->
          #   @registerDeviceCalled = true
          #   assert device?
          #   assert device instanceof pilightPlugin.PilightTemperatureSensor
          #   pilightTemperatureSensor = device
          #   assert pilightTemperatureSensor._constructorCalled
          #   assert pilightTemperatureSensor.config.device is "weather"
          #   assert pilightTemperatureSensor.config.location is "living"

          # framework.deviceManager.addDeviceToConfigCalled = false
          # framework.deviceManager.addDeviceToConfig = (config) ->
          #   @addDeviceToConfigCalled = true
          #   assert config?

          # framework.saveConfigCalled = false
          # framework.saveConfig = () ->
          #   @saveConfigCalled = true

          # pilightPlugin.client.socket.emit 'data', JSON.stringify(sampleConfigMsg) + '\n'

          # assert framework.deviceManager.getDeviceByIdCalled
          # assert framework.deviceManager.registerDeviceCalled
          # assert framework.deviceManager.addDeviceToConfigCalled
          # assert framework.saveConfigCalled

          # assert pilightTemperatureSensor.temperature is 23
          # assert pilightTemperatureSensor.humidity is 76

    describe "PilightSwitch", ->  
      describe "#turnOn()", ->
        it "should send turnOn", (finish)->
          # framework.saveConfigCalled = false
          # framework.saveConfig = () ->
          #   @saveConfigCalled = true
          # gotData = false
          # pilightPlugin.client.socket.write = (data) ->
          #   gotData = true
          #   msg = JSON.parse data
          #   assert msg?
          #   assert msg.message is 'send'
          #   assert msg.code?
          #   assert msg.code.location is 'living'
          #   assert msg.code.device is 'bookshelve'
          #   assert msg.code.state is "on"

          #   setTimeout( () ->
          #     msg = 
          #       origin: "config"
          #       type: 1
          #       devices:
          #         living: ["bookshelve"]
          #       values:
          #         state: "on"
          #     pilightPlugin.client.socket.emit 'data', JSON.stringify(msg) + "\n"
          #   , 1)

          # pilightSwitch.turnOn().then( ->
          #   assert gotData
          #   finish()
          # ).done()

        it "turnOn should timeout", (finish) ->
          # this.timeout 5000
          # pilightPlugin.config.timeout = 200

          # gotData = false
          # pilightPlugin.client.socket.write = (data) ->
          #   gotData = true
          #   msg = JSON.parse data
          #   assert msg?
          #   assert msg.message is 'send'
          #   assert msg.code?
          #   assert msg.code.location is 'living'
          #   assert msg.code.device is 'bookshelve'

          # pilightSwitch.turnOn().then( -> 
          #   assert false
          # ).catch( (error) ->
          #   assert error? 
          #   finish() 
          # ).done()

      describe "#turnOff()", ->
        it "should send turnOff", (finish)->
          # this.timeout 1000

          # framework.saveConfigCalled = false
          # framework.saveConfig = () ->
          #   @saveConfigCalled = true

          # gotData = false
          # pilightPlugin.client.socket.write = (data) ->
          #   gotData = true
          #   msg = JSON.parse data
          #   assert msg?
          #   assert msg.message is 'send'
          #   assert msg.code?
          #   assert msg.code.location is 'living'
          #   assert msg.code.device is 'bookshelve'
          #   assert msg.code.state is "off"

          #   setTimeout( () ->
          #     msg = 
          #       origin: "config"
          #       type: 1
          #       devices:
          #         living: ["bookshelve"]
          #       values:
          #         state: "off"
          #     pilightPlugin.client.socket.emit 'data', JSON.stringify(msg) + "\n"
          #   , 1)

          # pilightSwitch.turnOff().then( ->
          #   assert gotData
          #   finish()
          # ).done()

    describe "PilightDimmer", ->  
      # test need to be fixes:
      # describe "#turnOn()", ->
      #   it "should send turnOn", (finish)->
      #     framework.saveConfigCalled = false
      #     framework.saveConfig = () ->
      #       @saveConfigCalled = true

      #     gotData = false
      #     pilightPlugin.client.socket.write = (data) ->
      #       gotData = true
      #       msg = JSON.parse data
      #       assert msg?
      #       assert msg.message is 'send'
      #       assert msg.code?
      #       assert msg.code.location is 'living'
      #       assert msg.code.device is 'dimmer'
      #       assert msg.code.state is "on"
      #       assert msg.values?
      #       assert msg.values.dimlevel is "15"

      #       setTimeout( () ->
      #         msg = 
      #           origin: "config"
      #           type: 1
      #           devices:
      #             living: ["dimmer"]
      #           values:
      #             state: "on"
      #             dimlevel: "15"
      #         pilightPlugin.client.emit 'data', JSON.stringify(msg) + "\n"
      #       , 1)

      #     pilightDimmer.turnOn().then( ->
      #       assert gotData
      #       assert pilightDimmer._dimlevel is 100
      #       assert pilightDimmer._state is on
      #       finish()
      #     ).done()

      # describe "#turnOff()", ->
      #   it "should send turnOff", (finish)->
      #     this.timeout 1000


      #     framework.saveConfigCalled = false
      #     framework.saveConfig = () ->
      #       @saveConfigCalled = true

      #     gotData = false
      #     pilightPlugin.client.socket.write = (data) ->
      #       gotData = true
      #       msg = JSON.parse data
      #       assert msg?
      #       assert msg.message is 'send'
      #       assert msg.code?
      #       assert msg.code.location is 'living'
      #       assert msg.code.device is 'dimmer'
      #       assert msg.code.state is 'off'
      #       assert msg.values?
      #       assert msg.values.dimlevel is "0"

      #       setTimeout( () ->
      #         msg = 
      #           origin: "config"
      #           type: 1
      #           devices:
      #             living: ["dimmer"]
      #           values:
      #             state: "off"
      #             dimlevel: "0"
      #         pilightPlugin.client.emit 'data', JSON.stringify(msg) + "\n"
      #       , 1)

      #     pilightDimmer.turnOff().then( ->
      #       assert gotData
      #       assert pilightDimmer._dimlevel is 0
      #       assert pilightDimmer._state is off
      #       finish()
      #     ).done()


      describe "#changeDimlevelTo()", ->

        it "should change the dimlevel to 20", (finish)->

          # framework.saveConfigCalled = false
          # framework.saveConfig = () ->
          #   @saveConfigCalled = true

          # gotData = false
          # pilightPlugin.client.socket.write = (data) ->
          #   gotData = true
          #   pilightPlugin.client.socket.write = (data) -> #nop
          #   msg = JSON.parse data
          #   assert msg?
          #   assert msg.message is 'send'
          #   assert msg.code?
          #   assert msg.code.location is 'living'
          #   assert msg.code.device is 'dimmer'
          #   assert msg.code.values?
          #   assert msg.code.values.dimlevel is "3" # 100% => dimlevel 15

          #   setTimeout( () ->
          #     msg = 
          #       origin: "config"
          #       type: 1
          #       devices:
          #         living: ["dimmer"]
          #       values:
          #         state: "off"
          #         dimlevel: "3"
          #     pilightPlugin.client.socket.emit 'data', JSON.stringify(msg) + "\n"
          #   , 1)

          # pilightDimmer.changeDimlevelTo(20).then( ->
          #   assert gotData
          #   assert pilightDimmer._dimlevel is 20
          #   assert pilightDimmer._state is on
          #   finish()
          # ).done()

        it "turnOn should timeout", (finish) ->
          # this.timeout 5000
          # pilightPlugin.config.timeout = 200

          # gotData = false
          # pilightPlugin.client.socket.write = (data) ->
          #   gotData = true
          #   msg = JSON.parse data
          #   assert msg?
          #   assert msg.message is 'send'
          #   assert msg.code?
          #   assert msg.code.location is 'living'
          #   assert msg.code.device is 'dimmer'

          # pilightDimmer.turnOn().then( -> 
          #   assert false
          # ).catch( (error) ->
          #   assert error? 
          #   finish() 
          # ).done()

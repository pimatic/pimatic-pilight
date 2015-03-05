pimatic pilight plugin
======================

Deprecated notice
-----------------

**The plugin currently works only with the (outdated) pilight v5. We are looking for a new maintainer for the plugin, because 
the [homeduino plugin](https://github.com/pimatic/pimatic-homeduino) replaced most of pilights functionality and we will put our effort into this new standalone solution.**

About
-----------------

Plugin for the integration of [pilight](https://github.com/pilight/pilight) to control 433Mhz switches 
and dimmers and get informations from 433Mhz weather stations. See the project page for a list of 
[supported devices](http://wiki.pilight.org/doku.php/protocols). The pilight-daemon must be running 
to use this plugin.

Configuration
-------------
You can load the backend by editing your `config.json` to include:

    { 
       "plugin": "pilight"
    }

in the `plugins` section. For all configuration options see 
[pilight-config-schema](pilight-config-schema.html)

Devices are automatically added from the pilight-daemon config, when the connection is established. 

If you are using pilight 3.0 or later turn [ssdp](http://en.wikipedia.org/wiki/Simple_Service_Discovery_Protocol) on to auto detect ip and port:

    { 
       "plugin": "pilight",
       "ssdp": true
    }

Contributors
----------
Thanks to [thexperiments](https://github.com/thexperiments) for adding SSDP support.
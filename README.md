pimatic pilight plugin
======================

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
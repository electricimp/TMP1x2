# TMP1x2

Driver class for the TMP102 and TMP112 digital temperature sensors. The TMP1x2 class allows you to read the current temperature, as well as configure various interupts (the TMP1x2 class allows you to configure interrupts, however it does not deal with handling callbacks).

**To add this library to your project, add** `#require "tmp1x2.class.nut:1.0.0"` **to the top of your device code**

## Class Usage

### Constructor

To instantiate a new TMP1x2 object, you need to pass in a configured I2C object, and an optional I2C address. If no address is supplied, a default address of ```0x90``` will be use:

```squirrel
#require "tmp1x2.class.nut:1.0.0"

i2c  <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

temp <- TMP1x2(i2c);
```

### temp.read(*[callback]*)

The **read** function reads and returns the the current temperature in celsius. If a callback is supplied, the read will execute asynchrounously and the result will be passed to the callback function - if no callback is supplied, the read will execute synchronously and an object containing the sensor data will be returned.

```squirrel
temp.read(function(result) {
    if ("err" in result) {
        // if we get an error, log it
        server.log("Error Reading TMP102: "+err);
        return;
    }

    // if it was successful, do something with it
    console.log(result.temp + "");
});
```

**NOTE:** If an error occured during the read, an ```err``` key will be present in the data - you should *always* check for the existance of the ```err``` key before using the results:


## License

The TMP1x2 library is licensed under the [MIT License](./LICENSE).

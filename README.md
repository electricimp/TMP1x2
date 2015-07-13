# TMP1x2

Driver class for the [TMP102](http://www.ti.com.cn/cn/lit/ds/symlink/tmp102.pdf) and [TMP112](http://www.ti.com/lit/ds/symlink/tmp112.pdf) digital temperature sensors. The TMP1x2 class allows you to read the current temperature, as well as configure various interupts (the TMP1x2 class allows you to configure interrupts, however it does not deal with handling callbacks).

## Class Usage

### Constructor

To instantiate a new TMP1x2 object, you need to pass in a configured I2C object, and an optional I2C address. If no address is supplied, a default address of ```0x90``` will be use:

```squirrel
#require "tmp1x2.class.nut:1.0.0"

i2c  <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

temp <- TMP1x2(i2c);
```

### read(*[callback]*)

The **read** function reads and returns the the current temperature in celsius. If a callback is supplied, the read will execute asynchrounously and the result will be passed to the callback function - if no callback is supplied, the read will execute synchronously and an object containing the sensor data will be returned.

```squirrel
temp.read(function(result) {
    if ("err" in result) {
        server.log("Error Reading TMP102: " + result.err);
        return;
    }
    server.log(result.temp + " degrees C");
});
```

**NOTE:** If an error occured during the read, an ```err``` key will be present in the data - you should *always* check for the existance of the ```err``` key before using the results:

### setHighThreshold(*threshold*)

Sets the THigh threshold register (in degrees C).

```squirrel
// The high threshold to 30 degrees C
temp.setHighThreshold(30);
```

### getHighThreshold()

Returns the THigh threshold in degrees C.

```squirrel
server.log(temp.getHighThreshold());
```


### setLowThreshold(*threshold*)

Sets the TLow threshold register (in degrees C).

```squirrel
// The low threshold to 18 degrees C
temp.setHighThreshold(18);
```

### getLowThreshold()

Returns the TLow threshold in degrees C.

```squirrel
server.log(temp.getLowThreshold());
```

### setShutdownMode(state)

Sets the shutdown mode for the TMP1x2 sensor (1 or 0). When shutdown is set to 1, the tmp1x2 enters a low power sleep mode. When shutdown is set to 0, the tmp1x2 maintains a continous converstion state.

```squirrel
function goToSleep() {
    // Turn off the tmp1x2 and go to sleep;
    temp.setShutdownMode(1);
    imp.onidle(function() { server.sleepfor(3600); });
}

goToSleep();
```

### getShutdownMode()

Returns the current shutdown mode state (0 or 1)

```squirrel
function onWake() {
    // Wake the tmp1x2 if it's asleep
    if (temp.getShutdownMode() == 1) {
        temp.setShutdownMode(0);
    }
}
```

### setModeComparator()

Enables comparator mode. In comparator mode, the Alert pin is activated when the temperature equals or exceeds the value in the THigh register and it remains active until the temperature falls below the value in the TLow register.

```squirrel
// Setup interrupt to trigger when temp is above 30 degrees C,
// and remain active until it drops below 28 degrees C
temp.setHighThreshold(30);
temp.setLowThreshold(28);
temp.setModeComparator();
```

### setModeInterrupt()

Enables interrupt mode. In interrupte mode, the Alert pin is activated when the temperature exceeds THigh or goes below TLow. The Alert pin is cleared when the host controller reads the temperature register.

```squirrel
// Setup interrupt to trigger when temp is above 30 degrees C, or below 15 degrees C.
temp.setHighThreshold(30);
temp.setLowThreshold(15);
temp.setModeInterrupt();
```

### setActiveLow()

Sets the interrupt pin to be active low.

### setActiveHigh()

Sets the interrupt pin to be active high.

### setExtMode(state)

Sets the extended mode state (0 or 1). When extended mode is enabled, the tmp1x2 can read temperatures above 128 degrees C.

```squirrel
// We need really high temperatures..
temp.setExtMode(1);
```

### getExtMode()

Returns the current extended mode state (1 or 0).

## License

The TMP1x2 library is licensed under the [MIT License](./LICENSE).

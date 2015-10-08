# TMP1x2

Driver class for the [TMP102](http://www.ti.com.cn/cn/lit/ds/symlink/tmp102.pdf) and [TMP112](http://www.ti.com/lit/ds/symlink/tmp112.pdf) digital temperature sensors. The TMP1x2 class allows you to read the current temperature, as well as configure various interupts.

**To add this library to your project, add `#require "TMP1x2.class.nut:1.0.3"` to the top of your device code.**

You can view the library’s source code on [GitHub](https://github.com/electricimp/tmp1x2/tree/v1.0.3).


## Class Usage

### Constructor: TMP1x2(*i2c, [addr]*)

To instantiate a new TMP1x2 object, you need to pass in a configured I2C object, and an optional I2C address. If no address is supplied, a default address of ```0x90``` will be use:

```squirrel
#require "TMP1x2.class.nut:1.0.3"

i2c  <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

tmp <- TMP1x2(i2c);
```

## Class Methods

### read(*[callback]*)

The **read** function reads and returns the the current temperature in celsius. If a callback is supplied, the read will execute asynchrounously and the result will be passed to the callback function - if no callback is supplied, the read will execute synchronously and an object containing the sensor data will be returned.

```squirrel
tmp.read(function(result) {
    if ("err" in result) {
        server.log("Error Reading TMP102: " + result.err);
        return;
    }
    server.log(result.temp + " degrees C");
});
```

**NOTE:** If an error occured during the read, an ```err``` key will be present in the data - you should *always* check for the existance of the ```err``` key before using the results:

### setShutdown(state)

Sets the shutdown mode for the TMP1x2 sensor (1 or 0). When shutdown is set to 1, the tmp1x2 enters a low power sleep mode. When shutdown is set to 0, the tmp1x2 maintains a continous converstion state.

```squirrel
function goToSleep() {
    // Turn off the tmp1x2 and go to sleep;
    tmp.setShutdown(1);
    imp.onidle(function() { server.sleepfor(3600); });
}

goToSleep();
```

### getShutdown()

Returns the current shutdown mode state (0 or 1)

```squirrel
function onWake() {
    // Wake the tmp1x2 if it's asleep
    if (tmp.getShutdown() == 1) {
        tmp.setShutdown(0);
    }
}
```

### setExtMode(state)

Sets the extended mode state (0 or 1). When extended mode is enabled, the tmp1x2 can read temperatures above 128 degrees C. **NOTE: You will need to reset high and low thresholds if extended mode state changes.**

```squirrel
// We need really high temperatures..
tmp.setExtMode(1);
```

### getExtMode()

Returns the current extended mode state (1 or 0).

## Interrupt Methods

### Using Interrupts

The TMP1x2 class allows you to configure interrupts, however it does not deal with configuring the interrupt pin, or handling interrupt callbacks. In order to use interrupts, we must do three things:

- Connect the **ALERT** pin of the TMP1x2 to a GPIO pin on the imp
- Configure the DIGITAL_IN pin and handle the interrupt.
- Configure the interrupt parameters (with *.setHighThreshold()*, *.setLowThreshold())*, *.setModeComparator()*, *.setModeInterrupt()*, *.setActiveHigh()*, and *.setActiveLow()*)

```squirrel
#require "TMP1x2.class.nut:1.0.3"

// Configure the I2C bus
i2c  <- hardware.i2c89;
i2c.configure(CLOCK_SPEED_400_KHZ);

// Create the TMP1x2 object
tmp <- TMP1x2(i2c);

// Configure the alert pin to go high when temp is > 30C, or < 15C
tmp.setActiveHigh();
tmp.setHighThreshold(30);
tmp.setLowThreshold(15);
tmp.setModeInterrupt();

// Create our interrupt handler
function interruptHandler() {
    // Ignore falling edge case
    if (alert.read() == 0) return;

    // Log the temperature
    tmp.read(function(result) {
        if ("err" in result) {
            server.log("Error Reading TMP102: " + result.err);
            return;
        }
        server.log(result.temp + " degrees C");
    });
}

// Configure the interrupt pin
alert <- hardware.pin1;
alert.configure(DIGITAL_IN, interruptHandler);
```

### setHighThreshold(*threshold*)

Sets the THigh threshold register (in degrees C).  **NOTE: You will need to reset threshold if extended mode state changes.**

*See [Using Interrupts](#using-interrupts) for more information.*

### setLowThreshold(*threshold*)

Sets the TLow threshold register (in degrees C). **NOTE: You will need to reset threshold if extended mode state changes.**

*See [Using Interrupts](#using-interrupts) for more information.*

### setModeComparator()

Enables comparator mode. In comparator mode, the Alert pin is activated when the temperature equals or exceeds the value in the THigh register and it remains active until the temperature falls below the value in the TLow register.

*See [Using Interrupts](#using-interrupts) for more information.*

### setModeInterrupt()

Enables interrupt mode. In interrupte mode, the Alert pin is activated when the temperature exceeds THigh or goes below TLow. The Alert pin is cleared when the host controller reads the temperature register.

*See [Using Interrupts](#using-interrupts) for more information.*

### setActiveLow()

Sets the interrupt pin to be active low.

*See [Using Interrupts](#using-interrupts) for more information.*

### setActiveHigh()

Sets the interrupt pin to be active high.

*See [Using Interrupts](#using-interrupts) for more information.*

### getHighThreshold()

Returns the THigh threshold in degrees C.

```squirrel
server.log(tmp.getHighThreshold());
```

### getLowThreshold()

Returns the TLow threshold in degrees C.

```squirrel
server.log(tmp.getLowThreshold());
```

## License

The TMP1x2 library is licensed under the [MIT License](https://github.com/electricimp/TMP1x2/blob/master/LICENSE).

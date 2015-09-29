class TMP1x2 {

    static version = [1, 0, 2];

    // Errors
    static TIMEOUT_ERROR = "TMP1x2 conversion timed out";

    // Register addresses
    static TEMP_REG         = 0x00;
    static CONF_REG         = 0x01;
    static T_LOW_REG        = 0x02;
    static T_HIGH_REG       = 0x03;

    // ADC resolution in degrees C
    static DEG_PER_COUNT    = 0.0625;

    // Breakable tight loop for conversion_done
    static CONVERSION_POLL_INTERVAL = 0;
    // Timeout in seconds
    static CONVERSION_TIMEOUT = 0.5;

    // i2c address
    _addr   = null;
    _i2c    = null;

    // Callbacks for conversion
    _conversion_timeout_timer = null;
    _conversion_poll_timer = null;
    _conversion_ready_cb = null;

    // Parameters:
    //    i2c        A preconfigured I2C bus
    //    addr       The base address of the tmp1x2 device
    constructor(i2c, addr = 0x90) {
        _addr   = addr;
        _i2c    = i2c;
    }

    // Reads and returns the current temperature. If the callback parameter
    // is included, it will read asynchronously, otherwise it will read
    // syncronously and return the data table (see below).
    //
    // Parameters:
    //    cb         An optional callback with 1 parameter (data)
    //                  The data parameter will always have a key called
    //                  'temp' with the temperature in degrees C
    //                  If an error occured, temp will be null, and an
    //                  additional key ('err') will be present
    function read(cb = null) {

        if (getShutdown()) {
            _startConversion();

            if (cb != null) {
                // Asynchronous path
                local boundThis = this;

                // set a timeout callback
                _conversion_timeout_timer = imp.wakeup(CONVERSION_TIMEOUT, function() {
                    // Failure: cancel polling for a result and call the callback with error
                    imp.cancelwakeup(boundThis._conversion_poll_timer);
                    boundThis._conversion_ready_cb =  null;
                    imp.wakeup(0, function() { cb({ "err": TMP1x2.TIMEOUT_ERROR, "temp": null }); });
                });

                _pollForConversion(function() {
                    imp.wakeup(0, function() { cb({ "temp": boundThis._rawToTemp(boundThis._getReg(TEMP_REG)) }); });
                });
            } else {
                // Synchronous path

                // Get the start time for timeout
                local start = hardware.millis();
                local timeout = CONVERSION_TIMEOUT * 1000;

                // Wait until timeout or a successful read
                while (!_getConvReady() && (hardware.millis() - start) < timeout) {
                    //NOP: waiting
                }

                // If we timed out
                if ((hardware.millis() - start) >= timeout) {
                    return { "err": TMP1x2.TIMEOUT_ERROR, "temp": null };
                }

                // If we had a successful read
                return { "temp": _rawToTemp(_getReg(TEMP_REG)) };
            }
        } else {
            local temp = _rawToTemp(_getReg(TEMP_REG));
            if (cb != null) {
                imp.wakeup(0, function() { cb({ "temp": temp }); });
                return;
            }
            return { "temp": temp };
        }
    }

    // Sets the THigh threshold register
    //
    // Parameters:
    //    ths        The temperature in degrees C (integer)
    function setHighThreshold(ths) {
        _setReg(T_HIGH_REG, _tempToRaw(ths));
    }

    // Returns the THigh threshold in degrees C
    function getHighThreshold() {
        return _rawToTemp(_getReg(T_HIGH_REG));
    }

    // Sets the TLow threshold register
    //
    // Parameters:
    //    ths        The temperature in degrees C (integer)
    function setLowThreshold(ths) {
        _setReg(T_LOW_REG, _tempToRaw(ths));
    }

    // Returns the TLow threshold in ºC
    function getLowThreshold() {
        return _rawToTemp(_getReg(T_LOW_REG));
    }

    // Sets the shutdown mode for the tmp1x2 sensor
    //
    // Parameters:
    //    state      The shutdown state (1 or 0). When shutdown is
    //               set to 0, the tmp1x2 enters a low power sleep mode.
    //               When shutdown is set to 1, the tmp1x2 wakes up
    function setShutdown(state) {
        _setRegBit(CONF_REG, 8, state);
    }

    // Returns the current shutdown mode state (0 or 1)
    function getShutdown() {
        return _getRegBit(CONF_REG, 8);
    }

    // Enables comparator mode. In comparator mode, the Alert pin is
    // activated when the temperature equals or exceeds the value in the
    // THigh register and it remains active until the temperature falls
    // below the value in the TLow register.
    function setModeComparator() {
        _setRegBit(CONF_REG, 9, 0);
    }

    // Enables interrupt mode. In interrupte mode, the Alert pin is
    // activated when the temperature exceeds THigh or goes below TLow.
    // The Alert pin is cleared when the host controller reads the
    // temperature register.
    function setModeInterrupt() {
        _setRegBit(CONF_REG, 9, 1);
    }

    // Sets the interrupt pin to be active low
    function setActiveLow() {
        _setRegBit(CONF_REG, 10, 0);
    }

    // Sets the interrupt pin to be active high
    function setActiveHigh() {
        _setRegBit(CONF_REG, 10, 1);
    }

    // Sets the extended mode state (0 or 1)
    //
    // Parameters:
    //    state      The desired extended mode state (1 or 0).
    //               When extended mode is enabled, the tmp1x2
    //               can read temperatures above 128 degrees C
    function setExtMode(state) {
        _setRegBit(CONF_REG, 4, state);
    }

    // Returns the current extended mode state (1 or 0)
    function getExtMode() {
        return _getRegBit(CONF_REG, 4);
    }

    //-------------------- PRIVATE METHODS --------------------/

    function _twosComp(value, mask) {
        value = ~(value & mask) + 1;
        return value & mask;
    }

    function _getReg(reg) {
        local val = _i2c.read(_addr, format("%c", reg), 2);
        if (val != null) {
            return (val[0] << 8) | (val[1]);
        }
        return null;
    }

    function _setReg(reg, val) {
        _i2c.write(_addr, format("%c%c%c", reg, (val & 0xff00) >> 8, val & 0xff));
    }

    function _setRegBit(reg, bit, state) {
        local val = _getReg(reg);

        if (state == 0) { val = val & ~(0x01 << bit); }
        else { val = val | (0x01 << bit); }

        _setReg(reg, val);
    }

    function _getRegBit(reg, bit) {
        local result = (0x0001 << bit) & _getReg(reg);
        return result ? 1 : 0;
    }

    function _tempToRaw(temp) {
        local raw = ((temp * 1.0) / DEG_PER_COUNT).tointeger();
        if (getExtMode()) {
            if (raw < 0) { _twosComp(raw, 0x1FFF); }

            raw = (raw & 0x1FFF) << 3;
        } else {
            if (raw < 0) { _twosComp(raw, 0x0FFF); }

            raw = (raw & 0x0FFF) << 4;
        }
        return raw;
    }

    function _rawToTemp(raw) {
        if (getExtMode()) {
            raw = (raw >> 3) & 0x1FFF;
            if (raw & 0x1000) { raw = -1.0 * _twosComp(raw, 0x1FFF); }
        } else {
            raw = (raw >> 4) & 0x0FFF;
            if (raw & 0x0800) { raw = -1.0 * _twosComp(raw, 0x0FFF); }
        }
        return raw.tofloat() * DEG_PER_COUNT;
    }

    function _getConvReady() {
        if (_getRegBit(CONF_REG, 0)) {
            return false;
        }
        return true;
    }

    function _startConversion() {
        _setRegBit(CONF_REG, 15, 1);
    }

    function _pollForConversion(cb) {
        _conversion_ready_cb = cb;

        if (_getConvReady()) {
            // success: cancel the timeout timer
            if (_conversion_timeout_timer) { imp.cancelwakeup(_conversion_timeout_timer); }

            // We want to clear the callback before we invoke it
            // so we pull it into a local variable, null out the class property
            // and then invoke the local copy of it.
            local conversion_ready_cb = _conversion_ready_cb;
            _conversion_ready_cb = null;
            conversion_ready_cb();
        } else {
            // no result: schedule again
            _conversion_poll_timer = imp.wakeup(CONVERSION_POLL_INTERVAL, _pollForConversion);
        }
    }
}

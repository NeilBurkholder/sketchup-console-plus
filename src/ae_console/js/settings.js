define(['jquery', './bridge'], function ($, Bridge) {
    /**
     * @name Property
     * @typedef Property
     * @class
     */
    function Property (_name, _value) {
        var property = this,
            name = _name,
            value = _value;

        this.addListener = function (eventName, fn) {
            $(property).on(eventName, function (event, args) {
                fn.apply(undefined, args);
            });
            return property;
        };

        /**
         * Adds an event listener and ensures the action is initially executed with the current property value.
         */
        this.bindAction = function (eventName, fn) {
            fn.apply(undefined, [value]);
            $(property).on(eventName, function (event, args) {
                fn.apply(undefined, args);
            });
            return property;
        };

        function trigger (eventName, data) {
            var args = Array.prototype.slice.call(arguments).slice(1);
            $(property).trigger(eventName, [args]);
        }

        this.getName = function () {
            return name;
        };

        this.setValue = function (newValue) {
            value = newValue;
            trigger('change', newValue);
        };

        this.getValue = function (defaultValue) {
            return (typeof value !== 'undefined') ? value : defaultValue;
        };
    }

    /**
     * @name Settings
     * @typedef Settings
     * @class
     */
    function Settings () {
        var settings = this,
            properties = {};

        this.addListener = function (eventName, fn) {
            $(settings).on(eventName, function (event, args) {
                fn.apply(undefined, args);
            });
            return settings;
        };

        function trigger (eventName, data) {
            var args = Array.prototype.slice.call(arguments).slice(1);
            $(settings).trigger(eventName, [args]);
            return settings;
        }

        /**
         * Retrieves a value of a property by its name.
         * If the property does not exist, the property is created with the given value.
         * @param   {string}  name       The name of the property
         * @param   {object}  value      The new value to set
         * @returns {object}  The value
         */
        this.set = function (name, value) {
            if (properties[name]) {
                properties[name].setValue(value);
            } else {
                addProperty(name, value);
            }
            return value;
        };

        /**
         * Retrieves a value of a property by its name.
         * If the property does not exist, an empty property is created.
         * @param   {string}  name          The name of the property
         * @param   {object=} defaultValue  An optional default value to return if the property does not exist.
         * @returns {object}  The value
         */
        this.get = function (name, defaultValue) {
            if (properties[name]) {
                return properties[name].getValue();
            } else {
                return defaultValue;
            }
        };

        /**
         * Retrieves a property by its name.
         * If the property does not exist, an empty property is created.
         * @param   {string} name  The name of the property to retrieve
         * @param   {object=} defaultValue  An optional default value to return if the property does not exist.
         * @returns {Property}
         */
        this.getProperty = function (name, defaultValue) {
            return properties[name] || addProperty(name, defaultValue);
        };

        /**
         * Check whether a property exists.
         * @param   {string}  name          The name of the property
         * @returns {boolean}  True if the property exists, false otherwise.
         */
        this.has = function (name) {
            return properties.hasOwnProperty(name);
        };

        /**
         * Sets many properties at once.
         * @param   {object}  _settings  An object literal containing strings as keys.
         */
        this.load = function (_settings) {
            $.each(_settings, function(name, value) {
                if (properties.hasOwnProperty(name)) {
                    var property = properties[name];
                    if (value !== property.getValue()) property.setValue(value);
                } else {
                    addProperty(name, value);
                }
            });
            return settings;
        };

        function addProperty (name, value) {
            var property = new Property(name, value);
            property.addListener('change', function (newValue) {
                trigger('change', name, newValue);
                Bridge.call('update_property', name, newValue);
            });
            properties[name] = property;
            return property;
        }
    }

    Settings.Property = Property;

    return Settings;
});

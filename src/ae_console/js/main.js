// Main function
requirejs(['./app', './bridge', './console_api', 'jquery'], function (app, Bridge, API, $) {
    // 1. Load the app and UI (done)
    
    // 2. Publish 'Bridge' interface that the Ruby side will need to return from callbacks.
    // window.Bridge = Bridge; // This is now done with requirejs('bridge')

    // 3. Publish 'Console' API interface on which the consoles on the Ruby side will call functions.
    window.Console = API;

    // 4. Fallback for svg-resources to png images.
    if (navigator.userAgent.match(/MSIE|Trident/i)) {
        // Internet Explorer (even if it can render svg, it does not scale them properly).
        $('img').each(function (index, img) {
            img.src = img.src.replace(/\.svg$/, '.png');
        });
    } else {
        // Fallback on load failure.
        $('img').on('error', function () {
            var img = $(this),
                src = img.attr('src');
            img.attr('src', src.replace(/\.svg$/, '.png'));
        });
    }

    // 5. Catch uncaught errors in the WebDialog and send them to the console.
    // There are some errors by the ACE editor (when double-clicking or selection
    // that goes outside the editor) that would be silent in a normal Internet Explorer
    // but cause popups in SketchUp.
    window.onerror = function(messageOrEvent, source, lineNumber, columnNumber, errorObject) {
        window.console.log([messageOrEvent, source, lineNumber, columnNumber, errorObject]);
        if (!errorObject) {
            errorObject = new Error();
            errorObject.name = 'Error';
            errorObject.message = messageOrEvent;
            errorObject.fileName = source;
            errorObject.lineNumber = lineNumber;
            errorObject.columnNumber = columnNumber;
        }
        API.javaScriptError(errorObject);
        return true;
    };
});

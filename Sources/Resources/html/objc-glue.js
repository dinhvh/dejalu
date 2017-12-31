var callbacks = {};

var postResult = function(uuid, result) {
    var callback = callbacks[uuid];
    delete callbacks[uuid];
    callback(result);
};

var runCommand = function(commandInfo, callback) {
    var uuid = UUID.generate();
    commandInfo.uuid = uuid;
    callbacks[uuid] = function(jsonResult) {
        var result = null;
        if (jsonResult != null) {
            result = JSON.parse(jsonResult);
        }
        if (callback != null) {
            callback(result);
        }
    };

    if (Controller == null) {
        console.log('try to run command when JS is done');
        console.log(JSON.stringify(commandInfo));
    }

    Controller.jsRunCommand_(JSON.stringify(commandInfo));
};

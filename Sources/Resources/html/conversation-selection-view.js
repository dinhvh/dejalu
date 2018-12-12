// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

var labelsButtonPosition = function() {
    var button = document.querySelector('#label');
    return JSON.stringify(getAbsoluteRect(button));
};

var setSelectionConversationCount = function(count) {
    document.querySelector('#count').innerText = count;
    if (count == 0) {
        document.querySelector('#has-conversations').classList.add('hidden');
        document.querySelector('#no-conversation').classList.remove('hidden');
    }
    else {
        document.querySelector('#has-conversations').classList.remove('hidden');
        document.querySelector('#no-conversation').classList.add('hidden');
    }
    document.querySelector('#main').classList.remove('hidden');
};

var setDarkMode = function(enabled) {
    if (enabled) {
        document.body.classList.add('dark-mode');
    } else {
        document.body.classList.remove('dark-mode');
    }
};

document.addEventListener("DOMContentLoaded", function(event) {
    setup();
});

var setup = function() {
    var elementList = document.querySelectorAll('.action');
    var array = Array.prototype.slice.call(elementList);;
    for (var i = 0 ; i < array.length ; i ++) {
        (function() {
            var item = array[i];
            item.addEventListener('click', function() {
                runAction(item.id);
            });
        })();
    }
    document.addEventListener('keydown', function(e) {
        if (e.keyCode == 8 && !e.ctrlKey && !e.altKey) {
            if (e.metaKey) {
                runAction('trash');
            }
            else {
                runAction('archive');
            }
            cancelEvent(e);
        }
        if (e.keyCode == 37 && !e.ctrlKey && !e.altKey && !e.metaKey) {
            focusConversationList();
            cancelEvent(e);
        }
    });
    applyPendingCount();
};

////////////

var runAction = function(name, callback) {
    var commandInfo = {'command': 'jsRunAction', 'name': name};
    runCommand(commandInfo, callback);
};

var focusConversationList = function(callback) {
    var commandInfo = {'command': 'jsFocusConversationList'};
    runCommand(commandInfo, callback);
};

var applyPendingCount = function(callback) {
    var commandInfo = {'command': 'jsApplyPendingCount'};
    runCommand(commandInfo, callback);
};

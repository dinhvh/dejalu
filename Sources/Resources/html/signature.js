// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

var objcFocus = function() {
    var el = document.querySelector('#editor');
    el.contentEditable = true;

    var range = document.createRange();
    range.selectNodeContents(el);
    range.collapse(true);
    window.getSelection().removeAllRanges();
    window.getSelection().addRange(range);
};

var objcClearContent = function() {
    var el = document.querySelector('#editor');
    el.innerHTML = '';
};

var objcSetContent = function(data) {
    var el = document.querySelector('#editor');
    el.innerHTML = data;
};

var objcContent = function() {
    var result = {};
    var el = document.querySelector('#editor');
    result.html = el.innerHTML;
    var nodes = el.querySelectorAll('img');
    nodes = [].slice.call(nodes);
    var urls = [];
    nodes.forEach(function(img) {
        if (img.src.indexOf('webkit-fake-url:') == 0) {
            urls.push(img.src);
        }
    });
    result.urls = urls;
    return JSON.stringify(result);
};

var objcDisable = function() {
    var el = document.querySelector('#editor');
    el.contentEditable = false;
};

document.addEventListener("DOMContentLoaded", function(event) {
                          objcFocus();
                          });

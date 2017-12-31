var getCurrentRange = function()
{
    var selection = window.getSelection();
    if (selection.rangeCount == 0)
        return null;

    range = selection.getRangeAt(selection.rangeCount - 1);
    if (range == null) {
        return null;
    }

    return range;
}

var objcAddLinkToSelection = function(url)
{
    //window.WindowController.jsPrepareUndoForAddLink();
    var range = getCurrentRange();

    if (range.collapsed) {
        var newNode = document.createTextNode(url);
        range.insertNode(newNode);
        range.selectNodeContents(newNode);
    }

    var newNode = document.createElement('a');
    newNode.setAttribute('href', url);
    var child = range.extractContents();
    if (child) {
        newNode.appendChild(child);
        range.insertNode(newNode);
    }
    range.selectNodeContents(newNode);
    window.getSelection().removeAllRanges();
    window.getSelection().addRange(range);

    //window.WindowController.jsPrepareUndoDone();
}

var objcLinkFromSelection = function()
{
    var element = getParentAnchorElement();
    if (element != null) {
        return element.href;
    }

    var range = getCurrentRange();
    return range.toString();
}

var objcSelectCurrentLink = function() {
    var element = getParentAnchorElement();
    if (element == null) {
        return;
    }
    var range = document.createRange();
    range.selectNodeContents(element);
    window.getSelection().removeAllRanges();
    window.getSelection().addRange(range);
};

var getParentAnchorElement = function() {
    var range = getCurrentRange();
    var element = range.commonAncestorContainer;
    while (element != null) {
        if ((element.nodeType == Node.ELEMENT_NODE) && (element.tagName == 'A')) {
            return element;
        }
        element = element.parentElement;
    }
    return null;
};

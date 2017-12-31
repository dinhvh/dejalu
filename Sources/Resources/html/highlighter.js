var highlightWord = function(node, searchString) {
    console.log('searchsrtring: ' + searchString);
    var result = [];
    highlightWordInternal(result, node, searchString);
    return result;
}

var highlightWordInternal = function(result, node, searchString) {
    searchString = searchString.toLowerCase();
    var child = node.firstChild;
    while (child != null) {
        var next;

        next = child.nextSibling;

        if (child.nodeType == Node.TEXT_NODE) {
            var replaced = highlightWordInSpanNode(child, searchString);
            if (replaced != null) {
                result.push(replaced);
            }
        }
        else if (child.nodeType == Node.ELEMENT_NODE) {
            var tagName;

            tagName = child.tagName
            if (tagName == 'SCRIPT') {
                // do nothing
            }
            else if (tagName == 'STYLE') {
                // do nothing
            }
            else if (child.nodeType == Node.ELEMENT_NODE) {
                highlightWordInternal(result, child, searchString);
            }
        }

        child = next;
    }
};

var highlightWordInSpanNode = function(node, searchString) {
    var searchStringLength = searchString.length;
    var str = node.nodeValue;
    if (str == null) {
        return null;
    }
    var lcStr = str.toLowerCase();
    var container = document.createElement('span');
    container.classList.add('-dejalu-highlighted-container');
    container.originalString = str;
    var hasMatch = false;
    while (true) {
        var idx = lcStr.indexOf(searchString);
        if (idx == -1) {
            break;
        }
        if (idx != 0) {
            var leftNode = document.createTextNode(str.substring(0, idx));
            container.appendChild(leftNode);
        }
        var matchNode = document.createElement('span');
        matchNode.innerText = str.substring(idx, idx + searchStringLength);
        matchNode.classList.add('-dejalu-highlighted');
        container.appendChild(matchNode);

        str = str.substring(idx + searchStringLength);
        lcStr = lcStr.substring(idx + searchStringLength);
        hasMatch = true;
    }
    if (hasMatch) {
        if (str.length > 0) {
            var rightNode = document.createTextNode(str);
            container.appendChild(rightNode);
        }
        node.parentNode.replaceChild(container, node);
        return container;
    }
    return null;
};

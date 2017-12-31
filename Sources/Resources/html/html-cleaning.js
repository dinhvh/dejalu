var cancelEvent = function(e) {
    e.preventDefault();
    e.stopPropagation();
};

function getAbsoluteRect(oElement)
{
    var xReturnValue = 0;
    var yReturnValue = 0;
    var width = oElement.clientWidth;
    var height = oElement.clientHeight;
    while (oElement != null) {
        xReturnValue += oElement.offsetLeft;
        yReturnValue += oElement.offsetTop;
        oElement = oElement.offsetParent;
        if (oElement != null) {
            xReturnValue -= oElement.scrollLeft;
            yReturnValue -= oElement.scrollTop;
        }
    }
    return {'x': xReturnValue, 'y': yReturnValue, 'width': width, 'height': height};
}

function getAbsoluteRectWithId(id)
{
    var element = document.getElementById(id);
    if (element == null)
        return null;
    return getAbsoluteRect(element);
}

/**
* Determine whether a node's text content is entirely whitespace.
*
* @param nod  A node implementing the |CharacterData| interface (i.e.,
*             a |Text|, |Comment|, or |CDATASection| node
* @return     True if all of the text content of |nod| is whitespace,
*             otherwise false.
*/
function is_all_ws( nod )
{
    // Use ECMA-262 Edition 3 String and RegExp features
    return !(/[^\t\n\r ]/.test(nod.data));
}

/**
* Determine if a node should be ignored by the iterator functions.
*
* @param nod  An object implementing the DOM1 |Node| interface.
* @return     true if the node is:
*                1) A |Text| node that is all whitespace
*                2) A |Comment| node
*             and otherwise false.
*/

function is_ignorable( nod )
{
    return (nod.nodeType == Node.COMMENT_NODE) || // A comment node
    ( (nod.nodeType == Node.TEXT_NODE) && is_all_ws(nod) ); // a text node, all ws
}

/**
* Version of |firstChild| that skips nodes that are entirely
* whitespace and comments.
*
* @param sib  The reference node.
* @return     Either:
*               1) The first child of |sib| that is not
*                  ignorable according to |is_ignorable|, or
*               2) null if no such node exists.
*/
function first_child( par )
{
    var res=par.firstChild;
    while (res) {
        if (!is_ignorable(res)) return res;
        res = res.nextSibling;
    }
    return null;
}

function last_child(par)
{
    var res=par.lastChild;
    while (res) {
        if (!is_ignorable(res)) return res;
        res = res.previousSibling;
    }
    return null;
}

function next_sibling(par)
{
    var res = par.nextSibling;
    while (res) {
        if (!is_ignorable(res)) return res;
        res = res.nextSibling;
    }
    return null;
}

function previous_sibling(par)
{
    var res = par.previousSibling;
    while (res) {
        if (!is_ignorable(res)) return res;
        res = res.previousSibling;
    }
    return null;
}

function number_of_children(el)
{
    var count;
    count = 0;
    for(i = 0 ; i < el.childNodes.length ; i ++) {
        var node;
        
        node = el.childNodes.item(i);
        if (!is_ignorable(node)) {
            count ++;
        }
    }
    
    return count;
}

function getAbsoluteURL(baseurl, url)
{
    var uri = new URI(url);
    var baseuri = new URI(baseurl);
    if (uri == null) {
        return baseurl;
    }
    var resolved = uri.resolve(baseuri);
    
    return resolved.toString();
}

function getDocumentHTML()
{
    return document.documentElement.outerHTML;
}

function getNodeHTML(HTMLstring)
{
    var d = document.createElement('div');
    d.innerHTML = HTMLstring;
    return d;
}

function getSpanNodeHTML(HTMLstring)
{
    var d = document.createElement('span');
    d.innerHTML = HTMLstring;
    return d;
}

function fixHTMLFormatting(html, baseURL, urlDictionary, hideQuoted)
{
    var node;
    
    node = getNodeHTML(html);
    fixedNodeHTMLFormatting(node, baseURL, urlDictionary, hideQuoted, false);
    
    return node.innerHTML;
}

function measureCall(name, call)
{
//    var blacklist = ['removeComments', 'requoteCloudMagic', 'collapseAccompliQuotes', 'replaceBrWithDiv',
//                     'replaceURLUsingBaseURL', 'removeJavascript', 'removeIFrame', 'collapseRequoteOutlook',
//                     'collapseOutlookQuotes', 'collapseOutlookForwarded', 'collapseOriginalMessage',
//                     'collapseMessageFromHeader', 'collapseYahooQuotes', 'filterMicrosoftFormatting',
//                     'removeLegalText', 'removeStyle', 'collapseSignature', 'removeUnusefulBlanks',
//                     'replaceGtWithBlockquote', 'mergeBlockquotes', 'removeEltHundredPercent',
//                     'removeAbsolutePosition', 'filterContentEditable', 'filterId'];
//    blacklist = blacklist.slice(0, 12);
//    if (blacklist.includes(name)) {
//        return;
//    }
    var curTime = (new Date()).getTime();
    call();
    curTime = (new Date()).getTime() - curTime;
    //console.log('duration ' + name + ': ' + curTime);
}

function fixedNodeHTMLFormatting(node, baseURL, urlDictionary, hideSignature, applyAllFilters)
{
    measureCall('removeComments', function() {
        removeComments(node);
    });
    if (applyAllFilters) {
        measureCall('requoteCloudMagic', function() {
            requoteCloudMagic(node);
        });
        measureCall('collapseAccompliQuotes', function() {
            collapseAccompliQuotes(node);
        });
    }
    measureCall('replaceBrWithDiv', function() {
        replaceBrWithDiv(node);
    });
    if (baseURL != null) {
        measureCall('replaceURLUsingBaseURL', function() {
            replaceURLUsingBaseURL(node, baseURL);
        });
    }
    measureCall('removeJavascript', function() {
        removeJavascript(node);
    });
    measureCall('removeIFrame', function() {
        removeIFrame(node);
    });
    if (applyAllFilters) {
        measureCall('collapseRequoteOutlook', function() {
            collapseRequoteOutlook(node, node);
        });
        measureCall('collapseOutlookQuotes', function() {
            collapseOutlookQuotes(node);
        });
        measureCall('collapseOutlookForwarded', function() {
            collapseOutlookForwarded(node);
        });
        measureCall('collapseOriginalMessage', function() {
            collapseOriginalMessage(node);
        });
        measureCall('collapseMessageFromHeader', function() {
            collapseMessageFromHeader(node);
        });
        measureCall('collapseYahooQuotes', function() {
            collapseYahooQuotes(node);
        });
        measureCall('filterMicrosoftFormatting', function() {
            filterMicrosoftFormatting(node);
        });
        measureCall('removeLegalText', function() {
            removeLegalText(node);
        });
        measureCall('removeStyle', function() {
            removeStyle(node);
        });
    }
    if (hideSignature) {
        measureCall('collapseSignature', function() {
            collapseSignature(node, false);
        });
    }
    measureCall('removeUnusefulBlanks', function() {
        removeUnusefulBlanks(node);
    });
    while (true) {
        var result = false;
        measureCall('replaceGtWithBlockquote', function() {
            result = replaceGtWithBlockquote(node);
        });
        if (!result) {
            break;
        }
        // do nothing
    }
    measureCall('mergeBlockquotes', function() {
        mergeBlockquotes(node);
    });
    measureCall('removeEltHundredPercent', function() {
        removeEltHundredPercent(node);
    });
    if (applyAllFilters) {
        measureCall('removeAbsolutePosition', function() {
            removeAbsolutePosition(node);
        });
        measureCall('filterContentEditable', function() {
            filterContentEditable(node);
        });
        measureCall('filterId', function() {
            filterId(node);
        });
    }

    return node;
}

var blockRegex = /^(address|blockquote|body|center|dir|div|dl|fieldset|form|h[1-6]|hr|isindex|menu|noframes|noscript|ol|p|pre|table|ul|dd|dt|frameset|li|tbody|td|tfoot|th|thead|tr|html)$/i;

function isBlockLevel(el) {
    return blockRegex.test(el.nodeName);
}

function replaceGtWithBlockquote(node)
{
    var replaced = false;
    var divList = node.querySelectorAll('div');
    for(var i = 0 ; i < divList.length ; i ++) {
        var divNode = divList[i];
        var textNode = divNode.firstChild
        if (textNode == null) {
            continue;
        }
        while ((textNode != null) && (textNode.nodeType == Node.ELEMENT_NODE) && (!isBlockLevel(textNode))) {
            textNode = textNode.firstChild;
        }
        if (textNode == null) {
            continue;
        }
        if (textNode.nodeType == Node.TEXT_NODE) {
            var originalStr = textNode.textContent;
            var str = textNode.textContent;
            var j = 0;
            while (true) {
                if (j >= str.length) {
                    break;
                }
                if ((str.charAt(j) == ' ') || (str.charAt(j) == '\n')) {
                    j ++;
                    continue;
                }
                break;
            }
            if (j >= str.length) {
                continue;
            }
            if (str.charAt(j) != '>') {
                continue;
            }
            str = str.substring(j + 1);
            textNode.textContent = str;
            //console.log('|' + originalStr + '|');
            //console.log('|' + str + '|');
            
            var blockquote = document.createElement('blockquote');
            blockquote.setAttribute('type', 'cite');
            var child = divNode.firstChild;
            while (child != null) {
                if (isBlockLevel(child)) {
                    break;
                }
                var next = child.nextSibling;
                divNode.removeChild(child);
                blockquote.appendChild(child);
                child = next;
            }

            divNode.parentNode.insertBefore(blockquote, divNode);
            if (divNode.childNodes.length == 0) {
                divNode.parentNode.removeChild(divNode);
            }
            replaced = true;
        }
    }
    return replaced;
}

function collapseMessage(node)
{
    collapseQuoted(node, null);
    
    var lastBlockquote = null;
    var blockquotesList = node.querySelectorAll('blockquote[type=cite]');
    for(var i = 0 ; i < blockquotesList.length ; i ++) {
        if (isAncestorBlockquote(blockquotesList[i].parentNode)) {
            continue;
        }
        
        lastBlockquote = blockquotesList[i];
    }

    if (lastBlockquote != null) {
        if (!hasTextAfterElement(node, lastBlockquote)) {
            lastBlockquote.parentNode.removeChild(lastBlockquote);
        }
    }
}

function hasTextAfterElement(mainNode, node)
{
    while (1) {
        var next = node.nextSibling;
        if (next == null) {
            if (node.parentNode != mainNode) {
                next = node.parentNode.nextSibling;
            }
        }
        if (next == null) {
            break;
        }
        if (isSendersInfo(next)) {
            node = next;
            continue;
        }
        if ((next.nodeType == Node.ELEMENT_NODE) && (next.querySelector('img') == null)) {
            node = next;
            continue;
        }
        var text = next.textContent;
        if (text != null) {
            text = text.replace(/[\r\n\t\ ]/g, '');
            if (text.length > 0) {
                return true;
            }
        }

        node = next;
    }
    return false;
}

function isSendersInfo(node)
{
    if (node.classList != null) {
        if (node.classList.contains('no-resend')) {
            return true;
        }
    }
    var first = first_child(node)
    if (first == null) {
        return false;
    }
    if (next_sibling(first) != null) {
        return false;
    }
    return isSendersInfo(first);
}

function replaceURLUsingBaseURL(node, baseURL)
{
    if (baseURL == null)
        return;

    var list = [].slice.call(document.querySelectorAll('img'));
    list.forEach(function(node) {
        var url;
        
        url = node.getAttribute('src');
        if (url != null) {
            url = getAbsoluteURL(baseURL, url);
            node.setAttribute('src', url);
        }
    });
    list = [].slice.call(document.querySelectorAll('a'));
    list.forEach(function(node) {
        var url;
        
        url = node.getAttribute('href');
        if (url != null) {
            url = getAbsoluteURL(baseURL, url);
            node.setAttribute('href', url);
        }
    });
    /*
    var child = node.firstChild;
    while (child != null) {
        var next;
        
        next = child.nextSibling;
        
        if (child.nodeType == Node.ELEMENT_NODE) {
            var tagName;
            
            tagName = child.tagName
            if (tagName == 'IMG') {
                var url;
                
                url = child.getAttribute('src');
                if (url != null) {
                    url = getAbsoluteURL(baseURL, url);
                    child.setAttribute('src', url);
                }
            }
            else if (tagName == 'A') {
                var url;
                
                url = child.getAttribute('href');
                if (url != null) {
                    url = getAbsoluteURL(baseURL, url);
                    child.setAttribute('href', url);
                }
            }
        }
        
        replaceURLUsingBaseURL(child, baseURL);
        
        child = next;
    }
     */
}

var jsAttrToRemove = ['onabort', 'onblur', 'onchange', 'onclick',
'ondblclick', 'ondragdrop', 'onerror', 'onfocus',
'onkeydown', 'onkeypress', 'onload', 'onmouseover',
'onmouseout', 'onreset', 'onresize', 'onsubmit',
'onunload',
'onafterprint', 'onbeforeprint', 'onbeforeonload',
'onhaschange', 'onmessage', 'onoffline', 'ononline',
'onpagehide', 'onpageshow', 'onpopstate', 'onredo',
'onstorage', 'onundo',
'oncontextmenu', 'onformchange', 'onforminput', 'oninput',
'oninvalid', 'onselect', 'onkeyup',
'ondrag', 'ondragend', 'ondragenter', 'ondragleave', 'ondragover',
'ondragstart', 'ondrop', 'onmousedown', 'onmousemove', 'onmouseup',
'onmousewheel', 'onscroll',
'onabort', 'oncanplay', 'oncanplaythrough', 'ondurationchange',
'onemptied', 'onended', 'onloadeddata', 'onloadedmetadata',
'onloadstart', 'onpause', 'onplay', 'onplaying',
'onprogress', 'onratechange', 'onreadystatechange', 'onseeked',
'onseeking', 'onstalled', 'onsuspend', 'ontimeupdate',
'onvolumechange', 'onwaiting'
];

function removeJavascript(node)
{
    var child = node.firstChild;
    while (child != null) {
        var next;
        
        next = child.nextSibling;
        
        if (child.nodeType == Node.ELEMENT_NODE) {
            var tagName;
            
            tagName = child.tagName
            if (tagName == 'SCRIPT') {
                node.removeChild(child);
            }
            else if (child.nodeType == Node.ELEMENT_NODE) {
                if (tagName == 'a') {
                    var href;
                    
                    href = child.getAttribute('href');
                    if (href != null) {
                        href = href.toLowerCase();
                        if (href.indexOf('javascript:') == 0) {
                            child.removeAttribute('href');
                        }
                    }
                }
                for(var i in jsAttrToRemove) {
                    child.removeAttribute(jsAttrToRemove[i]);
                }
                removeJavascript(child);
            }
        }
        
        child = next;
    }
}

function removeIFrame(node)
{
    var list = [].slice.call(document.querySelectorAll('iframe'));
    list.forEach(function(node) {
        node.parentNode.removeChild(node);
    });
}

function filterMicrosoftFormatting(node)
{
    var child = node.firstChild;
    while (child != null) {
        var next;
        
        next = child.nextSibling;
        
        if (child.nodeType == Node.ELEMENT_NODE) {
            
            if (child.className == 'MsgListParagraph') {
                child.removeAttribute('class');
                child.style.removeProperty('text-indent');
                child.style.setProperty('margin', '0px');
            }
            else if (child.className == 'MsgListParagraph') {
                child.removeAttribute('class');
                child.style.removeProperty('text-indent');
            }
            else if (child.className == 'WordSection1') {
                child.removeAttribute('class');
                child.style.removeProperty('text-indent');
            }
            else if (child.className == 'MsoHyperlink') {
                child.removeAttribute('class');
            }
            else if (child.className == 'MsoHyperlinkFollowed') {
                child.removeAttribute('class');
            }
            else if (child.className == 'MsoNormal') {
                child.removeAttribute('class');
                child.style.removeProperty('text-indent');
                child.style.setProperty('margin', '0px');
            }
            else if (child.className == 'MsoPlainText') {
                child.removeAttribute('class');
            }
            else if (child.className == 'MsoListParagraphCxSpFirst') {
                child.removeAttribute('class');
                child.style.removeProperty('text-indent');
                child.style.setProperty('margin', '0px');
            }
            else if (child.className == 'MsoListParagraphCxSpMiddle') {
                child.removeAttribute('class');
                child.style.removeProperty('text-indent');
                child.style.setProperty('margin', '0px');
            }
            else if (child.className == 'MsoListParagraphCxSpLast') {
                child.removeAttribute('class');
                child.style.removeProperty('text-indent');
                child.style.setProperty('margin', '0px');
            }
            
            filterMicrosoftFormatting(child);
        }
        
        child = next;
    }
}

function hasMetaGenerator(node)
{
    var nodeList = node.querySelectorAll('meta');
    for (var i = 0 ; i < nodeList.length ; i ++) {
        var item = nodeList[i];
        var name = item.getAttribute('name');
        var content = item.getAttribute('content');
        if ((name == null) | (content == null)) {
            continue;
        }
        name = name.toLowerCase();
        content = content.toLowerCase();
        if ((name == 'generator') && (content.indexOf('microsoft') != -1)) {
            return true;
        }
    }
    return false;
}

function getOutlookQuotedText(node)
{
    var nodeList = node.querySelectorAll('div');
    for (var i = 0 ; i < nodeList.length ; i ++) {
        var item = nodeList[i];
        if (item.style.borderTop != '') {
            return item;
        }
    }
    return null;
}

function hasBlockquoteParent(node)
{
    while (node != null) {
        if (node.tagName == 'BLOCKQUOTE') {
            return true;
        }
        node = node.parentNode;
    }
    return false;
}

function collapseAccompliQuotes(node)
{
    var firstNodeToQuote = node.querySelector('.acompli_signature');
    if (firstNodeToQuote == null) {
        return;
    }
    if (hasBlockquoteParent(firstNodeToQuote)) {
        return;
    }

    outlookQuoteFromNode(node, firstNodeToQuote);
}

function collapseOutlookQuotes(node)
{
    if (!hasMetaGenerator(node)) {
        return;
    }
  
    var firstNodeToQuote = getOutlookQuotedText(node);
    if (firstNodeToQuote == null) {
        return;
    }

    outlookQuoteFromNode(node, firstNodeToQuote);
}

function outlookQuoteFromNode(mainNode, firstNodeToQuote)
{
    var blockquote = document.createElement('blockquote');
    blockquote.setAttribute('type', 'cite');
    var parentNode = firstNodeToQuote.parentNode;
    parentNode.insertBefore(blockquote, firstNodeToQuote);
    
    var currentChild = firstNodeToQuote;
    while (currentChild != null) {
        var nextChild = currentChild.nextSibling;
        var parentOfChild = currentChild.parentNode;
        blockquote.appendChild(currentChild);
        while (nextChild == null) {
            if (parentOfChild == mainNode) {
                break;
            }
            currentChild = parentOfChild;
            if (currentChild == null) {
                break;
            }
            nextChild = currentChild.nextSibling;
            if (nextChild == null) {
                parentOfChild = currentChild.parentNode;
            }
        }
        currentChild = nextChild;
    }
}

function collapseYahooQuotes(node)
{
    var currentChild = node.firstChild;
    while (currentChild != null) {
        var nextChild = currentChild.nextSibling;
        if ((currentChild.nodeType == Node.ELEMENT_NODE) && (currentChild.classList.contains('y_msg_container') || currentChild.classList.contains('yahoo_quoted'))) {
            var blockquote = document.createElement('blockquote');
            blockquote.setAttribute('type', 'cite');
            blockquote.appendChild(currentChild.cloneNode(true));
            node.replaceChild(blockquote, currentChild);
        }
        else if ((currentChild.nodeType == Node.ELEMENT_NODE) && (currentChild.id == '_origMsg_')) {
            var blockquote = document.createElement('blockquote');
            blockquote.setAttribute('type', 'cite');
            blockquote.appendChild(currentChild.cloneNode(true));
            node.replaceChild(blockquote, currentChild);
        }
        else {
            collapseYahooQuotes(currentChild);
        }
        currentChild = nextChild;
    }
}

function removeStyle(node)
{
    var child = node.firstChild;
    while (child != null) {
        var next;
        
        next = child.nextSibling;
        
        if (child.nodeType == Node.ELEMENT_NODE) {
            var tagName;
            
            //tagName = child.tagName.toLowerCase()
            if (child.tagName == 'STYLE') {
                node.removeChild(child);
            }
            else if (child.tagName == 'TITLE') {
                node.removeChild(child);
            }
            else if (child.tagName == 'META') {
                node.removeChild(child);
            }
            else if (child.tagName == 'LINK') {
                if (child.getAttribute('rel') != null) {
                    if (child.getAttribute('rel').toLowerCase == 'stylesheet') {
                        node.removeChild(child);
                    }
                }
            }
            else {
                removeStyle(child);
            }
        }
        
        child = next;
    }
}

function removeBackgroundImage(node)
{
}

function removeUnusefulBlanks(node)
{
    var count = 0;
    var child = node.firstChild;
    while (child != null) {
        var next;
        var removed;
        
        next = child.nextSibling;
        removed = false;
        
        //console.log('recurse? ' + child.outerHTML);
        if (child.nodeType == Node.ELEMENT_NODE) {
            removed = removeUnusefulBlanks(child);
        }
        
        /*
        if (!removed) {
        if (child.nodeType == Node.ELEMENT_NODE) {
        var tagName;
                
        tagName = child.tagName
        if ((tagName == 'DIV') && (number_of_children(child) == 0)) {
        node.removeChild(child);
        removed = true;
        }
        }
        }
        */
        if (!removed) {
            if (next != null) {
                if (next.nodeType == Node.ELEMENT_NODE) {
                    var tagName;
                    
                    tagName = next.tagName
                    if (is_all_ws(child) && (tagName == 'BLOCKQUOTE')) {
                        node.removeChild(child);
                        removed = true;
                    }
                }
            }
        }
        if (!removed) {
            if (next != null) {
                if (child.nodeType == Node.ELEMENT_NODE) {
                    var tagName;
                    
                    tagName = child.tagName
                    if (is_all_ws(next) && (tagName == 'BLOCKQUOTE')) {
                        var childToRemove;
                        
                        childToRemove = next;
                        next = next.nextSibling;
                        node.removeChild(childToRemove);
                        removed = true;
                    }
                }
            }
        }
        if (!removed) {
            if (!is_ignorable(child)) {
                count ++;
            }
        }
        
        child = next;
    }

    var mainNodeRemoved = false;
    if ((count == 0) && (node.tagName == 'DIV')) {
        node.parentNode.removeChild(node);
        mainNodeRemoved = true;
    }
    if ((node.tagName == 'SPAN') && (node.childNodes.length == 0)) {
        node.parentNode.removeChild(node);
        mainNodeRemoved = true;
    }
    return mainNodeRemoved;
}

function isBlockquote(node)
{
    var tagName;

    if (node.tagName == null) {
        return false;
    }
    tagName = node.tagName;
    /*
    if (tagName == 'div') {
    if (node.classList.contains('gmail_quote')) {
    return true;
    }
    }
    */
    if (tagName != 'BLOCKQUOTE') {
        return false;
    }
    if (node.className == 'gmail_quote') {
        return true;
    }
    if (node.getAttribute('type') == 'cite') {
        return true;
    }
    
    return false;
}

function mergeBlockquotes(node)
{
    var currentBlocknode = null;
    var processed = false;
    
    var child = node.firstChild;
    
    while (child != null) {
        var next;
        
        next = child.nextSibling;
        
        if (child.nodeType == Node.ELEMENT_NODE) {

            if ((child.tagName == 'DIV') && (number_of_children(child) == 1)) {
                var subchild = first_child(child);
                if (isBlockquote(subchild)) {
                    node.replaceChild(subchild, child);
                }
                child = subchild;
            }

            var tagName;
            
            tagName = child.tagName;
            if (isBlockquote(child)) {
                if (currentBlocknode == null) {
                    var subChild;
                    var subChildTagName;

                    if (child.childNodes.length == 0) {
                        child = next;
                        continue;
                    }
                    
                    subChild = child.firstChild;
                    subChildTagName = null;
                    if (subChild.nodeType == Node.ELEMENT_NODE) {
                        subChildTagName = subChild.tagName;
                    }
                    if ((child.childNodes.length == 1) && (isBlockquote(child) || (tagName == 'DIV'))) {
                        currentBlocknode = child;
                    }
                    else {
                        var div;
                        
                        currentBlocknode = document.createElement('blockquote');
                        currentBlocknode.setAttribute('type', 'cite');
                        
                        div = document.createElement('div');
                        currentBlocknode.appendChild(div);
                        subChild = child.firstChild;
                        while (subChild != null) {
                            div.appendChild(subChild.cloneNode(true));
                            subChild = subChild.nextSibling;
                        }
                        
                        node.replaceChild(currentBlocknode, child);
                        processed = true;
                    }
                }
                else {
                    var subChild;
                    var subChildTagName;
                    
                    subChild = child.firstChild;
                    if (subChild != null) {
                        subChildTagName = null;
                        if (subChild.nodeType == Node.ELEMENT_NODE) {
                            subChildTagName = subChild.tagName;
                        }
                        if ((child.childNodes.length == 1) && (isBlockquote(child) || (tagName == 'DIV'))) {
                            currentBlocknode.appendChild(subChild.cloneNode(true));
                            node.removeChild(child);
                            processed = true;
                        }
                        else {
                            var div;

                            div = document.createElement('div');
                            currentBlocknode.appendChild(div);

                            subChild = child.firstChild;
                            while (subChild != null) {
                                div.appendChild(subChild.cloneNode(true));
                                subChild = subChild.nextSibling;
                            }

                            node.removeChild(child);
                            processed = true;
                        }
                    }
                }
            }
            else {
                if (currentBlocknode != null) {
                    if (mergeBlockquotes(currentBlocknode)) {
                        processed = true;
                    }
                    currentBlocknode = null;
                }
                
                if (mergeBlockquotes(child)) {
                    processed = true;
                }
            }
        }
        
        child = next;
    }
    
    if (currentBlocknode != null) {
        if (mergeBlockquotes(currentBlocknode)) {
            processed = true;
        }
        currentBlocknode = null;
    }
    
    return processed;
}

function removeEltHundredPercent(node)
{
}

function removeAbsolutePosition(node)
{
}

function hideOrRenderCID(node)
{
}

function filterContentEditable(node)
{
    var child = node.firstChild;
    while (child != null) {
        var next;
        
        next = child.nextSibling;
        
        if (child.nodeType == Node.ELEMENT_NODE) {
            if (child.contentEditable) {
                child.removeAttribute('contentEditable');
            }
            filterContentEditable(child);
        }
        
        child = next;
    }
}

function filterId(node)
{
    var child = node.firstChild;
    while (child != null) {
        var next;
        
        next = child.nextSibling;
        
        if (child.nodeType == Node.ELEMENT_NODE) {
            if (child.id == 'main-body') {
                child.removeAttribute('id');
            }
            if ((child.className != null) && (child.classList != null)) {
                if ((child.className.indexOf('-dejalu-') != 0) && !child.classList.contains('btn') && !child.classList.contains('no-resend')) {
                    child.removeAttribute('class');
                }
            }
            
            filterId(child);
        }
        
        child = next;
    }
}

var showQuotedTextImage = null;

function collapseQuoted(node, path)
{
    /*
    if (showQuotedTextImage == null) {
    showQuotedTextImage = webViewCallController('jsImageResourceURL:', ['MessageShowQuotedText.png']);
    }
    */
    
    var currentBlockNodes = null;
    var currentIndex = 1;
    var child = node.firstChild;
    while (child != null) {
        var next;
        var subpath;
        var quoted;
        
        if (path == null) {
            subpath = currentIndex.toString();
        }
        else {
            subpath = path + '.' + currentIndex.toString();
        }
        
        next = child.nextSibling;
        quoted = false;
        
        if (child.nodeType == Node.ELEMENT_NODE) {
            if (isBlockquote(child)) {
                //quoted = true;
            }
            else {
                if ((child.tagName == 'P') || (child.tagName == 'DIV')) {
                    var text = child.textContent.toLowerCase();
                    text = text.replace(/\n/g, ' ');
                    text = text.replace(/^ +/, ' ');
                    text = text.trim();
                    var re;
                    re = /^on .* wrote:$/;
                    if (re.test(text)) {
                        quoted = true;
                    }
                    re = /^le[\u00a0 ].* a écrit[\u00a0 ]+:$/;
                    if (re.test(text)) {
                        quoted = true;
                    }
                    re = /^[0-9]{4}-[0-9]{2}-[0-9]{2} .* \<.*\>:$/;
                    if (re.test(text)) {
                        quoted = true;
                    }
                    re = /^[0-9]{4}年[0-9]{1,2}月[0-9]{1,2}日.*写道：$/;
                    if (re.test(text)) {
                        quoted = true;
                    }
                }
            }
        }
        if (quoted) {
            //child.style.display = 'none';
            node.removeChild(child);
            
            /*
            var div;
            // MessageShowQuotedtext@2x.png
            div = document.createElement('div');
            div.setAttribute('onclick', "toggleBlockQuoteVisibility(event, '" + subpath + "')");
            div.id = subpath + '-label';
            div.className = '-sparrow-quotedTextLabelHide';
            div.style.backgroundImage = 'url(' + showQuotedTextImage + ')';
            
            node.insertBefore(div, child);
            
            div = document.createElement('div');
            div.setAttribute('onclick', "toggleBlockQuoteVisibility(event, '" + subpath + "')");
            div.id = subpath + '-label-hide';
            div.className = '-sparrow-quotedTextLabelHide';
            div.style.display = 'none';
            div.style.backgroundImage = 'url(' + showQuotedTextImage + ')';
            
            node.insertBefore(div, child);
            
            child.style.display = 'none';
            child.id = subpath;
            */
        }
        else {
            if (child.nodeType == Node.ELEMENT_NODE) {
                var tagName;
                
                tagName = child.tagName
                if (tagName != 'A') {
                    collapseQuoted(child, subpath);
                }
            }
        }
        
        child = next;
        
        currentIndex ++;
    }
}

function createException()
{
    try {
        this.undef();
        return null;
    } catch (e) {
        return e;
    }
}

function stringifyArguments(args)
{
    var slice = Array.prototype.slice;
    for(var i = 0; i < args.length; ++i) {
        var arg = args[i];
        if (arg === undefined) {
            args[i] = 'undefined';
        } else if (arg === null) {
            args[i] = 'null';
        } else if (arg.constructor) {
            if (arg.constructor === Array) {
                if (arg.length < 3) {
                    args[i] = '[' + this.stringifyArguments(arg) + ']';
                } else {
                    args[i] = '[' + this.stringifyArguments(slice.call(arg, 0, 1)) + '...' + this.stringifyArguments(slice.call(arg, -1)) + ']';
                }
            } else if (arg.constructor === Object) {
                args[i] = '#object';
            } else if (arg.constructor === Function) {
                args[i] = '#function';
            } else if (arg.constructor === String) {
                args[i] = '"' + arg + '"';
            }
        }
    }
    return args.join(',');
}

function getCallstack(curr)
{
    var ANON = '{anonymous}';
    var fnRE = new RegExp('function\\s*([\\w\\-$]+)?\\s*\\(', 'i');
    var stack = [];
    var fn;
    var args
    var maxStackSize = 10;
    while (curr && stack.length < maxStackSize) {
        fn = fnRE.test(curr.toString()) ? RegExp.$1 || ANON : ANON;
        args = Array.prototype.slice.call(curr['arguments'] || []);
        stack[stack.length] = fn + '(' + this.stringifyArguments(args) + ')';
        curr = curr.caller;
    }
    return stack;
}
                                                                 
function printCurrentStack()
{
    var stack;
    stack = getCallstack(arguments.callee);
    var result = null;
    for(var stackIndex in stack) {
        if (result == null) {
            result = "  " + stack[stackIndex];
        }
        else {
            result = result + "\n  " + stack[stackIndex];
        }
    }
    if (result == null) {
        result = 'no stack';
    }
    console.log(result);
}

function readabilityCleaning(topDiv)
{
    /*
    if (readabilityHasTable(topDiv)) {
    return;
    }
    */
    
    readabilityRemoveHR(topDiv);
    readabilityRemoveEmptyParagraphs(topDiv);
    readabilityApplyFontStyle(topDiv);
    readabilityCleanStyles(topDiv);					// Removes all style attributes
}

function readabilityHasTable(node)
{
    return node.querySelector('table') != null;
}

// Get the inner text of a node - cross browser compatibly.
function readabilityGetInnerText(e) {
    if (navigator.appName == "Microsoft Internet Explorer")
        return e.innerText;
    else
        return e.textContent;
}

// Get character count
function getCharCount ( e,s ) {
    s = s || ",";
    return readabilityGetInnerText(e).split(s).length;
}

function readabilityApplyFontStyle(e)
{
    var cur = e.firstChild;
    while ( cur != null ) {
        var next;
        
        next = cur.nextSibling;

        if ( cur.nodeType == Node.ELEMENT_NODE ) {
            if (cur.tagName == 'TABLE') {
                cur = next;
                continue;
            }
            readabilityApplyFontStyle(cur);
            if (cur.tagName == 'FONT') {
                readabilityReplaceFontStyle(e, cur);
            }
            if ((cur.tagName == 'IMG') && (cur.src.indexOf('http:') != 0) && (cur.src.indexOf('https:') != 0)) {
                cur.classList.add('-dejalu-image');
            }
        }
        cur = next;
    }
}

function readabilityReplaceFontStyle(e, startNode)
{
    var nodeToMove = startNode.firstChild;
    
    fontColor = startNode.getAttribute('color');
    
    var spanNode;
    spanNode = document.createElement('span');
    if (fontColor != null) {
        spanNode.style.color = fontColor;
    }
    
    while (nodeToMove != null) {
        nextNode = nodeToMove.nextSibling;
        
        spanNode.appendChild(nodeToMove);
        
        nodeToMove = nextNode;
    }
    
    e.replaceChild(spanNode, startNode);
}

function requoteCloudMagic(node)
{
    var nodesList = node.querySelectorAll('div#oldcontent');
    for(var i = 0 ; i < nodesList.length ; i ++) {
        var divNode = nodesList[i];
        var blockquote = divNode.querySelector('blockquote');
        if (blockquote != null) {
            blockquote.setAttribute('type', 'cite');
        }
    }
}

function collapseRequoteOutlook(mainNode, e)
{
    var cur = e.firstChild;
    while ( cur != null ) {
        if (cur.nodeType == Node.ELEMENT_NODE) {
            var str = cur.textContent;
            str = str.replace(/\n/g, '');
            if (str == '___') {
                outlookQuoteFromNode(mainNode, cur);
                break;
            }
            
            if ((cur.tagName == 'DIV') && (cur.className == 'OutlookMessageHeader')) {
                outlookQuoteFromNode(mainNode, cur);
                break;
            }

            if ((cur.tagName == 'DIV') && (cur.id == 'divRplyFwdMsg')) {
                outlookQuoteFromNode(mainNode, cur);
                break;
            }

            collapseRequoteOutlook(mainNode, cur);
        }
        cur = cur.nextSibling;
    }
}

/*
function collapseOutlookMoveQuoted(e, startNode)
{
var nodeToMove = startNode;
    
var blockquoteNode;
blockquoteNode = document.createElement('blockquote');
blockquoteNode.setAttribute('type', 'cite');
    
while (nodeToMove != null) {
var nextNode = nodeToMove.nextSibling;
var parentOfChild = currentChild.parentNode;
while (nextNode == null) {
nodeToMove = parentOfChild;
if (nodeToMove == null) {
break;
}
nextNode = nodeToMove.nextSibling;
if (nextNode == null) {
parentOfChild = nodeToMove.parentNode;
}
}
        
blockquoteNode.appendChild(nodeToMove);
        
nodeToMove = nextNode;
}
    
e.appendChild(blockquoteNode);
}
*/

function collapseOutlookForwarded(node)
{
    var nodesList = node.querySelectorAll('div');
    for(var i = 0 ; i < nodesList.length ; i ++) {
        var divNode = nodesList[i];
        if (isAncestorBlockquote(divNode)) {
            continue;
        }
        if (divNode.querySelector('div') != null) {
            continue;
        }
        var textContent = nodesList[i].textContent;
        textContent = textContent.replace(/\n/g, '');
        if (textContent == 'Begin forwarded message:') {
            outlookQuoteFromNode(node, divNode);
            break;
        }
        else if (textContent.indexOf('-- Forwarded message --') != -1) {
            outlookQuoteFromNode(node, divNode);
            break;
        }
    }
}

function collapseOriginalMessage(node)
{
    var nodesList = node.querySelectorAll('div');
    var originalEnRegex = /^--+ ?Original Message ?--+$/i;
    var originalFrRegex = /^--+ Message original --+$/i;
    for(var i = 0 ; i < nodesList.length ; i ++) {
        var divNode = nodesList[i];
        if (isAncestorBlockquote(divNode)) {
            continue;
        }
        var textContent = nodesList[i].textContent;
        textContent = textContent.replace(/\n/g, '');
        if (originalEnRegex.test(textContent)) {
            outlookQuoteFromNode(node, divNode);
            break;
        }
        if (originalFrRegex.test(textContent)) {
            outlookQuoteFromNode(node, divNode);
            break;
        }
    }
}

function convertToCharCode(str)
{
    var result = '';
    for(var i = 0 ; i < str.length ; i ++) {
        result += ' ' + str.charCodeAt(i);
    }
    return result;
}

function isHeaders(node, divNode)
{
    if (divNode == null) {
        return;
    }
    if (isAncestorBlockquote(divNode)) {
        return;
    }
    //var textContent = nodesList[i].textContent;
    //console.log('|' + textContent + '|');
    var headers = [].slice.call(divNode.querySelectorAll('b'));
    var otherHeaders = [].slice.call(divNode.querySelectorAll('span[style]'));
    headers = headers.concat(otherHeaders);
    var hasFrom = false;
    var hasSent = false;
    var hasTo = false;
    var hasSubject = false;
    for(var k = 0 ; k < headers.length ; k ++) {
        if (headers[k].tagName == 'SPAN') {
            if (headers[k].style.fontWeight != 'bold') {
                continue;
            }
        }
        var headerName = headers[k].textContent;
        headerName = headerName.replace(/\n/g, '');
        headerName = headerName.replace(/[\u00a0]/g, ' ');
        if (headerName == 'From:') {
            hasFrom = true;
        }
        else if (headerName == 'Sent:') {
            hasSent = true;
        }
        else if (headerName == 'Date:') {
            hasSent = true;
        }
        else if (headerName == 'To:') {
            hasTo = true;
        }
        else if (headerName == 'Subject:') {
            hasSubject = true;
        }
        else if (headerName == 'De :') {
            hasFrom = true;
        }
        else if (headerName == 'Envoyé :') {
            hasSent = true;
        }
        else if (headerName == 'Envoyé le :') {
            hasSent = true;
        }
        else if (headerName == 'Date :') {
            hasSent = true;
        }
        else if (headerName == 'À :') {
            hasTo = true;
        }
        else if (headerName == 'Objet :') {
            hasSubject = true;
        }
    }
    if (hasFrom && hasSent && hasTo && hasSubject) {
        outlookQuoteFromNode(node, divNode);
        return true;
    }
    return false;
}

function collapseMessageFromHeader(node)
{
    var nodesList = node.querySelectorAll('p');
    for(var i = 0 ; i < nodesList.length ; i ++) {
        var divNode = nodesList[i];
        if (isHeaders(node, divNode)) {
            break;
        }
    }
    var nodesList = node.querySelectorAll('table');
    for(var i = 0 ; i < nodesList.length ; i ++) {
        var divNode = nodesList[i];
        if (isHeaders(node, divNode)) {
            break;
        }
    }
    var nodesList = node.querySelectorAll('div[style*="border-top"]');
    for(var i = 0 ; i < nodesList.length ; i ++) {
        var divNode = nodesList[i];
        if (isHeaders(node, divNode)) {
            break;
        }
    }
    var nodesList = node.querySelectorAll('div[style*="BORDER-TOP"]');
    for(var i = 0 ; i < nodesList.length ; i ++) {
        var divNode = nodesList[i];
        if (isHeaders(node, divNode)) {
            break;
        }
    }
    var nodesList = node.querySelectorAll('hr');
    for(var i = 0 ; i < nodesList.length ; i ++) {
        var divNode = next_sibling(nodesList[i]);
        if ((divNode != null) && (divNode.nodeType == Node.ELEMENT_NODE)) {
            if (isHeaders(node, divNode)) {
                break;
            }
        }
    }
}

function readabilityCleanStyles( e ) {
    e = e || document;
    var cur = e.firstChild;
    
    // If we had a bad node, there's not much we can do.
    if(!e)
        return;
    
    var fontWeightValue;
    var textDecorationValue;
    var fontStyleValue;
    var fontColorValue;
    var displayValue;
    var maxWidth;
    var visibility;
    var height;
    var fontSize;

    // Remove any root styles, if we're able.
    /*
    if(typeof e.removeAttribute == 'function')
    e.removeAttribute('style');
    */
    
    // Go until there are no more child nodes
    while ( cur != null ) {
        if ( cur.nodeType == Node.ELEMENT_NODE ) {
            if (cur.tagName == 'TABLE') {
                cur = cur.nextSibling;
                continue;
            }
            if (!cur.classList.contains('btn')) {
                // Remove style attribute(s) :
                fontWeightValue = cur.style.fontWeight;
                textDecorationValue = cur.style.textDecoration;
                fontStyleValue = cur.style.fontStyle;
                fontColorValue = cur.style.color;
                maxWidth = cur.style.maxWidth;
                visibility = cur.style.visibility;
                height = cur.style.height;
                fontSize = cur.style.fontSize;

                displayValue = null;
                if ((cur.style.display == 'none') || (cur.style.display == 'hidden')) {
                    displayValue = cur.style.display;
                }

                if ((cur.style.borderLeftStyle == 'solid') && (cur.tagName == 'BLOCKQUOTE')) {
                    cur.setAttribute('type', 'cite');
                }

                if ((fontColorValue == '#fff') || (fontColorValue == '#ffffff') || (fontColorValue == 'white') || (fontColorValue == 'rgb(255, 255, 255)')) {
                    fontColorValue = null;
                }

                cur.removeAttribute("style");

                cur.style.fontWeight = fontWeightValue;
                cur.style.textDecoration = textDecorationValue;
                cur.style.fontStyle = fontStyleValue;
                cur.style.color = fontColorValue;
                cur.style.maxWidth = maxWidth;
                cur.style.visibility = visibility;
                if (displayValue != null) {
                    cur.style.display = displayValue;
                }
                if (height != null) {
                    if ((height == '0') || (height == '0px')) {
                        cur.style.height = height;
                    }
                }
                if (fontSize == '0px') {
                    cur.style.fontSize = fontSize;
                }
            }
            readabilityCleanStyles( cur );
        }
        cur = cur.nextSibling;
    }
}

function readabilityKillDivs ( e ) {
    var divsList = e.getElementsByTagName( "div" );
    var curDivLength = divsList.length;
	
    // Gather counts for other typical elements embedded within.
    // Traverse backwards so we can remove nodes at the same time without effecting the traversal.
    for (var i=curDivLength-1; i >= 0; i--) {
        var p = divsList[i].getElementsByTagName("p").length;
        var img = divsList[i].getElementsByTagName("img").length;
        var li = divsList[i].getElementsByTagName("li").length;
        var a = divsList[i].getElementsByTagName("a").length;
        var embed = divsList[i].getElementsByTagName("embed").length;
        
        // If the number of commas is less than 10 (bad sign) ...
        if ( getCharCount(divsList[i]) < 10) {
            // And the number of non-paragraph elements is more than paragraphs 
            // or other ominous signs :
            if ( img > p || li > p || a > p || p == 0 || embed > 0) {
                divsList[i].parentNode.removeChild(divsList[i]);
            }
        }
    }
    return e;
}

function readabilityRemoveEmptyParagraphs(node)
{
    var nodeList = node.querySelectorAll('p');
    for (var i = 0 ; i < nodeList.length ; i ++) {
        var item = nodeList[i];
        if (item.querySelector('img') != null) {
            continue;
        }
        var str = item.textContent;
        str = str.replace(/\n/g, '');
        str = str.replace(/ /g, '');
        if ((str == '\u00a0') || (str == '')) {
            item.parentNode.removeChild(item);
        }
    }
}

function readabilityRemoveHR(node)
{
    var nodeList = node.querySelectorAll('hr');
    for (var i = 0 ; i < nodeList.length ; i ++) {
        var item = nodeList[i];
        item.parentNode.removeChild(item);
    }
}

function replaceBrWithDiv(node)
{
    while (1) {
        var item = node.querySelector('br:not(.done)');
        if (item == null) {
            break;
        }
        replaceBrInNode(item.parentNode);
    }
}

function replaceBrInNode(node)
{
    var lines = [];
    var currentLine = document.createElement('div');
    lines.push(currentLine);
    var child = node.firstChild;
    var previousNodeIsLine = false;
    while (child != null) {
        var nextChild = child.nextSibling;
        if (child.nodeType == Node.ELEMENT_NODE) {
            if (child.tagName == 'BR') {
                //console.log('add new line ' + currentLine.outerHTML);
                node.removeChild(child);
                child = nextChild;
                currentLine = document.createElement('div');
                lines.push(currentLine);
                continue;
            }
        }
        if (previousNodeIsLine && (child.nodeType == Node.TEXT_NODE)) {
            currentLine = document.createElement('div');
            lines.push(currentLine);
        }
        currentLine.appendChild(child);
        previousNodeIsLine = false;
        if (child.nodeType == Node.ELEMENT_NODE) {
            if ((child.tagName == 'P') || (child.tagName == 'DIV')) {
                previousNodeIsLine = true;
            }
        }
        child = nextChild;
    }
    
    var hasContent = false;
    lines.forEach(function(line) {
        if (line.firstChild != null) {
            hasContent = true;
        }
    });
    if (hasContent) {
        lines.forEach(function(line, idx) {
            if (line.querySelector('img') != null) {
                node.appendChild(line);
                return;
            }
            var lineText = line.textContent;
            lineText = lineText.replace(/\n/g, '');
            lineText = lineText.replace(/ /g, '');
            isEmpty = (lineText == '');
            if (idx != lines.length - 1) {
                if (isEmpty) {
                    isEmpty = false;
                    line.innerHTML = '<br class="done"/>';
                }
            }
            if (!isEmpty) {
                node.appendChild(line);
            }
        });
    }
    else {
        node.innerHTML = '<br class="done"/>';
    }
}

function isAncestorBlockquote(node){
    if (node == null) {
        return false;
    }
    if (node.tagName == 'BLOCKQUOTE') {
        return true;
    }
    return isAncestorBlockquote(node.parentNode);
}

function getSignatureSeparator(node)
{
    var nodeList = node.querySelectorAll('div');
    for (var i = 0 ; i < nodeList.length ; i ++) {
        var item = nodeList[i];
        if (item.querySelector('img') != null) {
            continue;
        }
        if (isAncestorBlockquote(item)) {
            continue;
        }
        var str = item.textContent;
        var done = false;
        while (!done) {
            var idxeol = str.indexOf('\n');
            //console.log('text? |' + str + '| ' + idxeol);
            var remaining = '';
            if (idxeol != -1) {
                remaining = str.substring(idxeol + 1, str.length);
                str = str.substring(0, idxeol - 1);
                //console.log('text2? |' + str + '| |' + remaining + '|');
                if (str == '') {
                    str = remaining;
                    if (str == '') {
                        done = true;
                    }
                }
                else {
                    done = true;
                }
            }
            else {
                done = true;
            }
        }
        str = str.replace(/\n/g, '');
        if (str == '--\u00a0') {
            return item;
        }
        if (str == '\u2014\u00a0') {
            return item;
        }
        if (str == '--') {
            return item;
        }
        if (str == '-- ') { // standard signature
            return item;
        }
        if (str == '\u2014') { // github
            return item;
        }
        //console.log(str);
//        if (str == '\u2014') {
//            return item;
//        }
        if (str == 'No virus found in this message.') {
            return item;
        }
        if (str == 'Sent from my iPhone') {
            return item;
        }
        if (str == 'Sent from my iPad') {
            return item;
        }
        //—
    }
    return null;
}

function collapseSignature(node, forceHide)
{
    var item = getSignatureSeparator(node);
    if (item == null) {
        return;
    }

    if (!forceHide) {
        var hasLink = false;
        var currentChild = item;
        while (currentChild != null) {
            if (currentChild.nodeType == Node.ELEMENT_NODE) {
                if (currentChild.tagName != 'BLOCKQUOTE') {
                    if (currentChild.querySelector('a:not(.-dejalu-autolinker)') != null) {
                        hasLink = true;
                        break;
                    }
                }
            }
            currentChild = currentChild.nextSibling;
        }
        
        if (hasLink) {
            return;
        }
    }

    var blockquote = document.createElement('div');
    blockquote.classList.add('signature');
    //blockquote.setAttribute('type', 'cite');
    var parentNode = item.parentNode;
    parentNode.insertBefore(blockquote, item);

    currentChild = item;
    while (currentChild != null) {
        //console.log('elt: |' + str + '| ' + currentChild.outerHTML);
        if (currentChild.tagName == 'DIV') {
            if (item.querySelector('img') == null) {
                var str = currentChild.textContent;
                str = str.replace(/\n/g, '');
                //console.log('signature: |' + str + '| ' + currentChild.outerHTML);
                if (str == '') {
                    break;
                }
            }
        }
        if (currentChild.tagName == 'BLOCKQUOTE') {
            break;
        }
        if (currentChild.tagName == 'P') {
            break;
        }
        if (currentChild.nodeType == Node.ELEMENT_NODE) {
            if (currentChild.querySelector('blockquote') != null) {
                break;
            }
        }
        
        var nextChild = currentChild.nextSibling;
        var parentOfChild = currentChild.parentNode;
        blockquote.appendChild(currentChild);
        while (nextChild == null) {
            currentChild = parentOfChild;
            if (currentChild == null) {
                break;
            }
            nextChild = currentChild.nextSibling;
            if (nextChild == null) {
                parentOfChild = currentChild.parentNode;
            }
        }
        currentChild = nextChild;
    }
    
    blockquote.parentNode.removeChild(blockquote);
}

function removeFirstWhitespace(node)
{
    var lastChild = first_child(node);
    while (lastChild != null) {
        var removed = false;
        
        var previous = next_sibling(lastChild);
        
        if (lastChild.tagName == 'DIV') {
            removeFirstWhitespace(lastChild);
            
            var subchild = first_child(lastChild);
            if (subchild == null) {
                lastChild.parentNode.removeChild(lastChild);
                removed = true;
            }
        }
        else if (lastChild.tagName == 'P') {
            var node = first_child(lastChild);
            if (node == null) {
                lastChild.parentNode.removeChild(lastChild);
                removed = true;
            }
            else {
                lastChild.style.marginTop = '0px';
            }
        }
        else if (lastChild.tagName == 'BR') {
            lastChild.parentNode.removeChild(lastChild);
            removed = true;
        }
        
        if (!removed) {
            break;
        }
        
        lastChild = previous;
    }
}

function removeLastWhitespace(node)
{
    var lastChild = last_child(node);
    while (lastChild != null) {
        var removed = false;
        
        var previous = previous_sibling(lastChild);
        
        if (lastChild.tagName == 'DIV') {
            removeLastWhitespace(lastChild);
            
            var subchild = first_child(lastChild);
            if (subchild == null) {
                lastChild.parentNode.removeChild(lastChild);
                removed = true;
            }
        }
        else if (lastChild.tagName == 'P') {
            var node = first_child(lastChild);
            if (node == null) {
                lastChild.parentNode.removeChild(lastChild);
                removed = true;
            }
            else {
                lastChild.style.marginBottom = '0px';
            }
        }
        else if (lastChild.tagName == 'BR') {
            lastChild.parentNode.removeChild(lastChild);
            removed = true;
        }
        
        if (!removed) {
            break;
        }
        
        lastChild = previous;
    }
}

function replaceImageWithText(node)
{
    var nodeList = node.querySelectorAll('img');
    for (var i = 0 ; i < nodeList.length ; i ++) {
        var item = nodeList[i];
        var replacedItem = document.createElement('div');
        replacedItem.style.backgroundColor = '#eee';
        replacedItem.style.display = 'inline-block';
        replacedItem.style.width = item.width + 'px';
        replacedItem.style.height = item.height + 'px';
        //replacedItem.innerText = '<image>';
        item.parentNode.insertBefore(replacedItem, item);
        item.parentNode.removeChild(item);
    }
}

function removeLegalTextForItem(item)
{
    if (item.querySelector('img') != null) {
        return;
    }
    var text = item.textContent;
    // replace &nbsp;
    text = text.replace(/[\r\n\t\u00a0]/g, ' ');
    text = text.replace(/^[" ]+/, '');
    text = text.replace(/[" ]+$/, '');
    // replace double space
    text = text.replace(/ +/g, ' ');
    if (text == "The information in this electronic mail message is the sender's confidential business and may be legally privileged. It is intended solely for the addressee(s). Access to this internet electronic mail message by anyone else is unauthorized. If you are not the intended recipient, any disclosure, copying, distribution or any action taken or omitted to be taken in reliance on it is prohibited and may be unlawful.") {
        item.textContent = '';
    }
    else if (text == "The sender believes that this E-mail and any attachments were free of any virus, worm, Trojan horse, and/or malicious code when sent. This message and its attachments could have been infected during transmission. By reading the message and opening any attachments, the recipient accepts full responsibility for taking protecti ve and remedial action about viruses and other defects. The sender's company is not liable for any loss or damage arising in any way from this message or its attachments.") {
        item.textContent = '';
    }
    else if (text == "The sender believes that this E-mail and any attachments were free of any virus, worm, Trojan horse, and/or malicious code when sent. This message and its attachments could have been infected during transmission. By reading the message and opening any attachments, the recipient accepts full responsibility for taking protective and remedial action about viruses and other defects. The sender's company is not liable for any loss or damage arising in any way from this message or its attachments.") {
        item.textContent = '';
    }
    else if (text == "Nothing in this email shall be deemed to create a binding contract to purchase/sell real estate. The sender of this email does not have the authority to bind a buyer or seller to a contract via written or verbal communications including, but not limited to, email communications.") {
        item.textContent = '';
    }
    else if (text == "If this email was sent to you as an unsecured message, it is not intended for confidential or sensitive information. If you cannot respond to this e-mail securely, please do not include your social security number, account number, or any other personal or financial information in the content of the email.") {
        item.textContent = '';
    }
    else if (text == "Wells Fargo Home Mortgage is a division of Wells Fargo Bank, N.A. All rights reserved. Equal Housing Lender. Wells Fargo Home Mortgage-2701 Wells Fargo Way-Minneapolis, MN 55467-8000") {
        item.textContent = '';
    }
    else if (text == "This may be a promotional email. To discontinue receiving promotional emails from Wells Fargo Bank N.A., including Wells Fargo Home Mortgage, click here NoEmailRequest@wellsfargo.com .") {
        item.textContent = '';
    }
    else if (text == "ATTENTION: THIS E-MAIL MAY BE AN ADVERTISEMENT OR SOLICITATION FOR PRODUCTS AND SERVICES.") {
        item.textContent = '';
    }
    else if (text == "Neither of these actions will affect delivery of important service messages regarding your accounts that we may need to send you or preferences you may have previously set for other e-mail services.") {
        item.textContent = '';
    }
    else if (text == "For additional information regarding our electronic communication policies, visit  http://wellsfargoadvisors.com/disclosures/email-disclosure.html .") {
        item.textContent = '';
    }
    else if (text == "Investment and insurance products are not insured by the FDIC or any federal government agency, are not bank deposits, are not obligations of or guaranteed by Citibank and are subject to investment risks, including possible loss of the principal amount invested.") {
        item.textContent = '';
    }
    else if (text == 'Citi Personal Wealth Management is a business of Citigroup Inc., which offers investment products through Citigroup Global Markets Inc. (“CGMI”), member SIPC. Insurance products are offered through Citigroup Life Agency LLC ("CLA"). In California, CLA does business as Citigroup Life Insurance Agency, LLC (license number 0G56746). CGMI, CLA and Citibank, N.A. are affiliated companies under the common control of Citigroup Inc. Citi and Citi with Arc Design are registered service marks of Citigroup Inc. or its affiliates.') {
        item.textContent = '';
    }
    else if (text == "E-mail sent through the internet is not secure. Do not use e-mail to send us confidential information. Do not e-mail orders to buy or sell securities, transfer funds or send time-sensitive instructions. We will not accept them. This e-mail is not an official trade confirmation for your transactions. Your e-mail message is not private in that it is subject to review by CGMI, its officers, agents and employees and to disclose as required or permitted under applicable law.") {
        item.textContent = '';
    }
    else if (text == "The sender believes that this E-mail and any attachments were free of any virus, worm, Trojan horse, and/or malicious code when sent. This message and its attachments could have been infected during transmission. By reading the message and opening any attachments, the recipient accepts full responsibility for taking protective a nd remed ial action about viruses and other defects. The sender's company is not liable for any loss or damage arising in any way from this message or its attachments.") {
        item.textContent = '';
    }
    else if (text == "This message may contain confidential and/or privileged information. If you are not the addressee or authorized to receive this for the addressee, you must not use, copy, disclose, or take any action based on this message or any information herein. If you have received this message in error, please advise the sender immediately by reply e-mail and delete this message. Thank you for your cooperation.") {
         item.textContent = '';
    }
}

function removeLegalText(node)
{
    var nodeList = node.querySelectorAll('div');
    for (var i = 0 ; i < nodeList.length ; i ++) {
        var item = nodeList[i];
        removeLegalTextForItem(item);
    }
    nodeList = node.querySelectorAll('p');
    for (var i = 0 ; i < nodeList.length ; i ++) {
        var item = nodeList[i];
        removeLegalTextForItem(item);
    }
}

function removeComments(e)
{
    var cur = e.firstChild;
    while ( cur != null ) {
        var next = cur.nextSibling;;
        if (cur.nodeType == Node.ELEMENT_NODE) {
            removeComments(cur);
        }
        else if (cur.nodeType == Node.COMMENT_NODE) {
            e.removeChild(cur);
        }
        cur = next;
    }
}

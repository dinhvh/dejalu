// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

var s_forwardedHeaders = {};

var setSubject = function(subject) {
    if ((subject == null) || (subject == '')) {
        subject = 'No subject';
    }
    document.querySelector('#reply-header .subject').textContent = subject;
};

var objcSetDarkMode = function(enabled) {
    if (enabled) {
        document.body.classList.add('dark-mode');
    } else {
        document.body.classList.remove('dark-mode');
    }
};

var objcSetRepliedContent = function(jsonInfo, addressesDisplayString, quotedHeadString) {
    var info = JSON.parse(jsonInfo);
    var content = info['content'];
    var node = null;
    if (content != null) {
        var autolinker = new Autolinker({newWindow : false,
            phone: false,
            hashtag: false,
        });
        content = autolinker.link(content);
        var node = getNodeHTML(content);
        var nodes = node.querySelectorAll('.no-resend');
        nodes = [].slice.call(nodes);
        nodes.forEach(function(nodeToRemove) {
            nodeToRemove.parentNode.removeChild(nodeToRemove);
        });
        nodes = node.querySelectorAll('.-dejalu-needs-html-filter');
        nodes = [].slice.call(nodes);
        nodes.forEach(function(nodeForFilter) {
            fixedNodeHTMLFormatting(nodeForFilter, null, {}, true, true);
            collapseSignature(node, true);
            readabilityCleaning(nodeForFilter);
            collapseMessage(nodeForFilter);
            removeFirstWhitespace(nodeForFilter);
            removeLastWhitespace(nodeForFilter);
            replaceImageWithText(nodeForFilter);
        });
    }

    composerType = 'reply';
    document.body.classList.add('reply');
    var repliedTextNode = document.querySelector('#replied-text .content');
    if (node != null) {
        repliedTextNode.appendChild(node);
    }
    document.querySelector('#replied-text .sender').textContent = info['sender'];
    document.querySelector('#replied-text .date').textContent = info['date'];
    document.querySelector('#replied-text .quoted-head').textContent = quotedHeadString;
    document.querySelector('#reply-header .recipient').textContent = addressesDisplayString;
    setSubject(info['subject']);
};

var objcSetForwardedContent = function(jsonInfo, quotedHeadString, jsonForwardedHeaders) {
    var forwardedHeaders = JSON.parse(jsonForwardedHeaders);
    var info = JSON.parse(jsonInfo);
    var content = info['content'];
    var node = null;
    if (content != null) {
        var autolinker = new Autolinker({newWindow : false,
            phone: false,
            hashtag: false,
        });
        content = autolinker.link(content);
        var node = getNodeHTML(content);
        var nodes = node.querySelectorAll('.-dejalu-needs-html-filter');
        nodes = [].slice.call(nodes);
        nodes.forEach(function(nodeForFilter) {
            fixedNodeHTMLFormatting(nodeForFilter, null, {}, true, true);
            collapseSignature(node, true);
            readabilityCleaning(nodeForFilter);
            //collapseMessage(nodeForFilter);
            removeFirstWhitespace(nodeForFilter);
            removeLastWhitespace(nodeForFilter);
            //replaceImageWithText(nodeForFilter);
        });
    }

    s_forwardedHeaders = forwardedHeaders;

    composerType = 'forward';
    console.log(info);
    if (info['mixed-text-attachments'] == 0) {
        loadContentAttachments(info, node);
    }
    else {
        replaceImageAttachments(info, node);
        replaceAttachments(info, node);
    }

    document.body.classList.add('reply');
    document.body.classList.add('forward');
    var repliedTextNode = document.querySelector('#replied-text .content');
    if (node != null) {
        repliedTextNode.appendChild(node);
    }
    document.querySelector('#replied-text .sender').textContent = info['sender'];
    document.querySelector('#replied-text .date').textContent = info['date'];
    document.querySelector('#replied-text .quoted-head').textContent = quotedHeadString;
    document.querySelector('#reply-header .recipient').textContent = '';
    setSubject(info['subject']);

    loadImages();
};

var getReplyHTMLMessageContent = function(cleanForSend, cleanContainer) {
    var quoteHeaderString = document.querySelector('#reply-container .quoted-head').textContent;
    var contentAndCIDUrls = getHTMLMessageContentCommon(cleanForSend);
    var content = contentAndCIDUrls.html;
    var cidUrls = contentAndCIDUrls['cid-urls'];
    var fakeUrls = contentAndCIDUrls['fake-urls'];
    var quotedNode = document.querySelector('#reply-container .content').cloneNode(true);
    var quotedCidUrls = replaceImageCIDInNode(quotedNode);
    var cidUrls = cidUrls.concat(quotedCidUrls);

    var quotedContent = quotedNode.innerHTML;
    var messageElement = document.querySelector('#message-reply-generator').cloneNode(true);
    var headersNode = messageElement.querySelector('.quoted-message .headers');
    if (composerType == 'forward') {
        headersNode.querySelector('.from').textContent = s_forwardedHeaders.from;
        headersNode.querySelector('.date').textContent = s_forwardedHeaders.fulldate;
        headersNode.querySelector('.subject').textContent = s_forwardedHeaders.subject;
        headersNode.querySelector('.to').textContent = s_forwardedHeaders.to;
        headersNode.querySelector('.from').removeAttribute('class');
        headersNode.querySelector('.date').removeAttribute('class');
        headersNode.querySelector('.subject').removeAttribute('class');
        headersNode.querySelector('.to').removeAttribute('class');
    }
    else {
        headersNode.parentNode.removeChild(headersNode);
        headersNode = null;
    }
    messageElement.querySelector('.message').innerHTML = content;
    messageElement.querySelector('.quote-header').textContent = quoteHeaderString;
    messageElement.querySelector('.quoted-message .content').innerHTML = quotedContent;
    var nodeList = messageElement.querySelector('.quoted-message').querySelectorAll('.-dejalu-needs-html-filter');
    for (var i = 0 ; i < nodeList.length ; i ++) {
        var item = nodeList[i];
        item.removeAttribute('class');
    }
    //messageElement.querySelector('.reply-meta .sender').innerText = document.querySelector('#reply-container .sender').innerText;
    //messageElement.querySelector('.reply-meta .date').innerText = document.querySelector('#reply-container .date').innerText;
    var headerMetaInfo = {'sender': document.querySelector('#reply-container .sender').textContent, 'date': document.querySelector('#reply-container .date').textContent, 'type': composerType};
    if (composerType == 'forward') {
        headerMetaInfo.from = s_forwardedHeaders.from;
        headerMetaInfo.fulldate = s_forwardedHeaders.fulldate;
        headerMetaInfo.subject = s_forwardedHeaders.subject;
        headerMetaInfo.to = s_forwardedHeaders.to;
    }

    if (cleanForSend || cleanContainer) {
        //var nodeToRemove = messageElement.querySelector('.reply-meta');
        //nodeToRemove.parentNode.removeChild(nodeToRemove);
        if (headersNode != null) {
            headersNode.classList.remove('headers');
        }
        messageElement.querySelector('.message').removeAttribute('class');
        messageElement.querySelector('.quote-header').removeAttribute('class');
        messageElement.querySelector('.quoted-message .content').removeAttribute('class');
        messageElement.querySelector('.quoted-message').removeAttribute('class');
    }

    return {'html': messageElement.innerHTML,
        'cid-urls': cidUrls,
        'fake-urls': fakeUrls,
        'header-meta': headerMetaInfo};
};

var objcReplyHTMLMessageContent = function(cleanForSend) {
    var info;
    if (document.body.classList.contains('reply')) {
        info = getReplyHTMLMessageContent(cleanForSend, false);
    }
    else {
        info = getHTMLMessageContentCommon(cleanForSend);
    }
    return JSON.stringify(info);
};

var replaceImageCIDInNode = function(node) {
    var nodeList = node.querySelectorAll('img');
    var cidUrls = [];
    for(var i = 0 ; i < nodeList.length ; i ++) {
        var item = nodeList[i];
        var url = item.getAttribute('x-dejalu-original-src');
        if (url != null) {
            item.removeAttribute('x-dejalu-original-src');
            item.src = url;
            cidUrls.push(url);
        }
    }
    return cidUrls;
};

var replaceFakeUrlInNode = function(node) {
    var nodeList = node.querySelectorAll('img');
    var fakeUrls = {};
    for(var i = 0 ; i < nodeList.length ; i ++) {
        var item = nodeList[i];
        var url = item.getAttribute('src');
        console.log(item);
        if (url != null) {
            if (url.indexOf('webkit-fake-url:') == 0) {
                fakeUrls[url] = UUID.generate();
                item.src = 'cid:' + fakeUrls[url];
            }
        }
    }
    return fakeUrls;
};

var getHTMLMessageNodeCommon = function(cleanForSend) {
    var contentNode = document.querySelector('#editor').cloneNode(true);
    if (cleanForSend) {
        var signatureNode = contentNode.querySelector('#signature');
        if (signatureNode != null) {
            signatureNode.removeAttribute('id');
            signatureNode.removeAttribute('class');
        }
    }
    var cidUrls = replaceImageCIDInNode(contentNode);
    var fakeUrls = replaceFakeUrlInNode(contentNode);
    return {'node': contentNode, 'cid-urls': cidUrls, 'fake-urls': fakeUrls}
};

var getHTMLMessageContentCommon = function(cleanForSend) {
    var info = getHTMLMessageNodeCommon(cleanForSend);
    var contentNode = info['node'];
    var cidUrls = info['cid-urls'];
    var fakeUrls = info['fake-urls'];
    return {'html': contentNode.innerHTML, 'cid-urls': cidUrls, 'fake-urls': fakeUrls}
};

var objcHTMLMessageContent = function(cleanForSend) {
    var result = getHTMLMessageContentCommon(cleanForSend);
    return JSON.stringify(result);
};

var isEOL = function(node) {
    if (node == null) {
        return false;
    }
    if (node.tagName != 'DIV') {
        return false;
    }
    if (!number_of_children(node) == 1) {
        return false;
    }
    if (first_child(node).tagName != 'BR') {
        return false;
    }
    return true;
};

var objcSetSignature = function(signature, cidsJson) {
    var editorNode = document.querySelector('#editor');
    var signatureNode = document.querySelector('#signature');
    if (signatureNode == null) {
        signatureNode = document.createElement('div');
        signatureNode.id = 'signature';
        editorNode.appendChild(signatureNode);
    }
    var eolNode;
    if (!signatureNode.classList.contains('added')) {
        signatureNode.classList.add('added');
        eolNode = getNodeHTML('<br/>');
        editorNode.insertBefore(eolNode, signatureNode);
    }

    if ((signature != '<div><br></div><div></div>') &&
        (signature != '<div><br></div>') &&
        (signature != '<br>') &&
        (signature != '')) {
        if (!signatureNode.classList.contains('padding')) {
            signatureNode.classList.add('padding');
            eolNode = getNodeHTML('<br/>');
            editorNode.insertBefore(eolNode, signatureNode);
        }
        else {
            eolNode = signatureNode.previousSibling;
            if (!isEOL(eolNode)) {
                eolNode = getNodeHTML('<br/>');
                editorNode.insertBefore(eolNode, signatureNode);
            }
        }
        objcReplaceSignature(signature, cidsJson);
    }
    else {
        if (signatureNode.classList.contains('padding')) {
            eolNode = signatureNode.previousSibling;
            if (isEOL(eolNode)) {
                signatureNode.classList.remove('padding');
            }
            editorNode.removeChild(eolNode);
        }
        signatureNode.innerHTML = '';
    }
};

var objcReplaceSignature = function(signature, cidsJson) {
    var cids = JSON.parse(cidsJson);
    var signatureNode = document.querySelector('#signature');
    var editorNode = document.querySelector('#editor');
    signatureContent = getNodeHTML(signature);
    signatureNode.innerHTML = '';
    signatureNode.appendChild(signatureContent);
    var images = signatureNode.querySelectorAll('img')
    images = [].slice.call(images);
    images.forEach(function(imgNode) {
        if (cids[imgNode.src] != null) {
            imgNode.setAttribute('x-dejalu-original-src', 'cid:' + cids[imgNode.src]);
            loadImageElement(imgNode);
        }
    });
};

var objcHasSignatureChanged = function(signature) {
    var signatureNode = document.querySelector('#signature');
    if (signatureNode == null) {
        return true;
    }
    signatureContent = getNodeHTML(signature);
    return signatureNode.textContent != signatureContent.textContent;
};

var objcCanEditAllContent = function() {
    return document.body.classList.contains('reply');
};

var objcEditAllContent = function() {
    var info = getReplyHTMLMessageContent(false, true);
    document.body.classList.remove('reply');
    document.querySelector('#editor').innerHTML = info['html'];
    showRecipientEditor();
};

var objcSetHTMLMessageContent = function(subject, recipient, jsonReplyMetaInfo, content) {
    var replyMetaInfo = JSON.parse(jsonReplyMetaInfo);
    var isReply = false;
    var node = getNodeHTML(content);
    var writtenNode = node.querySelector('.message');
    var quoteHeader = node.querySelector('.quote-header');
    var quotedMessage = node.querySelector('.quoted-message');
    //var senderNode = node.querySelector('.reply-meta .sender');
    //var dateNode = node.querySelector('.reply-meta .date');
    if ((quoteHeader != null) && (quotedMessage != null)) {
        document.body.classList.add('reply');
        var repliedTextNode = document.querySelector('#replied-text .content');
        if (quotedMessage.querySelector('.content') != null) {
            repliedTextNode.innerHTML = quotedMessage.querySelector('.content').innerHTML;
        }
        else {
            repliedTextNode.innerHTML = quotedMessage.innerHTML;
        }
        //document.querySelector('#replied-text .sender').textContent = senderNode.textContent;
        //document.querySelector('#replied-text .date').textContent = dateNode.textContent;
        composerType = replyMetaInfo['type'];
        if (composerType == 'forward') {
            document.body.classList.add('forward');

            s_forwardedHeaders = {};
            s_forwardedHeaders.from = replyMetaInfo.from;
            s_forwardedHeaders.fulldate = replyMetaInfo.fulldate;
            s_forwardedHeaders.subject = replyMetaInfo.subject;
            s_forwardedHeaders.to = replyMetaInfo.to;
        }
        document.querySelector('#replied-text .sender').textContent = replyMetaInfo['sender'];
        document.querySelector('#replied-text .date').textContent = replyMetaInfo['date'];
        document.querySelector('#replied-text .quoted-head').textContent = quoteHeader.textContent;
        document.querySelector('#reply-header .recipient').textContent = recipient;
        setSubject(subject);
        //document.querySelector('#reply-header .subject').textContent = subject;
        document.querySelector('#editor').innerHTML = writtenNode.innerHTML;
        isReply = true;
    }
    else {
        document.querySelector('#editor').innerHTML = content;
    }
    var imgNodes = document.querySelector('#editor').querySelectorAll('img');
    var images = [].slice.call(imgNodes);
    images.forEach(function(element) {
        loadImageElement(element);
    });
    loadImages();

    return isReply;
};

var objcFocus = function() {
    var el = document.querySelector('#editor');
    var range = document.createRange();
    range.selectNodeContents(el);
    range.collapse(true);
    window.getSelection().removeAllRanges();
    window.getSelection().addRange(range);
};

var objcIsNodeTextContents = function(node)
{
    while (node != null) {
        if (node.nodeType == Node.ELEMENT_NODE) {
            if (node.classList.contains("selectable")) {
                return true;
            }
        }
        node = node.parentNode;
    }

    return false;
}

var rangeIsInEditor = function(range)
{
    var node = range.commonAncestorContainer;
    if (node == null) {
        return false;
    }

    while (node != null) {
        if (node.nodeType == Node.ELEMENT_NODE) {
            if (node.id == 'editor') {
                return true;
            }
        }
        node = node.parentNode;
    }

    return false;
}

var checkSelectionTimer = null;
var lastEditorSelectionRange = null;

var selectionChangeHandler = function() {
    saveEditorSelection();
    if (checkSelectionTimer != null) {
        clearTimeout(checkSelectionTimer);
        checkSelectionTimer = null;
    }
    checkSelectionTimer = setTimeout(function() { checkSelection(); }, 500);
};

var checkSelection = function() {
    checkSelectionTimer = null;

    if (!window.getSelection().isCollapsed) {
        return;
    }
    if (window.getSelection().rangeCount == 0) {
        restoreEditorSelection();
        return;
    }
    var range = window.getSelection().getRangeAt(0);
    if (!rangeIsInEditor(range)) {
        restoreEditorSelection();
    }
};

var restoreEditorSelection = function() {
    if (lastEditorSelectionRange == null) {
        objcFocus();
    }
    else {
        console.log('restore selection');
        window.getSelection().removeAllRanges();
        window.getSelection().addRange(lastEditorSelectionRange);
    }
};

var saveEditorSelection = function() {
    if (window.getSelection().rangeCount == 0) {
        return;
    }
    var range = window.getSelection().getRangeAt(0);
    if (!rangeIsInEditor(range)) {
        return;
    }
    lastEditorSelectionRange = range;
};

var showNativeRecipientEditor = function(callback) {
    var commandInfo = {'command': 'jsShowRecipientEditor'};
    runCommand(commandInfo, callback);
};

var showNativeSubjectEditor = function(callback) {
    var commandInfo = {'command': 'jsShowSubjectEditor'};
    runCommand(commandInfo, callback);
};

var showRecipientEditor = function() {
    //document.querySelector('#reply-header-container .recipient-container').classList.add('hidden');
    //document.querySelector('#reply-header-container .subject').classList.add('hidden');
    document.querySelector('#reply-header-container').classList.add('hidden');
    showNativeRecipientEditor();
};

var showSubjectEditor = function() {
    //document.querySelector('#reply-header-container .recipient-container').classList.add('hidden');
    //document.querySelector('#reply-header-container .subject').classList.add('hidden');
    document.querySelector('#reply-header-container').classList.add('hidden');
    showNativeSubjectEditor();
};

var loadImage = function(msg, url, filename, uniqueID, allowResize, callback) {
    var commandInfo = {'command': 'jsLoadImage', 'messageinfo': msg, 'url': url, 'filename': filename, 'uniqueID': uniqueID, 'allowResize': allowResize};
    runCommand(commandInfo, callback);
};

var loadImageElement = function(element) {
    var url = element.getAttribute('x-dejalu-original-src');
    if (url == null) {
        return;
    }
    loadImage(null, url, null, null, true, function(imageData) {
        var mimeType = imageData['mimeType'];
        var base64 = imageData['base64'];
        if (base64 != null) {
            element.src = 'data:image/png;base64,' + base64;
        }
    });;
};

var loadDraftMessage = function(rowid, callback) {
    var commandInfo = {'command': 'jsLoadDraftMessage', 'messagerowid': rowid};
    runCommand(commandInfo, callback);
};

var loadDraftAttachments = function(info, callback) {
    var commandInfo = {'command': 'jsLoadDraftAttachments', 'info': info};
    runCommand(commandInfo, callback);
};

var loadMessages = function(callback) {
    var commandInfo = {'command': 'jsLoadMessages'};
    runCommand(commandInfo, callback);
};

var objcLoadDraftMessage = function(rowid) {
    console.log('load draft message');
    loadDraftMessage(rowid, function(info) {
        if (info != null) {
            loadDraftAttachments(info);
        }
    });
};

var objcLoadDraftConversation = function(rowid, folderid) {
    loadMessages(function(messages) {
        var found = null;
        messages.forEach(function(msg) {
            if (msg.folderid == folderid) {
                if (found == null) {
                    found = msg;
                }
            }
            if (found == null) {
                console.log('no draft found');
                return;
            }
            loadDraftMessage(found.rowid, function(info) {
                if (info != null) {
                    loadDraftAttachments(info);
                }
            });
        });
    });
};

var objcLoadHTMLBody = function(html, baseURL) {
    var fixedHTML = fixHTMLFormatting(html, baseURL, {}, false);
    var editorNode = document.querySelector('#editor');
    var node = getNodeHTML(html);
    editorNode.insertBefore(editorNode.firstChild, node);
};

var loadContentAttachments = function(info, node) {
    loadContentImageAttachments(info, node);
    loadContentOtherAttachments(info, node);
};

var loadContentImageAttachments = function(info, node) {
    //var messageNode = this.element;
    //var contentNode = messageNode.querySelector('.content');

    replaceImageAttachments(info, node);
    replaceEmbeddedImages(info, node);

    var imagesTemplate = document.querySelector('#images-container-template > .images-container');
    var imagesNode = imagesTemplate.cloneNode(true);
    var imageTemplate = document.querySelector('#image-container-template > .image-container');

    var attachments = info['image-attachments'];
    if (attachments.length == 0) {
        return;
    }
    attachments.forEach(function(attachmentInfo) {
        var imageNode = imageTemplate.cloneNode(true);
        imageNode.querySelector('.attachment-name').textContent = attachmentInfo.filename;
        imageNode.id = 'attachment-' + info.rowid + '-' + attachmentInfo.uniqueID;
        imageNode.querySelector('img').originalUrl = 'x-mailcore-image:' + attachmentInfo.uniqueID;
        imagesNode.appendChild(imageNode);
    }.bind(this));
    node.appendChild(imagesNode);
};

var loadContentOtherAttachments = function(info, node) {
    //var messageNode = this.element;
    //var contentNode = messageNode.querySelector('.content');

    replaceAttachments(info, node);

    var attachmentsTemplate = document.querySelector('#attachments-container-template > .attachments-container');
    var attachmentsNode = attachmentsTemplate.cloneNode(true);
    var attachmentTemplate = document.querySelector('#attachment-container-template > .attachment-container');

    var attachments = info['other-attachments'];
    if (attachments.length == 0) {
        return;
    }
    attachments.forEach(function(attachmentInfo) {
        var attachmentNode = attachmentTemplate.cloneNode(true);
        attachmentNode.querySelector('.attachment-name').textContent = attachmentInfo.filename;
        attachmentNode.id = 'attachment-' + info.rowid + '-' + attachmentInfo.uniqueID;
        attachmentNode.querySelector('img').originalUrl = 'x-dejalu-icon:' + attachmentInfo.filenameext;
        attachmentsNode.appendChild(attachmentNode);
    }.bind(this));
    node.appendChild(attachmentsNode);
};

var replaceImageAttachments = function(info, node) {
    /*
    //var messageNode = this.element;
    //var contentNode = messageNode.querySelector('.content');

    var imageTemplate = document.querySelector('#image-container-template > .image-container');

    var images = node.querySelectorAll('img.-dejalu-image-attachment');
    var idx;
    for(idx = 0 ; idx < images.length ; idx ++) {
    var img = images[idx];
    var filename = img.getAttribute('x-dejalu-filename');
    var uniqueID = img.getAttribute('x-dejalu-unique-id');
    var imageNode = imageTemplate.cloneNode(true);
    imageNode.querySelector('img').originalUrl = img.src;
    imageNode.id = 'attachment-' + this.rowid + '-' + uniqueID;
    imageNode.querySelector('.attachment-name').innerText = filename;
    var parentNode = img.parentNode;
    parentNode.insertBefore(imageNode, img.nextSibling);
    parentNode.removeChild(img);
    }
    */
};

var replaceEmbeddedImages = function(info, node) {
    //var messageNode = this.element;
    //var contentNode = messageNode.querySelector('.content');

    var imageTemplate = document.querySelector('#embedded-image-container-template > .embedded-image-container');

    //var images = node.getElementsByClassName('-dejalu-image');
    var images = node.querySelectorAll('img.-dejalu-image');
    var idx;
    /*
    var cidURLs = [];
    for(idx = 0 ; idx < images.length ; idx ++) {
    var img = images[idx];
    var url = img.src;
    if (url == null) {
    url = img.getAttribute('src');
    }
    if (url.indexOf('cid:') == 0) {
    cidURLs.push(img.src);
    }
    }
    */
    for(idx = 0 ; idx < images.length ; idx ++) {
        var img = images[idx];
        var url = img.src;
        if (url == null) {
            url = img.getAttribute('src');
        }
        if (url.indexOf('cid:') != 0) {
            continue;
        }
        var imageNode = imageTemplate.cloneNode(true);
        console.log(imageNode.querySelector('img'));
        console.log(img.src);
        imageNode.querySelector('img').setAttribute('x-dejalu-original-src', img.src);
        imageNode.querySelector('img').originalUrl = img.src;
        var basicInfo = info['cid-mapping'][img.src];
        if (basicInfo != null) {
            var uniqueID = basicInfo.uniqueID;
            var filename = basicInfo.filename;
            imageNode.id = 'attachment-' + this.rowid + '-' + uniqueID;
            imageNode.querySelector('.attachment-name').textContent = filename;
        }
        var parentNode = img.parentNode;
        parentNode.insertBefore(imageNode, img.nextSibling);
        parentNode.removeChild(img);
        if ((img.height != 0) && (img.width != 0)) {
            if ((img.width > 580) || (img.height > 400)) {
                imageNode.querySelector('img').classList.add('bigger');
            }
            else {
                imageNode.querySelector('img').width = img.width;
                imageNode.querySelector('img').height = img.height;
            }
        }
    }
};

var replaceAttachments = function(info, node) {
    /*
    //var messageNode = this.element;
    //var contentNode = messageNode.querySelector('.content');

    var attachmentTemplate = document.querySelector('#attachment-container-template > .attachment-container');

    var images = node.querySelectorAll('img.-dejalu-attachment');
    var idx;
    for(idx = 0 ; idx < images.length ; idx ++) {
    var img = images[idx];
    var filename = img.getAttribute('x-dejalu-filename');
    var uniqueID = img.getAttribute('x-dejalu-unique-id');
    var attachmentNode = attachmentTemplate.cloneNode(true);
    attachmentNode.querySelector('img').originalUrl = img.src;
    attachmentNode.id = 'attachment-' + this.rowid + '-' + uniqueID;
    attachmentNode.querySelector('.attachment-name').innerText = filename;
    var parentNode = img.parentNode;
    parentNode.insertBefore(attachmentNode, img.nextSibling);
    parentNode.removeChild(img);
    }
    */
};

var imageElements = function(contentNode) {
    var imageNodes = contentNode.getElementsByTagName('img');
    return [].slice.call(imageNodes);
};

var findCIDImageURL = function(contentNode) {
    var images = imageElements(contentNode);
    console.log(contentNode);
    console.log(images);
    var resultImages = [];

    var imgLinks = [];
    for (var i = 0; i < images.length; i++) {
        var url = images[i].originalUrl;
        if (url == null) {
            url = images[i].getAttribute('src');
        }
        if (url != null) {
            if (url.indexOf('cid:') == 0 || url.indexOf('x-mailcore-image:') == 0 || url.indexOf('x-dejalu-icon:') == 0) {
                imgLinks.push(url);
                resultImages.push(images[i]);
            }
        }
    }
    console.log(imgLinks);
    return {'urls': imgLinks, 'images': resultImages};
}

var loadImages = function() {
    var contentNode = document.querySelector('#editor');
    loadImagesInNode(contentNode);
    var contentNode = document.querySelector('#replied-text .content');
    loadImagesInNode(contentNode);
}

var loadImagesInNode = function(contentNode) {
    //console.log("load images " + contentNode.innerHTML);
    var imagesUrls = findCIDImageURL(contentNode);
    var images = imagesUrls['images'];
    var urls = imagesUrls['urls'];
    urls.forEach(function(url, idx) {
        var filename = images[idx].getAttribute('x-dejalu-filename');
        var uniqueID = images[idx].getAttribute('x-dejalu-unique-id');
        var allowResize = (url.indexOf('cid:') != 0);
                 
        var img = images[idx];
        var imageWrapper = img.parentNode;
        if (!imageWrapper.classList.contains('image-wrapper')) {
            img.style.opacity = 0;
        }
                 
        loadImage(null, url, filename, uniqueID, allowResize, function(imageData) {
            var mimeType = imageData['mimeType'];
            var base64 = imageData['base64'];
            var img = images[idx];
            if (base64 != null) {
                img.src = 'data:image/png;base64,' + base64;
                if (imageData.height > imageData.width) {
                    img.classList.add('portrait');
                }
                else {
                    img.classList.add('landscape');
                }
                if (imageData.height < 185) {
                    img.classList.add('smaller-height');
                }
            }
            var imageWrapper = img.parentNode;
            if (imageWrapper.classList.contains('image-wrapper')) {
                var containerNode = imageWrapper;
                while (!containerNode.classList.contains('container')) {
                    containerNode = containerNode.parentNode;
                }
                if (base64 != null) {
                    containerNode.classList.remove('loading');
                }
                if (containerNode.classList.contains('embedded-image-container')) {
                    console.log('resize? ' + img.style.width + ' ' + img.style.height + '|' + img.height + ' ' + img.width);
                    if ((img.height == 0) || (img.width == 0)) {
                        console.log('image data: ' + imageData.width + ' ' + imageData.height);
                        if ((imageData.width > 580) || (imageData.height > 400)) {
                            img.classList.add('bigger');
                        }
                        else {
                            img.width = imageData.width;
                            img.height = imageData.height;
                        }
                    }
                    else {
                        console.log('has size: ' + imageData.width + ' ' + imageData.height);
                        if ((img.width > 580) || (img.height > 400)) {
                            img.classList.add('bigger');
                        }
                    }
                }
            }
            else {
                img.style.opacity = 1;
            }
        }.bind(this));
    }.bind(this));
};

var highlightedNodes = null;
var searchResultIndex = -1;
var currentMatches = null;
var currentSearchString = null;

var objcHighlightSearchResult = function(searchString) {
    clearSearchResult();
    if (searchString == null) {
        return;
    }
    if (searchString.length == 0) {
        return;
    }
    var contentNode = document.querySelector('#editor');
    highlightedNodes = highlightWord(contentNode, searchString);

    currentMatches = [];
    highlightedNodes.forEach(function(containerNode) {
        var nodeList = containerNode.querySelectorAll('.-dejalu-highlighted');
        currentMatches = currentMatches.concat([].slice.call(nodeList));
    });
    searchResultIndex = -1;
    for(var i = 0 ; i < currentMatches.length ; i ++) {
        var node = currentMatches[i];
        var rect = getAbsoluteRect(node);
        if (rect.y > 0) {
            searchResultIndex = i;
            break;
        }
    }

    if (searchResultIndex == -1) {
        if (currentMatches.length > 0) {
            searchResultIndex = 0;
        }
    }

    document.querySelector('#editor').classList.add('search-result');
    focusSearchResult(false);
}

var clearSearchResult = function() {
    if (highlightedNodes == null) {
        return;
    }
    highlightedNodes.forEach(function(node) {
        var textNode = document.createTextNode(node.originalString);
        node.parentNode.replaceChild(textNode, node);
    }.bind(this));
    highlightedNodes = null;
    document.querySelector('#editor').classList.remove('search-result');
};

var objcClearSearchResult = function() {
    objcHighlightSearchResult('');
};

var objcFocusNextSearchResult = function() {
    if (searchResultIndex == -1) {
        return;
    }

    var node = currentMatches[this.searchResultIndex];
    node.classList.remove('-dejalu-search-result-focus');

    searchResultIndex ++;
    if (searchResultIndex >= currentMatches.length) {
        searchResultIndex = 0;
    }

    focusSearchResult(false);
};

var objcFocusPreviousSearchResult = function() {
    if (searchResultIndex == -1) {
        return;
    }

    var node = currentMatches[searchResultIndex];
    node.classList.remove('-dejalu-search-result-focus');

    searchResultIndex --;
    if (searchResultIndex < 0) {
        searchResultIndex = currentMatches.length - 1;
    }

    focusSearchResult(false);
};

var focusSearchResult = function(goUp) {
    if (searchResultIndex == -1) {
        return;
    }
    var node = currentMatches[searchResultIndex];
    node.classList.add('-dejalu-search-result-focus');
    node.scrollIntoView(goUp);

    var range = document.createRange();
    range.selectNodeContents(node);
    window.getSelection().removeAllRanges();
    window.getSelection().addRange(range);
};

var objcHideStaticRecipient = function() {
    document.querySelector('#reply-header-container').classList.add('hidden');
};

var objcAddGiphyImage = function(url, width, height) {
    var range = getCurrentRange();
    if (range == null) {
        objcFocus();
        range = getCurrentRange();
    }

    var divNode = document.createElement("div");
    var imgNode = document.createElement("img");
    imgNode.src = url;
    imgNode.width = width;
    imgNode.height = height;
    divNode.appendChild(imgNode);
    var brNode = document.createElement("br");
    divNode.appendChild(brNode);
    brNode = document.createElement("br");
    divNode.appendChild(brNode);
    brNode = document.createElement("br");
    divNode.appendChild(brNode);
    range.insertNode(divNode);

    var range = document.createRange();
    range.selectNodeContents(divNode);
    range.collapse(false);
    window.getSelection().removeAllRanges();
    window.getSelection().addRange(range);

    divNode.scrollIntoView();
};

var setup = function() {
    document.addEventListener('selectionchange', function(e) {
        selectionChangeHandler();
    });

    document.querySelector('#reply-header-container .recipient-container').addEventListener('dblclick', function(e) {
        showRecipientEditor();
    });
    document.querySelector('#reply-header-container .subject').addEventListener('dblclick', function(e) {
        showSubjectEditor();
    });
    document.querySelector('#reply-header-container .edit-button').addEventListener('click', function(e) {
        showRecipientEditor();
    });
    document.querySelector('#reply-container').addEventListener('click', function (evt) {
        if (evt.detail != 3) {
            return;
        }
        objcEditAllContent();
    });
    document.addEventListener("DOMNodeInserted", function(e) {
        // Notify of change!
        //console.warn("change!", e);
        var element = e.srcElement;
        if (element.tagName == 'IMG') {
            loadImageElement(element);
        }
        if (element.tagName == 'A') {
            if (element.firstChild == null) {
                element.innerText = element.href;
            }
        }
    });
};

document.addEventListener("DOMContentLoaded", function(event) {
    setup();
});

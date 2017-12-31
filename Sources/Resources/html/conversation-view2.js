// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

var s_mainConversation = null;
var s_debugEnabled = false;

var Conversation = function() {
    this.containerNode = document.querySelector('#messages');
    this.subjectContainerNode = document.querySelector('#subject-container');
    this.moreMessagesNode = document.querySelector('#more-messages');
    this.updateButton = document.querySelector('#update-button');

    this.moreMessagesNode.addEventListener('click', function(e) {
        this.expandMessages();
        cancelEvent(e);
    }.bind(this));

    this.subjectContainerNode.querySelector('.subject .conversation-has-attachment').addEventListener('click', function(e) {
        this.saveAllAttachments();
        cancelEvent(e);
    }.bind(this));

    this.subjectContainerNode.querySelector('.subject .conversation-reply').addEventListener('click', function(e) {
        this.replyCurrentMessage();
        closeWindow();
        cancelEvent(e);
    }.bind(this));

    this.updateButton.addEventListener('click', function(e) {
        this.updateConversation();
        this.hideUpdateButton();
        cancelEvent(e);
    }.bind(this));

    this.reset();
};

Conversation.sharedInstance = function() {
    if (s_mainConversation == null) {
        s_mainConversation = new Conversation();
    }
    return s_mainConversation;
};

Conversation.prototype.reset = function() {
    this.messages = [];
    this.messagesHash = {};
    this.maxMessageUnread = 0;
    this.currentMessageToLoad = 0;
    this.batchLoadCount = 0;
    this.containerNode.innerHTML = '';
    this.hideNodesWhileLoading = false;
    this.conversationInfo = null;
    this.finishedLoading = false;
    this.notifyingConversationUpdates = false;
    this.hasPendingConversationUpdates = false;
    this.contentCached = {};
    this.selectedMessage = null;
    this.searchResultIndex = -1;
    this.currentMatches = null;
    this.currentSearchString = null;

    if (this.markAsReadTimer != null) {
        clearTimeout(this.markAsReadTimer);
        this.markAsReadTimer = null;
    }

    this.subjectContainerNode.querySelector('.subject .subject-text').textContent = '';
    this.subjectContainerNode.querySelector('.recipient').textContent = '';
    this.subjectContainerNode.querySelector('.recipient').classList.add('hidden');
    this.subjectContainerNode.querySelector('.subject .conversation-has-attachment').classList.add('hidden');
    this.moreMessagesNode.classList.add('hidden');
    this.moreMessagesNode.classList.remove('temporary-hidden');
    this.hideUpdateButton();
};

Conversation.prototype.setInfo = function(info) {
    // date, timestamp, unread, starred, messages -> (id, folder, snippet, subject, sender),
    // sender-md5, sender, single-recipient, recipients, senders, recipients-md5, listid,
    // notification

    this.reset();
    this.conversationInfo = info;
    var subject = info.subject;
    if ((subject == null) || (subject == '')) {
        subject = 'No subject';
    }
    this.subjectContainerNode.querySelector('.subject .subject-text').textContent = subject;
    var recipientStr = this.recipientString();
    if (recipientStr != null) {
        this.subjectContainerNode.querySelector('.recipient').classList.remove('hidden');
        this.subjectContainerNode.querySelector('.recipient').textContent = recipientStr;
    }
    else {
        this.subjectContainerNode.querySelector('.recipient').classList.add('hidden');
    }
    if (this.conversationInfo.hasattachment) {
        this.subjectContainerNode.querySelector('.subject .conversation-has-attachment').classList.remove('hidden');
    }

    this.loadMessages();
};

Conversation.prototype.notifyConversationUpdates = function() {
    if (this.notifyingConversationUpdates) {
        this.hasPendingConversationUpdates = true;
        return;
    }

    this.notifyingConversationUpdates = true;

    loadMessages(function(messages) {
        //var hasNewMessages = false;
        var existingMsgID = {};
        this.addedMessages = [];
        this.messages.forEach(function(msg) {
            existingMsgID[msg.msgid] = msg;
        });
        messages.forEach(function(info) {
            var msg = existingMsgID[info.msgid];
            if (msg == null) {
                msg = new Message();
                msg.initWithInfo(info);
                this.addedMessages.push(msg);
                //hasNewMessages = true;
            }
        }.bind(this));

        this.addedMessageIndex = 0;
        this.loadNextAddedMessage();
    }.bind(this));
};

Conversation.prototype.loadNextAddedMessage = function() {
    if (this.hasPendingConversationUpdates) {
        this.loadNextAddedMessagesDone();
        return;
    }
    if (this.addedMessageIndex >= this.addedMessages.length) {
        this.loadNextAddedMessagesDone();
        return;
    }
    var msg = this.addedMessages[this.addedMessageIndex];
    msg.loadMessage(function() {
        this.addedMessageIndex ++;
        this.loadNextAddedMessage();
    }.bind(this));
};

Conversation.prototype.loadNextAddedMessagesDone = function() {
    if (this.hasPendingConversationUpdates) {
        this.notifyingConversationUpdates = false;
        this.hasPendingConversationUpdates = false;
        this.notifyConversationUpdates();
    }

    if (this.addedMessages.length > 0) {
        var shouldNotify = false;
        this.addedMessages.forEach(function(msg) {
                                   if (!msg.me && msg.unread) {
                                   shouldNotify = true;
                                   }
                                   });
        if (shouldNotify) {
            this.showUpdateButton();
        }
        else {
            this.updateConversation();
        }
    }

    this.notifyingConversationUpdates = false;
};

Conversation.prototype.showUpdateButton = function() {
    this.updateButton.classList.remove('hidden');
};

Conversation.prototype.hideUpdateButton = function() {
    this.updateButton.classList.add('hidden');
};

Conversation.prototype.updateConversation = function() {
    var existingMessagesHash = this.messagesHash;
    var existingMessages = this.messages;

    loadMessages(function(messages) {
        this.messages = [];
        this.messagesHash = {};
        var updatedMessagesHash = {};
        var messageToDelete = [];

        messages.forEach(function(info, idx) {
            updatedMessagesHash[info.rowid] = info;
        });

        existingMessages.forEach(function(msg) {
            if (updatedMessagesHash[msg.rowid] == null) {
                messageToDelete.push(msg);
            }
        });

        messageToDelete.forEach(function(msg) {
            msg.element.parentNode.removeChild(msg.element);
        });

        this.maxMessageUnread = 0;
        messages.forEach(function(info, idx) {
            oldMsg = existingMessagesHash[info.rowid];
            if (oldMsg != null) {
                this.messages.push(oldMsg);
                this.messagesHash[oldMsg.rowid] = oldMsg;
                return;
            }
            var message = new Message();
            message.initWithInfo(info);
            // rowid, unread, starred, uid, folderid, msg, date
            message.markedAsRead = false;
            if (message.unread) {
                this.maxMessageUnread = idx;
            }
            this.messages.push(message);
            this.messagesHash[message.rowid] = message;
        }.bind(this));

        this.maxMessageUnread ++;
        this.finishedLoading = false;
        this.currentMessageToLoad = 0;
        this.renderingDisabled = false;
        this.finishedLoadingCallback = null;
        this.loadNextMessage();
    }.bind(this));
};

Conversation.prototype.recipientString = function() {
    var senders = this.conversationInfo.recipients;
    var sendersString = '';
    var listid = conversationInfo.listid;
    if (listid != null) {
        // don't show conversation recipient.
        return null;
    }
    else {
        if (senders.length <= 2) {
            // don't show conversation recipient.
            return null;
        }
        if (senders != null) {
            senders.forEach(function(sender, idx) {
                if (idx != 0) {
                    sendersString += ', ';
                }
                sendersString += sender;
            });
        }
    }
    return sendersString;
};

Conversation.prototype.replyCurrentMessage = function() {
    if (this.messages.length == 0) {
        return;
    }

    var msg = this.messages[0];
    if (this.selectedMessage != null) {
        msg = this.selectedMessage;
    }
    msg.reply();
};

Conversation.prototype.forwardCurrentMessage = function() {
    if (this.messages.length == 0) {
        return;
    }

    var msg = this.messages[0];
    if (this.selectedMessage != null) {
        msg = this.selectedMessage;
    }
    msg.forward();
};

Conversation.prototype.editCurrentDraftMessage = function() {
    if (this.messages.length == 0) {
        return;
    }

    var msg = this.messages[0];
    if (this.selectedMessage != null) {
        msg = this.selectedMessage;
    }
    msg.editDraftMessage();
};

Conversation.prototype.loadMessages = function() {
    loadMessages(function(messages) {
        this.messages = [];
        this.messagesHash = {}
        this.maxMessageUnread = 0;
        messages.forEach(function(info, idx) {
            var message = new Message();
            // rowid, unread, starred, uid, folderid, msg, date
            for(var attrname in info) {
                message[attrname] = info[attrname];
            }
            message.markedAsRead = false;
            if (message.unread) {
                this.maxMessageUnread = idx;
            }
            this.messages.push(message);
            this.messagesHash[message.rowid] = message;
        }.bind(this));
        this.maxMessageUnread ++;
        this.currentMessageToLoad = 0;
        this.renderingDisabled = false;
        this.finishedLoadingCallback = function() {
            this.precacheMessages(function() {
                console.log('precache done');
            }.bind(this));
        };
        this.loadNextMessage();
        //console.log(this);
    }.bind(this));
};

Conversation.prototype.loadNextMessage = function() {
    var message = null;
    while (true) {
        if (!this.renderingDisabled) {
            if ((this.currentMessageToLoad >= this.messages.length) || (this.currentMessageToLoad > this.maxMessageUnread)) {
                console.log('finished loading, render');
                this.batchLoadCount = 0;
                this.renderMessages();
                this.finishedLoadingMessages();
                return;
            }
            else if (this.batchLoadCount == 5) {
                this.batchLoadCount = 0
                this.renderMessages();
            }
        }
        else {
            if ((this.currentMessageToLoad >= this.messages.length) || (this.currentMessageToLoad > this.maxMessageUnread)) {
                this.finishedLoadingMessages();
                return;
            }
        }

        message = this.messages[this.currentMessageToLoad];
        if (!message.infoLoaded) {
            break;
        }
        this.currentMessageToLoad ++;
    }
    console.log('load next msg ' + this.currentMessageToLoad);
    console.log(message);
    message.loadMessage(function() {
        this.currentMessageToLoad ++;
        this.batchLoadCount ++;
        this.loadNextMessage();
    }.bind(this));
};

Conversation.prototype.renderMessages = function() {
    for(var idx = 0 ; idx < this.messages.length ; idx ++) {
        var message = this.messages[idx];
        if (!message.infoLoaded) {
            break;
        }
        if (message.addedToDOM) {
            continue;
        }

        var isOlderMessage = (idx == this.messages.length - 1);
        var isMostRecent = (idx == 0);
        var previousMessageElement = null;
        if (idx > 0) {
            previousMessageElement = this.messages[idx - 1].element;
        }
        message.addMessageElement(this.containerNode, previousMessageElement, isOlderMessage, isMostRecent, this.hideNodesWhileLoading);
        message.addedToDOM = true;
    }

    console.log('rendered: ' + this.currentMessageToLoad + ' ' + this.messages.length);
};

Conversation.prototype.finishedLoadingMessages = function() {
    if (!this.renderingDisabled) {
        if (this.hideNodesWhileLoading) {
            this.hideNodesWhileLoading = false;
            this.showHiddenNodes();
        }
        var hasUnrenderedMessages = false;
        for(var idx = 0 ; idx < this.messages.length ; idx ++) {
            var message = this.messages[idx];
            if (message.element == null) {
                hasUnrenderedMessages = true;
            }
        }
        if (hasUnrenderedMessages) {
            this.moreMessagesNode.classList.remove('hidden');
        }
        else {
            this.moreMessagesNode.classList.add('hidden');
        }
        this.moreMessagesNode.classList.remove('temporary-hidden');
        this.finishedLoading = true;
        this.trySetupMarkAsReadTimer();
    }
    else {
        this.finishedLoading = true;
    }
    if (this.finishedLoadingCallback != null) {
        this.finishedLoadingCallback();
    }
};

Conversation.prototype.trySetupMarkAsReadTimer = function() {
    console.log('try mark timer');
    if (!this.finishedLoading) {
        console.log('try mark timer - not finished');
        return;
    }
    if (!this.allMessagesLoaded()) {
        console.log('try mark timer - not loaded');
        return;
    }
    var height = this.subjectContainerNode.offsetHeight;
    this.messages.forEach(function(msg) {
        if (msg.addedToDOM) {
            height += msg.element.offsetHeight;
        }
    });

    if (this.markAsReadTimer != null) {
        clearTimeout(this.markAsReadTimer);
        this.markAsReadTimer = null;
    }
    this.markAsReadTimer = setTimeout(function() {
        this.markAsReadTimer = null;
        this.markAsReadVisibleMessages();
    }.bind(this), 2000);
};

Conversation.prototype.allMessagesLoaded = function() {
    var loaded = true;
    this.messages.forEach(function(msg) {
        if (msg.addedToDOM && !msg.contentLoaded) {
            loaded = false;
        }
    });
    return loaded;
};

Conversation.prototype.markAsReadVisibleMessages = function() {
    this.messages.forEach(function(msg) {
        if (msg.addedToDOM) {
            msg.markAsRead();
        }
    });
};

Conversation.prototype.scrolled = function() {
    this.markAsReadVisibleMessages();
};

Conversation.prototype.showHiddenNodes = function() {
    this.messages.forEach(function(msg) {
        if (msg.hidden) {
            msg.element.classList.remove('hidden');
            msg.hidden = false;
        }
    });
};

Conversation.prototype.loadImagesForMessageWithRowID = function(rowid) {
    var msg = this.messagesHash[rowid];
    if (msg == null) {
        return;
    }
    msg.loadImages();
};

Conversation.prototype.loadContentForMessageWithRowID = function(rowid) {
    var msg = this.messagesHash[rowid];
    if (msg == null) {
        return;
    }
    if (msg.contentLoaded) {
        return;
    }
    var idx = this.messages.indexOf(msg);
    var isOlderMessage = (idx == this.messages.length - 1);
    var isMostRecent = (idx == 0);
    msg.loadMessage(function() {
        msg.loadMessageContent(isOlderMessage, isMostRecent, false);
    }.bind(this))
};

Conversation.prototype.getCachedContent = function(msgid) {
    return this.contentCached[msgid];
};

Conversation.prototype.setCachedContent = function(msgid, content) {
    this.contentCached[msgid] = content;
};

Conversation.prototype.deselectAttachments = function() {
    this.messages.forEach(function(msg) {
        msg.deselectAttachments();
    }.bind(this));
};

Conversation.prototype.selectedAttachment = function() {
    var result = null;
    this.messages.forEach(function(msg) {
        var currentResult = msg.selectedAttachment();
        if (currentResult != null) {
            result = currentResult;
        }
    }.bind(this));
    return result;
};

Conversation.prototype.quickLookAttachment = function() {
    var selectedAttachment = this.selectedAttachment();
    var allAttachments = [];
    var selectedIndex = -1;
    this.messages.forEach(function(msg) {
        if (msg.element == null) {
            return;
        }
        msg.allAttachments().forEach(function(attachmentInfo) {
            var attachmentElement = msg.element.querySelector('#attachment-' + attachmentInfo.rowid + '-' + attachmentInfo.uniqueID);
            if (attachmentElement == null) {
                return;
            }
            var rect = getAbsoluteRect(attachmentElement);
            attachmentInfo["rect"] = rect;
            attachmentInfo.sender = msg.sender;
            if ((selectedAttachment.rowid == attachmentInfo.rowid) && (selectedAttachment.uniqueID == attachmentInfo.uniqueID)) {
                selectedIndex = allAttachments.length;
            }
            allAttachments.push(attachmentInfo);
        }.bind(this));
    }.bind(this));

    console.log(allAttachments);
    console.log('selected: ' + selectedIndex);
    //var element = document.querySelector('#attachment-' + attachment.rowid + '-' + attachment.uniqueID);
    //var rect = getAbsoluteRect(element);
    quickLookAttachment(selectedIndex, allAttachments);
};

Conversation.prototype.saveAllAttachments = function() {
    /*
    console.log('save all attachments');
    this.precacheMessages(function() {
    console.log('save all attachments step 2');
    var hasAttachment = false;
    this.messages.forEach(function(msg) {
    console.log('save all attachments for msg ' + msg.rowid);
    if (msg.saveAllAttachments()) {
    hasAttachment = true;
    }
    }.bind(this));
    if (hasAttachment) {
    openTemporaryFolder();
    }
    }.bind(this));
    */
    this.precacheMessages(function() {
        var allAttachments = [];
        this.messages.forEach(function(msg) {
            msg.allAttachments().forEach(function(attachmentInfo) {
                allAttachments.push(attachmentInfo);
            }.bind(this));
        }.bind(this));
        saveAllAttachments(this.conversationInfo.subject, allAttachments);
    }.bind(this));
};

Conversation.prototype.precacheMessages = function(callback) {
    console.log('precaching');
    this.maxMessageUnread = this.messages.length;
    this.hideNodesWhileLoading = true;
    this.finishedLoading = false;
    this.currentMessageToLoad = 0;
    this.renderingDisabled = true;
    this.finishedLoadingCallback = callback;
    this.loadNextMessage();
};

Conversation.prototype.expandMessages = function(callback) {
    this.moreMessagesNode.classList.add('temporary-hidden');

    for(var i = 0 ; i <= this.maxMessageUnread ; i ++) {
        if (i >= this.messages.length) {
            continue;
        }

        var msg = this.messages[i];
        msg.expandMessageNode();
    }
    for(var i = 0 ; i < this.messages.length ; i ++) {
        this.messages[i].forceExpanded = 1;
    }
    this.maxMessageUnread = this.messages.length;
    this.hideNodesWhileLoading = true;
    this.finishedLoading = false;
    this.currentMessageToLoad = 0;
    this.renderingDisabled = false;
    this.finishedLoadingCallback = callback;
    this.loadNextMessage();
};

Conversation.prototype.openSelectedAttachment = function() {
    var attachment = this.selectedAttachment();
    if (attachment == null) {
        console.log('no attachment');
        return;
    }
    openAttachment(attachment.folderid, attachment.rowid, attachment.uniqueID);
};

Conversation.prototype.setSelectedMessage = function(message) {
    this.selectedMessage = message;
};

Conversation.prototype.highlightSearchResult = function(searchString) {
    this.currentSearchString = searchString;
    this.currentMatches = [];
    this.expandMessages(function() {
        this.messages.forEach(function(msg) {
            msg.highlightSearchResult(searchString);
            if (msg.highlightedNodes != null) {
                msg.highlightedNodes.forEach(function(containerNode) {
                    var nodeList = containerNode.querySelectorAll('.-dejalu-highlighted');
                    this.currentMatches = this.currentMatches.concat([].slice.call(nodeList));
                }.bind(this));
            }
        }.bind(this));
    }.bind(this));
    this.searchResultIndex = -1;
    for(var i = 0 ; i < this.currentMatches.length ; i ++) {
        var node = this.currentMatches[i];
        var rect = getAbsoluteRect(node);
        if (rect.y > 0) {
            this.searchResultIndex = i;
            break;
        }
    }

    if (this.searchResultIndex == -1) {
        if (this.currentMatches.length > 0) {
            this.searchResultIndex = 0;
        }
    }
    console.log(this.currentMatches);

    this.focusSearchResult(false);
};

Conversation.prototype.focusNextSearchResult = function() {
    if (this.searchResultIndex == -1) {
        return;
    }

    var node = this.currentMatches[this.searchResultIndex];
    node.classList.remove('-dejalu-search-result-focus');

    this.searchResultIndex ++;
    if (this.searchResultIndex >= this.currentMatches.length) {
        this.searchResultIndex = 0;
    }

    this.focusSearchResult(false);
};

Conversation.prototype.focusPreviousSearchResult = function() {
    if (this.searchResultIndex == -1) {
        return;
    }

    var node = this.currentMatches[this.searchResultIndex];
    node.classList.remove('-dejalu-search-result-focus');

    this.searchResultIndex --;
    if (this.searchResultIndex < 0) {
        this.searchResultIndex = this.currentMatches.length - 1;
    }

    this.focusSearchResult(false);
};

Conversation.prototype.focusSearchResult = function(goUp) {
    if (this.searchResultIndex == -1) {
        return;
    }
    var node = this.currentMatches[this.searchResultIndex];
    node.classList.add('-dejalu-search-result-focus');
    node.scrollIntoView(goUp);
};

Conversation.prototype.clearSearchResult = function() {
    this.messages.forEach(function(msg) {
        msg.clearSearchResult();
    }.bind(this));
};

Conversation.prototype.deselectContextMenu = function() {
    var nodes = document.querySelectorAll('.context-menu-selected');
    nodes = [].slice.call(nodes);
    nodes.forEach(function(node) {
        node.classList.remove('context-menu-selected');
    }.bind(this));
};

Conversation.prototype.showOriginalFormatForContextMenuMessage = function() {
    var node = document.querySelector('.context-menu-selected');
    this.messages.forEach(function(msg) {
        if (msg.element == node) {
            msg.showUncollapsedMessage();
        }
    }.bind(this));
};

Conversation.prototype.showSourceForContextMenuMessage = function() {
    var node = document.querySelector('.context-menu-selected');
    this.messages.forEach(function(msg) {
        if (msg.element == node) {
            showMessageSource(msg.folderid, msg.rowid);
        }
    }.bind(this));
};

Conversation.prototype.htmlForSelectedMessage = function() {
    var msg = this.messages[0];
    if (this.selectedMessage != null) {
        msg = this.selectedMessage;
    }
    if (msg.element == null) {
        return '';
    }
    return msg.element.outerHTML;
};

Conversation.prototype.htmlForHeader = function() {
    return document.querySelector('#subject-container').innerHTML;
};

// ### Message ###

var Message = function() {
    // rowid, unread, starred, uid, folderid, msg, date, msgid,
    // subject, me, sender, date, content, msg,
    // header-date, header-from, header-to, header-cc, header-bcc, recipients, recipients-md5, listid
    // infoLoaded, contentLoaded
    this.infoLoaded = false;
    this.collapsed = false;
    this.markedAsRead = false;
    this.addedToDOM = false;
    this.hidden = false;
    this.contentLoaded = false;
    this.forceExpanded = false;
};

Message.prototype.initWithInfo = function(info) {
    for(var attrname in info) {
        this[attrname] = info[attrname];
    }
};

Message.prototype.reply = function() {
    replyMessage(this);
};

Message.prototype.forward = function() {
    forwardMessage(this);
};

Message.prototype.editDraftMessage = function() {
    console.log('edit draft: ' + this.rowid);
    editDraftMessage(this.rowid, this.folderid);
};

Message.prototype.loadMessage = function(callback) {
    loadMessage(this.rowid, this.folderid, function(messageInfo) {
        // subject, me, sender, date, content, msg,
        // header-date, header-from, header-to, header-cc, header-bcc, recipients, recipients-md5, listid
        for(var attrname in messageInfo) {
            this[attrname] = messageInfo[attrname];
        }
        this.infoLoaded = true;
        callback();
    }.bind(this));
};

Message.prototype.addMessageElement = function(containerNode, previousMessageElement, isOlderMessage, isMostRecent, hideNodesWhileLoading) {
    var messageTemplate = document.querySelector('#message-template > .message');
    var messageNode = messageTemplate.cloneNode(true);
    if (this.me) {
        messageNode.classList.add('me');
    }

    messageNode.querySelector('.debug-msg-rowid').textContent = this.rowid;

    // set initial expanded/collapsed state
    if ((this.unread == 0) && !isMostRecent && (this.starred == 0) && !this.forceExpanded) {
        messageNode.classList.add('read');
        this.collapsed = true;
        messageNode.addEventListener('click', function(e) {
            if (this.expandMessageNode()) {
                cancelEvent(e);
            }
        }.bind(this));
    }
    if (hideNodesWhileLoading) {
        messageNode.classList.add('hidden');
        this.hidden = true;
    }

    // set sender state.
    messageNode.querySelector('.sender .text').textContent = this.sender;
    var recipientString = '';
    //console.log(this);
    if (this.recipients != null) {
        this.recipients.forEach(function(recipient, idx) {
            if (idx != 0) {
                recipientString += ', ';
            }
            recipientString += recipient;
        });
    }
    if (recipientString != '') {
        messageNode.querySelector('.sender .recipient-text').textContent = ' to ' + recipientString;
    }
    if (Conversation.sharedInstance().conversationInfo['recipients-md5'] == this['recipients-md5']) {
        messageNode.querySelector('.sender .recipient-text').classList.add('hidden');
    }
    if (this.listid != null) {
        messageNode.querySelector('.sender .recipient-text').classList.add('hidden');
    }

    // set date.
    messageNode.querySelector('.date').textContent = this.date;

    // hover for sender.
    var senderNode = messageNode.querySelector('.sender');
    senderNode.addEventListener('mouseenter', function() {
        this.addHoverFeedback();
    }.bind(this));
    senderNode.addEventListener('mouseleave', function() {
        this.removeHoverFeedback();
    }.bind(this));
    // toggle for sender.
    senderNode.addEventListener('click', function(e) {
        this.toggleHeader();
        cancelEvent(e);
    }.bind(this));

    messageNode.addEventListener('mousedown', function(e) {
        if (e.mouseDownHandled) {
            return;
        }
        this.select();
    }.bind(this));

    this.element = messageNode;

    if (previousMessageElement == null) {
        containerNode.insertBefore(messageNode, containerNode.firstChild);
    }
    else {
        containerNode.insertBefore(messageNode, previousMessageElement.nextSibling);
    }

    this.loadHeader();
    this.loadMessageContent(isOlderMessage, isMostRecent, false);
    
    setTimeout(function() {
        var contentContainerNode = messageNode.querySelector('.content-container');
        contentContainerNode.classList.remove('setup');
    }, 0);
};

Message.prototype.select = function() {
    if (Conversation.sharedInstance().selectedMessage != this) {
        if (Conversation.sharedInstance().selectedMessage != null) {
            Conversation.sharedInstance().selectedMessage.element.classList.toggle('selected', false);
        }
        Conversation.sharedInstance().setSelectedMessage(this);
    }

    if (Conversation.sharedInstance().messages.length <= 1) {
        // Don't select emails if there's only one.
        return;
    }

    this.element.classList.toggle('selected', true);
};

Message.prototype.showUncollapsedMessage = function() {
    this.contentLoaded = false;
    this.element.querySelector('.content').innerHTML = '';
    this.loadMessageContent(false, false, true);
};

Message.prototype.loadHeader = function() {
    if (this['header-replyto'] != null) {
        this.addAddresses(this.element.querySelector('.headers .header-replyto'), this['header-replyto']);
    }
    else {
        this.element.querySelector('.headers .header-replyto-container').classList.add('hidden');
    }
    if (this['header-from'] != null) {
        this.addAddress(this.element.querySelector('.headers .header-from'), this['header-from']);
    }
    else {
        this.element.querySelector('.headers .header-from-container').classList.add('hidden');
    }
    if (this['header-to'] != null) {
        this.addAddresses(this.element.querySelector('.headers .header-to'), this['header-to']);
    }
    else {
        this.element.querySelector('.headers .header-to-container').classList.add('hidden');
    }
    if (this['header-cc'] != null) {
        this.addAddresses(this.element.querySelector('.headers .header-cc'), this['header-cc']);
    }
    else {
        this.element.querySelector('.headers .header-cc-container').classList.add('hidden');
    }
    if (this['header-bcc'] != null) {
        this.addAddresses(this.element.querySelector('.headers .header-bcc'), this['header-bcc']);
    }
    else {
        this.element.querySelector('.headers .header-bcc-container').classList.add('hidden');
    }
    if (this['header-date'] != null) {
        this.element.querySelector('.headers .header-date').innerText = this['header-date'];
    }
    else {
        this.element.querySelector('.headers .header-date-container').classList.add('hidden');
    }
};

Message.prototype.addAddress = function(node, address) {
    var addressTemplate = document.querySelector('#address-template > .address');
    var addressNode = addressTemplate.cloneNode(true);
    if (address['display-name'] == address['mailbox']) {
        address['display-name'] = null;
    }
    if (address['display-name'] != null) {
        addressNode.querySelector('.display-name').innerText = address['display-name'];
        addressNode.querySelector('.mailbox').innerText = '<' + address['mailbox'] + '>';
    }
    else {
        addressNode.querySelector('.display-name').innerText = address['mailbox'];
    }
    node.appendChild(addressNode);
    addressNode.addEventListener('mousedown', function(e) {
        if (e.mouseDownHandled) {
            return;
        }
        showAddressMenu(address, getAbsoluteRect(addressNode));
        e.mouseDownHandled = true;
    }.bind(this));
};

Message.prototype.addAddresses = function(node, addresses) {
    addresses.forEach(function(address) {
        this.addAddress(node, address);
    }.bind(this));
};

Message.prototype.loadMessageContent = function(isOlderMessage, isMostRecent, forceUncollapsed) {
    var messageNode = this.element;
    if (messageNode == null) {
        return;
    }
    if (this.contentLoaded) {
        return;
    }

    var isForwardedMessage = false;
    if (this['original-subject'] != null) {
        var originalSubject = this['original-subject'].toLowerCase();
        if (originalSubject.indexOf('fwd:') == 0) {
            isForwardedMessage = true;
        }
        else if (originalSubject.indexOf('fw:') == 0) {
            isForwardedMessage = true;
        }
    }

    var expanded = true;
    if ((this.unread == 0) && !isMostRecent && (this.starred == 0) && !this.forceExpanded) {
        expanded = false;
    }
    if (forceUncollapsed) {
        expanded = true;
    }

    var content = this.content;
    if (content == null) {
        content = Conversation.sharedInstance().getCachedContent(this.msgid);
    }
    else {
        Conversation.sharedInstance().setCachedContent(this.msgid, content);
    }
    if (content != null) {
        var autolinker = new Autolinker({newWindow : false,
            phone: false,
            hashtag: false,
            className: '-dejalu-autolinker',
        });
        content = autolinker.link(content);

        var node = getNodeHTML(content);
        var nodes = node.querySelectorAll('.-dejalu-needs-html-filter');
        nodes = [].slice.call(nodes);
        // cleaning html
        nodes.forEach(function(nodeForFilter) {
            if (!forceUncollapsed) {
                fixedNodeHTMLFormatting(nodeForFilter, null, {}, true, true);
                readabilityCleaning(nodeForFilter);
                if (!isOlderMessage && !isForwardedMessage) {
                    collapseMessage(nodeForFilter);
                }
                removeFirstWhitespace(nodeForFilter);
                removeLastWhitespace(nodeForFilter);
            }
        }.bind(this));

        var contentNode = messageNode.querySelector('.content');

        if (this['mixed-text-attachments'] == 0) {
            this.loadContentAttachments(node);
        }
        else {
            this.replaceImageAttachments(node);
            this.replaceAttachments(node);
        }

        contentNode.innerHTML = '';
        contentNode.appendChild(node);
        var allLinks = node.querySelectorAll('a[href]');
        allLinks = [].slice.call(allLinks);
        allLinks.forEach(function(eltNode) {
            var showLinksOnHover = false;
            if (eltNode.href.length > 0) {
                showLinksOnHover = true;
            }
            if (showLinksOnHover) {
                eltNode.addEventListener('mouseover', function() {
                    this.showLink(eltNode.href);
                }.bind(this))
                eltNode.addEventListener('mouseout', function() {
                    this.hideLink();
                }.bind(this))
            }
        }.bind(this));

        //console.log('content loaded ' + this.rowid);
        this.contentLoaded = true;

        if (!expanded) {
            var height = contentNode.offsetHeight;
            if (height > 77) {
                height = 77;
            } else {
                var footerNode = messageNode.querySelector('.content-footer');
                footerNode.classList.add('actual-size');
            }
            var contentContainerNode = messageNode.querySelector('.content-container');
            contentContainerNode.style.height = height + 'px';
        }
        else {
            //console.log('expanded');
        }
        var tableNode = contentNode.querySelector('table');
        if (tableNode != null) {
            var width = tableNode.offsetWidth;
            if (width > 580) {
                messageNode.classList.add('larger');
            }
        }

        this.setupAttachmentEventHandler();

        this.loadImages();
        Conversation.sharedInstance().trySetupMarkAsReadTimer();
    }
    else {
        var placeholderTemplate = document.querySelector('#message-not-loaded-template > .message-placeholder');
        var node = placeholderTemplate.cloneNode(true);

        var contentNode = messageNode.querySelector('.content');
        contentNode.innerHTML = '';
        contentNode.appendChild(node);
    }
};

Message.prototype.showLink = function(url) {
    if (url.indexOf('http://') == 0) {
        url = url.substring(7);
    }
    else if (url.indexOf('https://') == 0) {
        url = url.substring(8);
    }
    var linkNode = document.querySelector('#link');
    linkNode.textContent = url;
    linkNode.classList.remove('hidden');
};

Message.prototype.hideLink = function(url) {
    var linkNode = document.querySelector('#link');
    linkNode.classList.add('hidden');
};

Message.prototype.setupAttachmentEventHandler = function() {
    var messageNode = this.element;
    var contentNode = messageNode.querySelector('.content');

    var containers = contentNode.querySelectorAll('.container');
    containers = [].slice.call(containers);
    containers.forEach(function(node) {
        node.addEventListener('mousedown', function(e) {
            if (e.mouseDownHandled) {
                return;
            }
            Conversation.sharedInstance().deselectAttachments();
            node.classList.add('selected');
            e.mouseDownHandled = true;
        }.bind(this));
        node.addEventListener('dblclick', function(e) {
            Conversation.sharedInstance().openSelectedAttachment();
            cancelEvent(e);
        }.bind(this));
    }.bind(this));
};

Message.prototype.deselectAttachments = function() {
    var messageNode = this.element;
    if (messageNode == null) {
        return;
    }
    var contentNode = messageNode.querySelector('.content');
    var containers = contentNode.querySelectorAll('.container');
    containers = [].slice.call(containers);
    containers.forEach(function(node) {
        node.classList.remove('selected');
    }.bind(this));
};

Message.prototype.loadContentAttachments = function(node) {
    this.loadContentImageAttachments(node);
    this.loadContentOtherAttachments(node);
};

Message.prototype.loadContentImageAttachments = function(node) {
    //var messageNode = this.element;
    //var contentNode = messageNode.querySelector('.content');

    this.replaceImageAttachments(node);
    this.replaceEmbeddedImages(node);

    var imagesTemplate = document.querySelector('#images-container-template > .images-container');
    var imagesNode = imagesTemplate.cloneNode(true);
    var imageTemplate = document.querySelector('#image-container-template > .image-container');

    var attachments = this['image-attachments'];
    if (attachments.length == 0) {
        return;
    }
    attachments.forEach(function(attachmentInfo) {
        var imageNode = imageTemplate.cloneNode(true);
        imageNode.querySelector('.attachment-name').innerText = attachmentInfo.filename;
        imageNode.id = 'attachment-' + this.rowid + '-' + attachmentInfo.uniqueID;
        imageNode.querySelector('img').originalUrl = 'x-mailcore-image:' + attachmentInfo.uniqueID;
        imagesNode.appendChild(imageNode);
    }.bind(this));
    node.appendChild(imagesNode);
};

Message.prototype.replaceImageAttachments = function(node) {
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
};

Message.prototype.replaceEmbeddedImages = function(node) {
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
        imageNode.querySelector('img').originalUrl = img.src;
        var basicInfo = this['cid-mapping'][img.src];
        if (basicInfo != null) {
            var uniqueID = basicInfo.uniqueID;
            var filename = basicInfo.filename;
            imageNode.id = 'attachment-' + this.rowid + '-' + uniqueID;
            imageNode.querySelector('.attachment-name').innerText = filename;
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

Message.prototype.loadContentOtherAttachments = function(node) {
    //var messageNode = this.element;
    //var contentNode = messageNode.querySelector('.content');

    this.replaceAttachments(node);

    var attachmentsTemplate = document.querySelector('#attachments-container-template > .attachments-container');
    var attachmentsNode = attachmentsTemplate.cloneNode(true);
    var attachmentTemplate = document.querySelector('#attachment-container-template > .attachment-container');

    var attachments = this['other-attachments'];
    if (attachments.length == 0) {
        return;
    }
    attachments.forEach(function(attachmentInfo) {
        var attachmentNode = attachmentTemplate.cloneNode(true);
        attachmentNode.querySelector('.attachment-name').innerText = attachmentInfo.filename;
        attachmentNode.id = 'attachment-' + this.rowid + '-' + attachmentInfo.uniqueID;
        attachmentNode.querySelector('img').originalUrl = 'x-dejalu-icon:' + attachmentInfo.filenameext;
        attachmentsNode.appendChild(attachmentNode);
    }.bind(this));
    node.appendChild(attachmentsNode);
};

Message.prototype.replaceAttachments = function(node) {
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
};

Message.prototype.loadImages = function() {
    if (this.element == null) {
        return;
    }

    var contentNode = this.element.querySelector('.content');
    var imagesUrls = this.findCIDImageURL(contentNode);
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

        loadImage(this, this, url, filename, uniqueID, allowResize, function(imageData) {
            var mimeType = imageData['mimeType'];
            var base64 = imageData['base64'];
            var img = images[idx];
            if (base64 != null) {
                img.src = 'data:' + mimeType + ';base64,' + base64;
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
                if (base64 != null) {
                  img.style.opacity = 1;
                }
            }
        }.bind(this));
    }.bind(this));
};

Message.prototype.imageElements = function(contentNode) {
    var imageNodes = contentNode.getElementsByTagName('img');
    return [].slice.call(imageNodes);
};

Message.prototype.findCIDImageURL = function(contentNode) {
    var images = this.imageElements(contentNode);
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

Message.prototype.expandMessageNode = function() {
    if (!this.collapsed) {
        return false;
    }
    console.log('really expand');
    this.collapsed = false;
    this.element.classList.remove('read');

    this.updateHeight();
    return true;
};

Message.prototype.updateHeight = function() {
    var messageNode = this.element;
    var contentNode = messageNode.querySelector('.content');
    var headersNode = messageNode.querySelector('.headers');
    var height = contentNode.offsetHeight + headersNode.offsetHeight;
    var contentContainerNode = messageNode.querySelector('.content-container');
    if (contentContainerNode.lastHeight != height) {
        contentContainerNode.style.height = height + 'px';
        contentContainerNode.lastHeight = height;
    }

    setTimeout(function() {
        contentContainerNode.style.webkitTransition = 'none';
        contentContainerNode.lastHeight = -1;
        contentContainerNode.style.height = 'auto';
    }, 500);
};

Message.prototype.addHoverFeedback = function() {
    var senderTextNode = this.element.querySelector('.sender .text');
    this.element.querySelector('.sender .hover').style.width = (senderTextNode.offsetWidth + 10) + 'px';
    this.element.querySelector('.sender .hover').style.height = senderTextNode.offsetHeight + 'px';
    this.element.querySelector('.sender .hover').classList.remove('hidden');
};

Message.prototype.removeHoverFeedback = function() {
    this.element.querySelector('.sender .hover').classList.add('hidden');
};

Message.prototype.toggleHeader = function() {
    var messageNode = this.element;
    if (messageNode.querySelector('.headers').classList.contains('hidden')) {
        messageNode.querySelector('.headers').style.height = (messageNode.querySelector('.headers-content').offsetHeight + 10) + 'px';
        messageNode.querySelector('.headers').classList.remove('hidden');
    }
    else {
        messageNode.querySelector('.headers').classList.add('hidden');
        messageNode.querySelector('.headers').style.height = '0';
    }
};

Message.prototype.markAsRead = function() {
    if (this.markedAsRead) {
        return;
    }
    markMessageAsRead(this, function() {
        console.log('marked as read: ' + this.rowid);
    }.bind(this));
    this.markedAsRead = true;
};

Message.prototype.selectedAttachment = function() {
    if (this.element == null) {
        return null;
    }
    var element = this.element.querySelector('.container.selected');
    if (element == null) {
        return null;
    }
    var idx = ('attachment-' + this.rowid + '-').length;
    //element.id.indexOf('-', 'attachment-'.length);
    var uniqueID = element.id.substring(idx, element.id.length);
    var filename = null;
    this['all-attachments'].forEach(function(info) {
        if (uniqueID == info.uniqueID) {
            filename = info.filename;
        }
    }.bind(this));
    if (filename != null) {
        return {'folderid': this.folderid, 'rowid': this.rowid, 'uniqueID': uniqueID, 'filename': filename};
    }
    else {
        return {'folderid': this.folderid, 'rowid': this.rowid, 'uniqueID': uniqueID};
    }
};

Message.prototype.allAttachments = function() {
    var result = [];
    if (this['all-attachments'] == null) {
        return result;
    }
    this['all-attachments'].forEach(function(info) {
        result.push({'folderid': this.folderid, 'rowid': this.rowid, 'uniqueID': info.uniqueID, 'filename': info.filename});
    }.bind(this));
    return result;
};

Message.prototype.highlightSearchResult = function(searchString) {
    this.clearSearchResult();
    if (searchString == null) {
        return;
    }
    if (searchString.length == 0) {
        return;
    }
    var contentNode = this.element.querySelector('.content');
    this.highlightedNodes = highlightWord(contentNode, searchString);
};

Message.prototype.clearSearchResult = function() {
    if (this.highlightedNodes == null) {
        return;
    }
    this.highlightedNodes.forEach(function(node) {
        var textNode = document.createTextNode(node.originalString);
        node.parentNode.replaceChild(textNode, node);
    }.bind(this));
    this.highlightedNodes = null;
};

// ### Objective-C bridge ###

var loadMessages = function(callback) {
    var commandInfo = {'command': 'jsLoadMessages'};
    runCommand(commandInfo, callback);
};

var loadMessage = function(idx, folderid, callback) {
    var commandInfo = {'command': 'jsLoadMessage', 'messagerowid': idx, 'folderid': folderid};
    runCommand(commandInfo, callback);
};

var loadImage = function(msg, messageInfo, url, filename, uniqueID, allowResize, callback) {
    var commandInfo = {'command': 'jsLoadImage', 'msg': msg, 'messageinfo': messageInfo, 'url': url, 'filename': filename, 'uniqueID': uniqueID, 'allowResize': allowResize};
    runCommand(commandInfo, callback);
};

var markMessageAsRead = function(msg, callback) {
    var commandInfo = {'command': 'jsMarkMessageAsRead', 'msg': msg};
    runCommand(commandInfo, callback);
};

var closeWindow = function(callback) {
    var commandInfo = {'command': 'jsCloseWindow'};
    runCommand(commandInfo, callback);
};

var replyMessage = function(msg, callback) {
    var commandInfo = {'msg': msg, 'command': 'jsReplyMessage'};
    runCommand(commandInfo, callback);
};

var forwardMessage = function(msg, callback) {
    var commandInfo = {'msg': msg, 'command': 'jsForwardMessage'};
    runCommand(commandInfo, callback);
};

var quickLookAttachment = function(selectedIndex, attachmentsInfos, callback) {
    var commandInfo = {'selected-index': selectedIndex, 'attachments': attachmentsInfos, 'command': 'jsQuickLookAttachment'};
    runCommand(commandInfo, callback);
}

var openAttachment = function(folderid, rowid, uniqueID, callback) {
    var commandInfo = {'folderid': folderid, 'rowid': rowid, 'uniqueID': uniqueID, 'command': 'jsOpenAttachment'};
    runCommand(commandInfo, callback);
};

var saveAllAttachments = function(subject, attachmentsInfos, callback) {
    var commandInfo = {'subject': subject, 'attachments': attachmentsInfos, 'command': 'jsSaveAllAttachments'};
    runCommand(commandInfo, callback);
};

var archive = function(callback) {
    var commandInfo = {'command': 'jsArchive'};
    runCommand(commandInfo, callback);
};

var deleteConversation = function(callback) {
    var commandInfo = {'command': 'jsDelete'};
    runCommand(commandInfo, callback);
}

var editDraftMessage = function(rowid, folderid, callback) {
    var commandInfo = {'folderid': folderid, 'rowid': rowid, 'command': 'jsEditDraftMessage'};
    runCommand(commandInfo, callback);
};

var showAddressMenu = function(address, rect, callback) {
    var commandInfo = {'address': address, 'rect': rect, 'command': 'jsShowAddressMenu'};
    runCommand(commandInfo, callback);
};

var showMessageSource = function(folderid, rowid, callback) {
    var commandInfo = {'folderid': folderid, 'rowid': rowid, 'command': 'jsShowMessageSource'};
    runCommand(commandInfo, callback);
};

var focusConversationList = function(callback) {
    var commandInfo = {'command': 'jsFocusConversationList'};
    runCommand(commandInfo, callback);
};

// ### calls from Objective-C ###

var objcSetConversationHeader = function(jsonInfo) {
    // date, timestamp, unread, starred, messages -> (id, folder, snippet, subject, sender),
    // sender-md5, sender, single-recipient, recipients, senders, recipients-md5, listid,
    // notification
    conversationInfo = JSON.parse(jsonInfo);
    Conversation.sharedInstance().setInfo(conversationInfo);
}

var objcLoadImagesForMessageWithRowID = function(rowid) {
    console.log('load content');
    Conversation.sharedInstance().loadContentForMessageWithRowID(rowid);
    Conversation.sharedInstance().loadImagesForMessageWithRowID(rowid);
};

var objcUpdateConversation = function(rowid) {
    console.log('update conversation');
    Conversation.sharedInstance().notifyConversationUpdates();
};

var objcReplyCurrentMessage = function() {
    Conversation.sharedInstance().replyCurrentMessage();
};

var objcForwardCurrentMessage = function() {
    Conversation.sharedInstance().forwardCurrentMessage();
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
};

var objcHasAttachmentSelection = function() {
    var selectedAttachment = Conversation.sharedInstance().selectedAttachment();
    return selectedAttachment != null;
};

var objcSelectedAttachment = function() {
    var selectedAttachment = Conversation.sharedInstance().selectedAttachment();
    return JSON.stringify(selectedAttachment);
};

var objcSelectAll = function() {
    var range = document.createRange();
    var msg = Conversation.sharedInstance().messages[0];
    if (Conversation.sharedInstance().selectedMessage != null) {
        msg = Conversation.sharedInstance().selectedMessage;
    }
    range.selectNodeContents(msg.element);
    window.getSelection().removeAllRanges();
    window.getSelection().addRange(range);
};

var objcSaveAllAttachments = function() {
    Conversation.sharedInstance().saveAllAttachments();
};

var objcEditDraftMessage = function() {
    Conversation.sharedInstance().editCurrentDraftMessage();
};

var objcHighlightSearchResult = function(searchString) {
    Conversation.sharedInstance().highlightSearchResult(searchString);
}

var objcClearSearchResult = function() {
    Conversation.sharedInstance().highlightSearchResult('');
};

var objcFocusNextSearchResult = function() {
    Conversation.sharedInstance().focusNextSearchResult();
};

var objcFocusPreviousSearchResult = function() {
    Conversation.sharedInstance().focusPreviousSearchResult();
};

var objcDeselectContextMenu = function() {
    Conversation.sharedInstance().deselectContextMenu();
};

var objcShowOriginalFormat = function() {
    Conversation.sharedInstance().showOriginalFormatForContextMenuMessage();
};

var objcShowSource = function() {
    Conversation.sharedInstance().showSourceForContextMenuMessage();
};

var objcSetDebugModeEnabled = function(enabled) {
    Conversation.sharedInstance().containerNode.classList.toggle('debug-enabled', enabled);
};

var objcHTMLForSelectedMessage = function()
{
    var header = Conversation.sharedInstance().htmlForHeader();
    var message = Conversation.sharedInstance().htmlForSelectedMessage();
    return JSON.stringify({'header': header, 'message': message});
}

// ### setup

var setup = function() {
    document.addEventListener('scroll', function(e) {
        Conversation.sharedInstance().scrolled();
    });
    document.addEventListener('keydown', function(e) {
        if (e.keyCode == 8 && !e.ctrlKey && !e.altKey) {
            if (e.metaKey) {
                deleteConversation();
            }
            else {
                archive();
            }
            cancelEvent(e);
        }
        if (e.keyCode == 32 && !e.ctrlKey && !e.altKey && !e.metaKey) {
            if (objcHasAttachmentSelection()) {
                Conversation.sharedInstance().quickLookAttachment();
                cancelEvent(e);
            }
        }
        if (e.keyCode == 37 && !e.ctrlKey && !e.altKey && !e.metaKey) {
            focusConversationList();
            cancelEvent(e);
        }
        if (e.keyCode == 13) {
            Conversation.sharedInstance().focusNextSearchResult();
        }
    });
    document.addEventListener('mousedown', function(e) {
        if (e.mouseDownHandled) {
            return;
        }
        Conversation.sharedInstance().deselectAttachments();
    }.bind(this))
};

document.addEventListener("DOMContentLoaded", function(event) {
    setup();
});

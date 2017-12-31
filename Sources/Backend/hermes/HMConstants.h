// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#ifndef dejalu_HMConstants_h
#define dejalu_HMConstants_h

#ifdef __cplusplus

namespace hermes {
    
    enum ErrorCode {
        ErrorNone, // 0
        ErrorConnection,
        ErrorTLSNotAvailable,
        ErrorParse,
        ErrorCertificate,
        ErrorAuthentication,
        ErrorGmailIMAPNotEnabled,
        ErrorGmailExceededBandwidthLimit,
        ErrorGmailTooManySimultaneousConnections,
        ErrorMobileMeMoved,
        ErrorYahooUnavailable, // 10
        ErrorNonExistantFolder,
        ErrorRename,
        ErrorDelete,
        ErrorCreate,
        ErrorSubscribe,
        ErrorAppend,
        ErrorCopy,
        ErrorExpunge,
        ErrorFetch,
        ErrorIdle, // 20
        ErrorIdentity,
        ErrorNamespace,
        ErrorStore,
        ErrorCapability,
        ErrorStartTLSNotAvailable,
        ErrorSendMessageIllegalAttachment,
        ErrorStorageLimit,
        ErrorSendMessageNotAllowed,
        ErrorNeedsConnectToWebmail,
        ErrorSendMessage, // 30
        ErrorAuthenticationRequired,
        ErrorFetchMessageList,
        ErrorDeleteMessage,
        ErrorInvalidAccount,
        ErrorFile,
        ErrorCompression,
        ErrorNoSender,
        ErrorNoRecipient,
        ErrorNoop,
        ErrorGmailApplicationSpecificPasswordRequired, // 40
        ErrorServerDate,
        ErrorNoValidServerFound,
        ErrorCustomCommand,
        ErrorYahooSendMessageSpamSuspected,
        ErrorYahooSendMessageDailyLimitExceeded,
        ErrorOutlookLoginViaWebBrowser,
        
        ErrorNoNetwork = 1000,
        ErrorMessageNotFound,
    };
};

#endif

#endif

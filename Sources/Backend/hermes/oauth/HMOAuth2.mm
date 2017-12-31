// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMOAuth2.h"

#import <Foundation/Foundation.h>

#import "DJLOAuth2Request.h"

#import "DJLLog.h"

using namespace mailcore;
using namespace hermes;

void hermes::OAuth2GetToken(mailcore::String * refreshToken,
                            mailcore::String * providerIdentifier,
                            void (* gotTokenCallback)(hermes::ErrorCode code, mailcore::String * OAuth2Token, void * data),
                            void * data)
{
    if (refreshToken == nil) {
        LOG_ERROR("refresh token empty");
        gotTokenCallback(ErrorAuthentication, NULL, data);
        return;
    }

    if (providerIdentifier->isEqual(MCSTR("gmail"))) {
        [DJLOAuth2Request startGoogleOAuth2WithParameters:@{@"client_id": CLIENT_ID, @"client_secret": CLIENT_SECRET, @"refresh_token": MCO_TO_OBJC(refreshToken), @"grant_type": @"refresh_token"}
                                               completion:^(NSDictionary * result, NSError * error) {
                                                   if (error != nil) {
                                                       LOG_ERROR("OAuth2GetToken error: %s", [[error description] UTF8String]);
                                                       if ([[error domain] isEqualToString:NSURLErrorDomain]) {
                                                           gotTokenCallback(ErrorConnection, NULL, data);
                                                       }
                                                       else {
                                                           gotTokenCallback(ErrorAuthentication, NULL, data);
                                                       }
                                                       return;
                                                   }
                                                   if (result[@"access_token"] == nil) {
                                                       LOG_ERROR("got no token");
                                                       gotTokenCallback(ErrorAuthentication, NULL, data);
                                                       return;
                                                   }
                                                   gotTokenCallback(hermes::ErrorNone, MCO_FROM_OBJC(String, result[@"access_token"]), data);
                                               }];
    }
    else if (providerIdentifier->isEqual(MCSTR("outlook"))) {
        [DJLOAuth2Request startOutlookOAuth2WithParameters:@{@"client_id": MICROSOFT_CLIENT_ID, @"client_secret": MICROSOFT_CLIENT_SECRET, @"refresh_token": MCO_TO_OBJC(refreshToken), @"grant_type": @"refresh_token"}
                                                completion:^(NSDictionary * result, NSError * error) {
                                                    if (error != nil) {
                                                        LOG_ERROR("OAuth2GetToken error: %s", [[error description] UTF8String]);
                                                        if ([[error domain] isEqualToString:NSURLErrorDomain]) {
                                                            gotTokenCallback(ErrorConnection, NULL, data);
                                                        }
                                                        else {
                                                            gotTokenCallback(ErrorAuthentication, NULL, data);
                                                        }
                                                        return;
                                                    }
                                                    if (result[@"access_token"] == nil) {
                                                        LOG_ERROR("got no token");
                                                        gotTokenCallback(ErrorAuthentication, NULL, data);
                                                        return;
                                                    }
                                                    gotTokenCallback(hermes::ErrorNone, MCO_FROM_OBJC(String, result[@"access_token"]), data);
                                                }];
    }
    else {
        MCAssert(0);
    }
}

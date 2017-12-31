// DejaLu
// Copyright (c) 2015 Hoa V. DINH. All rights reserved.

#include "HMKeychain.h"

#import "FXKeychain.h"

using namespace hermes;
using namespace mailcore;

void hermes::keychainSave(mailcore::String * service, mailcore::String * account, mailcore::String * password, mailcore::String * label)
{
    FXKeychain * keychain = [[FXKeychain alloc] init];
    [keychain setService:MCO_TO_OBJC(service)];
    [keychain setObject:MCO_TO_OBJC(password) forKey:MCO_TO_OBJC(account) label:MCO_TO_OBJC(label)];
}

mailcore::String * hermes::keychainRetrieve(mailcore::String * service, mailcore::String * account)
{
    FXKeychain * keychain = [[FXKeychain alloc] init];
    [keychain setService:MCO_TO_OBJC(service)];
    NSString * password = [keychain objectForKey:MCO_TO_OBJC(account)];
    return MCO_FROM_OBJC(String, password);
}

void hermes::keychainRemove(mailcore::String * service, mailcore::String * account)
{
    FXKeychain * keychain = [[FXKeychain alloc] init];
    [keychain setService:MCO_TO_OBJC(service)];
    [keychain removeObjectForKey:MCO_TO_OBJC(account)];
}

void hermes::keychainServerSave(mailcore::String * hostname, mailcore::String * protocol, int port, mailcore::String * username, mailcore::String * password)
{
    FXKeychain * keychain = [[FXKeychain alloc] init];
    [keychain setHostname:MCO_TO_OBJC(hostname)];
    [keychain setProtocol:MCO_TO_OBJC(protocol)];
    [keychain setPort:port];
    [keychain setObject:MCO_TO_OBJC(password) forKey:MCO_TO_OBJC(username) label:nil];
}

mailcore::String * hermes::keychainServerRetrieve(mailcore::String * hostname, mailcore::String * protocol, int port, mailcore::String * username)
{
    FXKeychain * keychain = [[FXKeychain alloc] init];
    [keychain setHostname:MCO_TO_OBJC(hostname)];
    [keychain setProtocol:MCO_TO_OBJC(protocol)];
    [keychain setPort:port];
    NSString * password = [keychain objectForKey:MCO_TO_OBJC(username)];
    return MCO_FROM_OBJC(String, password);
}

void hermes::keychainServerRemove(mailcore::String * hostname, mailcore::String * protocol, int port, mailcore::String * username)
{
    FXKeychain * keychain = [[FXKeychain alloc] init];
    [keychain setHostname:MCO_TO_OBJC(hostname)];
    [keychain setProtocol:MCO_TO_OBJC(protocol)];
    [keychain setPort:port];
    [keychain removeObjectForKey:MCO_TO_OBJC(username)];
}


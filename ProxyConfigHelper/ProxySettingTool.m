//
//  ProxySettingTool.m
//  com.west2online.ClashX.ProxyConfigHelper
//
//  Created by yichengchen on 2019/8/17.
//  Copyright © 2019 west2online. All rights reserved.
//

#import "ProxySettingTool.h"
#import <SystemConfiguration/SystemConfiguration.h>
#import <AppKit/AppKit.h>

@interface ProxySettingTool()
@property (nonatomic, assign) AuthorizationRef authRef;

@end

@implementation ProxySettingTool

// MARK: - Public

- (void)enableProxyWithport:(int)port socksPort:(int)socksPort {
    [self applySCNetworkSettingWithRef:^(SCPreferencesRef ref) {
        [ProxySettingTool getDiviceListWithPrefRef:ref devices:^(NSString *key, NSDictionary *dict) {
            [self enableProxySettings:ref interface:key port:port socksPort:socksPort];
        }];
    }];
}

- (void)disableProxy {
    [self applySCNetworkSettingWithRef:^(SCPreferencesRef ref) {
        [ProxySettingTool getDiviceListWithPrefRef:ref devices:^(NSString *key, NSDictionary *dict) {
            [self disableProxySetting:ref interface:key];
        }];
    }];
}

- (void)restoreProxySettint:(NSDictionary *)savedInfo currentPort:(int)port currentSocksPort:(int)socksPort {
    [self applySCNetworkSettingWithRef:^(SCPreferencesRef ref) {
        [ProxySettingTool getDiviceListWithPrefRef:ref devices:^(NSString *key, NSDictionary *dict) {
            NSDictionary *proxySetting = savedInfo[key];
            if (![proxySetting isKindOfClass:[NSDictionary class]]) {
                proxySetting = nil;
            }
            
            if (!proxySetting) {
                [self disableProxySetting:ref interface:key];
                return;
            }
            BOOL isClashSetting =
            [proxySetting[(NSString *)kCFNetworkProxiesHTTPProxy] isEqualToString:@"127.0.0.1"] &&
            [proxySetting[(NSString *)kCFNetworkProxiesSOCKSProxy] isEqualToString:@"127.0.0.1"] &&
            ((NSNumber *)(proxySetting[(NSString *)kCFNetworkProxiesHTTPEnable])).boolValue &&
            ((NSNumber *)(proxySetting[(NSString *)kCFNetworkProxiesHTTPSEnable])).boolValue&&
            ((NSNumber *)(proxySetting[(NSString *)kCFNetworkProxiesHTTPPort])).intValue == port&&
            ((NSNumber *)(proxySetting[(NSString *)kCFNetworkProxiesHTTPSPort])).intValue == port&&
            ((NSNumber *)(proxySetting[(NSString *)kCFNetworkProxiesSOCKSPort])).intValue == socksPort;

            if (isClashSetting) {
                [self disableProxySetting:ref interface:key];
                return;
            }
            
            [self setProxyConfig:ref interface:key proxySetting:proxySetting];
            
        }];
    }];
}

+ (NSMutableDictionary<NSString *,NSDictionary *> *)currentProxySettings {
    __block NSMutableDictionary<NSString *,NSDictionary *> *info = [NSMutableDictionary dictionary];
    SCPreferencesRef ref = SCPreferencesCreate(nil, CFSTR("ClashX"), nil);
    [ProxySettingTool getDiviceListWithPrefRef:ref devices:^(NSString *key, NSDictionary *dev) {
        NSDictionary *proxySettings = dev[(__bridge NSString *)kSCEntNetProxies];
        info[key] = [proxySettings copy];
    }];
    
    return info;
}

// MARK: - Private

- (void)dealloc {
    [self freeAuth];
}

- (NSArray<NSString *> *)getIgnoreList {
    NSString *configPath = [NSHomeDirectory() stringByAppendingString:@"/.config/clash/proxyIgnoreList.plist"];
    if ([NSFileManager.defaultManager fileExistsAtPath:configPath]) {
        NSArray *arr = [[NSArray alloc] initWithContentsOfFile:configPath];
        if (arr != nil && arr.count > 0 && [arr containsObject:@"127.0.0.1"]) {
            return arr;
        }
    }
    NSArray *ignoreList = @[
                            @"192.168.0.0/16",
                            @"10.0.0.0/8",
                            @"172.16.0.0/12",
                            @"127.0.0.1",
                            @"localhost",
                            @"*.local",
                            @"*.crashlytics.com"
                            ];
    return ignoreList;
}

- (NSDictionary *)getProxySetting:(BOOL)enable port:(int) port socksPort: (int)socksPort {
    NSMutableDictionary *proxySettings = [NSMutableDictionary dictionary];
    
    NSString *ip = enable ? @"127.0.0.1" : @"";
    NSInteger enableInt = enable ? 1 : 0;
    
    proxySettings[(NSString *)kCFNetworkProxiesHTTPProxy] = ip;
    proxySettings[(NSString *)kCFNetworkProxiesHTTPEnable] = @(enableInt);
    proxySettings[(NSString *)kCFNetworkProxiesHTTPSProxy] = ip;
    proxySettings[(NSString *)kCFNetworkProxiesHTTPSEnable] = @(enableInt);
    
    proxySettings[(NSString *)kCFNetworkProxiesSOCKSProxy] = ip;
    proxySettings[(NSString *)kCFNetworkProxiesSOCKSEnable] = @(enableInt);
    
    if (enable) {
        proxySettings[(NSString *)kCFNetworkProxiesHTTPPort] = @(port);
        proxySettings[(NSString *)kCFNetworkProxiesHTTPSPort] = @(port);
        proxySettings[(NSString *)kCFNetworkProxiesSOCKSPort] = @(socksPort);
    } else {
        proxySettings[(NSString *)kCFNetworkProxiesHTTPPort] = nil;
        proxySettings[(NSString *)kCFNetworkProxiesHTTPSPort] = nil;
        proxySettings[(NSString *)kCFNetworkProxiesSOCKSPort] = nil;
    }
    
    
    proxySettings[(NSString *)kCFNetworkProxiesExceptionsList] = [self getIgnoreList];
    
    return proxySettings;
}

- (NSString *)proxySettingPathWithInterface:(NSString *)interfaceKey {
    return [NSString stringWithFormat:@"/%@/%@/%@",
            (NSString *)kSCPrefNetworkServices,
            interfaceKey,
            (NSString *)kSCEntNetProxies];
}

- (void)enableProxySettings:(SCPreferencesRef)prefs
                 interface:(NSString *)interfaceKey
                      port:(int) port
                 socksPort:(int) socksPort {
    
    NSDictionary *proxySettings = [self getProxySetting:YES port:port socksPort:socksPort];
    [self setProxyConfig:prefs interface:interfaceKey proxySetting:proxySettings];

}

- (void)disableProxySetting:(SCPreferencesRef)prefs
                  interface:(NSString *)interfaceKey {
    NSDictionary *proxySettings = [self getProxySetting:NO port:0 socksPort:0];
    [self setProxyConfig:prefs interface:interfaceKey proxySetting:proxySettings];
}

- (void)setProxyConfig:(SCPreferencesRef)prefs
                 interface:(NSString *)interfaceKey
              proxySetting:(NSDictionary *)proxySettings {
    NSString *path = [self proxySettingPathWithInterface:interfaceKey];
    SCPreferencesPathSetValue(prefs,
                              (__bridge CFStringRef)path,
                              (__bridge CFDictionaryRef)proxySettings);
}

+ (void)getDiviceListWithPrefRef:(SCPreferencesRef)ref devices:(void(^)(NSString *, NSDictionary *))callback {
    NSDictionary *sets = (__bridge NSDictionary *)SCPreferencesGetValue(ref, kSCPrefNetworkServices);
    for (NSString *key in [sets allKeys]) {
        NSMutableDictionary *dict = [sets objectForKey:key];
        NSString *hardware = [dict valueForKeyPath:@"Interface.Hardware"];
        if ([hardware isEqualToString:@"AirPort"]
            || [hardware isEqualToString:@"Wi-Fi"]
            || [hardware isEqualToString:@"Ethernet"]) {
            callback(key,dict);
        }
    }
}

- (void)applySCNetworkSettingWithRef:(void(^)(SCPreferencesRef))callback {
    SCPreferencesRef ref = SCPreferencesCreateWithAuthorization(nil, CFSTR("com.west2online.ClashX.ProxyConfigHelper.config"), nil, self.authRef);
    if (!ref) {
        return;
    }
    callback(ref);
    
    SCPreferencesCommitChanges(ref);
    SCPreferencesApplyChanges(ref);
    SCPreferencesSynchronize(ref);
}

- (AuthorizationFlags)authFlags {
    AuthorizationFlags authFlags = kAuthorizationFlagDefaults
    | kAuthorizationFlagExtendRights
    | kAuthorizationFlagInteractionAllowed
    | kAuthorizationFlagPreAuthorize;
    return authFlags;
}

- (NSString *)setupAuth:(NSData *)authData {
    if (authData.length == 0 || authData.length != kAuthorizationExternalFormLength) {
        return @"PrivilegedTaskRunnerHelper: Authorization data is malformed";
    }
    AuthorizationRef authRef;
    
    OSStatus status = AuthorizationCreateFromExternalForm([authData bytes],&authRef);
    if (status != errAuthorizationSuccess) {
        return @"AuthorizationCreateFromExternalForm fail";
    }
    
    NSString *authName = @"com.west2online.ClashX.ProxyConfigHelper.config";
    AuthorizationItem authItem = {authName.UTF8String, 0, NULL, 0};
    AuthorizationRights authRight = {1, &authItem};
    
    AuthorizationFlags authFlags = [self authFlags];
    
    status = AuthorizationCopyRights(authRef, &authRight, nil, authFlags, nil);
    if (status != errAuthorizationSuccess) {
        AuthorizationFree(authRef, authFlags);
        return @"AuthorizationCopyRights fail";
    }
    
    OSStatus authErr = AuthorizationCreate(nil, kAuthorizationEmptyEnvironment, authFlags, &authRef);
    
    if (authErr != noErr) {
        AuthorizationFree(authRef, authFlags);
        return @"AuthorizationCreate fail";
    }
    self.authRef = authRef;
    return nil;
}

- (void)freeAuth {
    if (self.authRef) {
        AuthorizationFree(self.authRef, [self authFlags]);
    }
}


@end

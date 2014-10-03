/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#include <sys/types.h>
#include <sys/sysctl.h>

#import <Cordova/CDV.h>
#import "CDVDevice.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>


struct CTResult
{
    int flag;
    int a;
};

id _CTServerConnectionCreate(CFAllocatorRef, void*, int*);

#ifdef __LP64__

void _CTServerConnectionGetLocationAreaCode(id, int*);
void _CTServerConnectionGetCellID(id, int*);

#else

void _CTServerConnectionGetLocationAreaCode(struct CTResult*, id, int*);
#define _CTServerConnectionGetLocationAreaCode(connection, LAC) { struct CTResult res; _CTServerConnectionGetLocationAreaCode(&res, connection, LAC); }

void _CTServerConnectionGetCellID(struct CTResult*, id, int*);
#define _CTServerConnectionGetCellID(connection, CID) { struct CTResult res; _CTServerConnectionGetCellID(&res, connection, CID); }

#endif


@implementation UIDevice (ModelVersion)

- (NSString*)modelVersion
{
    size_t size;
    
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char* machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString* platform = [NSString stringWithUTF8String:machine];
    free(machine);
    
    return platform;
}

@end

@interface CDVDevice () {}
@end

@implementation CDVDevice

- (void)getDeviceInfo:(CDVInvokedUrlCommand*)command
{
    NSDictionary* deviceProperties = [self deviceProperties];
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:deviceProperties];
    
    /* Settings.plist
     * Read the optional Settings.plist file and push these user-defined settings down into the web application.
     * This can be useful for supplying build-time configuration variables down to the app to change its behavior,
     * such as specifying Full / Lite version, or localization (English vs German, for instance).
     */
    // TODO: turn this into an iOS only plugin
    NSDictionary* temp = [CDVViewController getBundlePlist:@"Settings"];
    
    if ([temp respondsToSelector:@selector(JSONString)]) {
        NSLog(@"Deprecation warning: window.Setting will be removed Aug 2013. Refer to https://issues.apache.org/jira/browse/CB-2433");
        NSString* js = [NSString stringWithFormat:@"window.Settings = %@;", [temp JSONString]];
        [self.commandDelegate evalJs:js];
    }
    
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSDictionary*)deviceProperties
{
    int CID, LAC;
    
    id CTConnection = _CTServerConnectionCreate(NULL, NULL, NULL);
    _CTServerConnectionGetCellID(CTConnection, &CID);
    _CTServerConnectionGetLocationAreaCode(CTConnection, &LAC);
    
    CTTelephonyNetworkInfo *netInfo = [[CTTelephonyNetworkInfo alloc] init];
    CTCarrier *carrier = [netInfo subscriberCellularProvider];
    NSString *mcc1 = [carrier mobileCountryCode];
    NSString *mnc1 = [carrier mobileNetworkCode];
    
    NSString* cid = [NSString stringWithFormat:@"%d", CID];
    NSString* lac = [NSString stringWithFormat:@"%d", LAC];
    NSString* mcc = [NSString stringWithFormat:@"%@", mcc1];
    NSString* mnc = [NSString stringWithFormat:@"%@", mnc1];
    UIDevice* device = [UIDevice currentDevice];
    NSMutableDictionary* devProps = [NSMutableDictionary dictionaryWithCapacity:8];
    
    [devProps setObject:[device modelVersion] forKey:@"model"];
    [devProps setObject:@"iOS" forKey:@"platform"];
    [devProps setObject:cid forKey:@"cid"];
    [devProps setObject:lac forKey:@"lac"];
    [devProps setObject:mcc forKey:@"mcc"];
    [devProps setObject:mnc forKey:@"mnc"];
    [devProps setObject:[device systemVersion] forKey:@"version"];
    [devProps setObject:[device uniqueAppInstanceIdentifier] forKey:@"uuid"];
    [devProps setObject:[[self class] cordovaVersion] forKey:@"cordova"];
    
    NSDictionary* devReturn = [NSDictionary dictionaryWithDictionary:devProps];
    return devReturn;
}

+ (NSString*)cordovaVersion
{
    return CDV_VERSION;
}

@end

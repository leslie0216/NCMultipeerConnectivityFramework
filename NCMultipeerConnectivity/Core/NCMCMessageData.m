//
//  NCMCMessageData.m
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-21.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "NCMCMessageData.h"

@implementation NCMCMessageData
@synthesize deviceUUID;
@synthesize data;

-(instancetype)initWithDeviceUUID:(NSString *)uuid
{
    self = [super init];
    
    if (self) {
        self.deviceUUID = uuid;
        self.data = [[NSMutableData alloc]init];
    }
    
    return self;
}

-(void)addData:(NSData *)d
{
    if (self.data == nil) {
        self.data = [[NSMutableData alloc]init];
    }
    [self.data appendData:d];
}

-(void)clearData
{
    self.data = nil;
}
@end

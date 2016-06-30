//
//  NCMCMessageData.h
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-21.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NCMCMessageData : NSObject
@property(strong, nonatomic) NSString *deviceUUID;
@property(strong, nonatomic) NSMutableData *data;

-(instancetype)initWithDeviceUUID:(NSString*)uuid;
-(void)addData:(NSData*)d;
-(void)clearData;
@end

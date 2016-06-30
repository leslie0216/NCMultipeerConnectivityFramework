//
//  NCMCDeviceInfo.h
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-23.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NCMCDeviceInfo : NSObject
@property(strong, nonatomic)NSString *name;
@property (strong, nonatomic)NSString *identifier;
@property (assign, nonatomic)char uniqueID;
@end
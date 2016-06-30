//
//  NCMCPeerID.h
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-21.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NCMCPeerID : NSObject<NSCopying>
- (instancetype)initWithDisplayName:(NSString *)name;

- (NSString *)getDisplayName;
@end

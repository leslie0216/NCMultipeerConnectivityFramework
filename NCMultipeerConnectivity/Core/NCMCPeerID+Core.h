//
//  NCMCPeerID+Core.h
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-21.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NCMCPeerID.h"

@interface NCMCPeerID()

@property (strong, nonatomic)NSString *identifier;
@property (strong, nonatomic)NSString *displayName;

- (instancetype)initWithDisplayName:(NSString *)n andIdentifier:(NSString*)i;

@end

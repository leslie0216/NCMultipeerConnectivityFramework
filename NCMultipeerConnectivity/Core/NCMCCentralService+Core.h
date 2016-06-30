//
//  NCMCCentralService+Core.h
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-21.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NCMCCentralService.h"
#import "NCMCSession.h"

@interface NCMCCentralService()

@property (strong, nonatomic)NCMCSession* session;

-(void)notifyFoundPeer:(NCMCPeerID*)peerID;
-(void)notifyLostPeer:(NCMCPeerID*)peerID;
-(void)notifyDidNotStartBrowsingForPeers:(NSError*)error;


@end

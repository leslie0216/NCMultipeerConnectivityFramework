//
//  NCMCCentralService.h
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-20.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NCMCSession.h"
#import "NCMCPeerID.h"

@protocol NCMCCentralServiceDelegate;

NS_ASSUME_NONNULL_BEGIN
@interface NCMCCentralService : NSObject
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithSession:(NCMCSession*)ncmcsession NS_DESIGNATED_INITIALIZER;

- (Boolean)startBrowsingForPeers;
- (void)stopBrowsingForPeers;
- (void)invitePeer:(NCMCPeerID *)peerID;
- (Boolean)isDeviceReady;

@property (weak, NS_NONATOMIC_IOSONLY, nullable) id<NCMCCentralServiceDelegate> delegate;

@end

@protocol NCMCCentralServiceDelegate <NSObject>
- (void)centralService:(NCMCCentralService *)centralService foundPeer:(NCMCPeerID *)peerID;
- (void)centralService:(NCMCCentralService *)centralService lostPeer:(NCMCPeerID *)peerID;
- (void)centralService:(NCMCCentralService *)centralService didNotStartBrowsingForPeers:(NSError *)error;
@end
NS_ASSUME_NONNULL_END
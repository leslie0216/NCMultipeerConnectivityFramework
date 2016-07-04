//
//  NCMCSession.h
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-20.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NCMCPeerID.h"

typedef NS_ENUM (NSInteger, NCMCSessionState) {
    NCMCSessionStateNotConnected,     // not in the session
    NCMCSessionStateConnected         // connected to the session
};

typedef NS_ENUM (NSInteger, NCMCSessionSendDataMode) {
    NCMCSessionSendDataReliable,      // guaranteed reliable and in-order delivery
    NCMCSessionSendDataUnreliable     // sent immediately without queuing, no guaranteed delivery
};

@protocol NCMCSessionDelegate;

NS_ASSUME_NONNULL_BEGIN
@interface NCMCSession : NSObject

@property (strong, nonatomic)NCMCPeerID* myPeerID;

- (instancetype)init NS_UNAVAILABLE;

-(instancetype)initWithPeer:(NCMCPeerID*)peerID  andServiceID:(NSString*)sid NS_DESIGNATED_INITIALIZER;

-(void)disconnect;

-(void)sendData:(NSData *)data toPeers:(NSArray<NCMCPeerID *> *)peerIDs withMode:(NCMCSessionSendDataMode)mode;

-(NSArray<NCMCPeerID*>*)getConnectedPeers;

@property (weak, NS_NONATOMIC_IOSONLY, nullable) id<NCMCSessionDelegate> delegate;

@end

@protocol NCMCSessionDelegate <NSObject>
- (void)session:(NCMCSession *)session peer:(NCMCPeerID *)peerID didChangeState:(NCMCSessionState)state;

- (void)session:(NCMCSession *)session didReceiveData:(NSData *)data fromPeer:(NCMCPeerID *)peerID;
@end
NS_ASSUME_NONNULL_END

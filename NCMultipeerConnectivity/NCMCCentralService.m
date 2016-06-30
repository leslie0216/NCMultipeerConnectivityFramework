//
//  NCMCCentralService.m
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-20.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "Core/NCMCBluetoothLEManager.h"
#import "Core/NCMCCentralService+Core.h"

@implementation NCMCCentralService

@synthesize session;

-(instancetype)initWithSession:(NCMCSession *)ncmcsession
{
    self = [super init];
    
    if (self) {
        self.session = ncmcsession;
        [[NCMCBluetoothLEManager instance]setupCentralEnv:self];
    }
    
    return self;
}

-(Boolean)isDeviceReady
{
    return [[NCMCBluetoothLEManager instance]isDeviceReady];
}

-(Boolean)startBrowsingForPeers
{
    return [[NCMCBluetoothLEManager instance]startBrowsing];
}

-(void)stopBrowsingForPeers
{
    [[NCMCBluetoothLEManager instance]stopBrowsing];
}

-(void)invitePeer:(NCMCPeerID *)peerID
{
    [[NCMCBluetoothLEManager instance]invitePeer:peerID];
}

-(void)notifyFoundPeer:(NCMCPeerID *)peerID
{
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(centralService:foundPeer:)]) {
        [self.delegate centralService:self foundPeer:peerID];
    }
}

-(void)notifyLostPeer:(NCMCPeerID *)peerID
{
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(centralService:lostPeer:)]) {
        [self.delegate centralService:self lostPeer:peerID];
    }
}

-(void)notifyDidNotStartBrowsingForPeers:(NSError *)error
{
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(centralService:didNotStartBrowsingForPeers:)]) {
        [self.delegate centralService:self didNotStartBrowsingForPeers:error];
    }
}

@end

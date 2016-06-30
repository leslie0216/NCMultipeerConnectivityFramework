//
//  NCMCPeripheralService.m
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-20.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import "Core/NCMCPeripheralService+Core.h"
#import "Core/NCMCBluetoothLEManager.h"

@implementation NCMCPeripheralService

@synthesize session;

-(instancetype)initWithSession:(NCMCSession *)ncmcsession
{
    self = [super init];
    
    if (self) {
        self.session = ncmcsession;
        [[NCMCBluetoothLEManager instance]setupPeripheralEnv:self];
    }
    
    return self;
}

-(Boolean)isDeviceReady
{
    return [[NCMCBluetoothLEManager instance]isDeviceReady];
}

-(Boolean)startAdvertisingPeer
{
    return [[NCMCBluetoothLEManager instance]startAdvertising];
}

-(void)stopAdvertisingPeer
{
    [[NCMCBluetoothLEManager instance]stopAdvertising];
}

-(void)notifyDidReceiveInvitationFromPeer:(NCMCPeerID *)peerID invitationHandler:(void (^)(BOOL, NCMCSession*, NCMCPeerID *))invitationHandler
{
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(peripheralService:didReceiveInvitationFromPeer:invitationHandler:)]) {
        [self.delegate peripheralService:self didReceiveInvitationFromPeer:peerID invitationHandler:invitationHandler];
    }
}

-(void)notifyDidNotStartAdvertising:(NSError *)error
{
    if (self.delegate != nil && [self.delegate respondsToSelector:@selector(peripheralService:didNotStartAdvertising:)]) {
        [self.delegate peripheralService:self didNotStartAdvertising:error];
    }
}

@end

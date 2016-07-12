//
//  NCMCSession+Core.h
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-21.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NCMCSession.h"
#import "NCMCDeviceInfo.h"

@interface NCMCSession()

@property (strong, nonatomic)NSString* serviceID;
@property (assign, nonatomic)char myUniqueID;
@property (strong, nonatomic)NSMutableDictionary<NSString*, NCMCDeviceInfo*> *connectedDevices;

-(void)notifyPeerStateChanged:(NCMCPeerID *)peerID newState:(NCMCSessionState)state;
-(void)notifyDidReceiveData:(NSData *)data fromPeer:(NCMCPeerID *)peerID;

-(void)onDataReceived:(NSData *)data from:(NSString *)identifier;
-(void)onPeripheralDisconnected:(NSString *)identifier; // used by central
-(void)onCentralDisconnected; // used by perihearal

-(void)sendCentralConnectionRequestToPeer:(NCMCPeerID *)peerID;

-(void)setSelfAsCentral;
-(NSString*)getCentralDeviceIdentifier;

@end

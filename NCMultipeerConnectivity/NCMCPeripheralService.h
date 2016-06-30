//
//  NCMCPeripheralService.h
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-20.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NCMCSession.h"
#import "NCMCPeerID.h"

@protocol NCMCPeripheralServiceDelegate;

NS_ASSUME_NONNULL_BEGIN
@interface NCMCPeripheralService : NSObject
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithSession:(NCMCSession*)session NS_DESIGNATED_INITIALIZER;

- (Boolean)startAdvertisingPeer;// before call this function, should check isDeviceReady, otherwise this function would return NO

- (void)stopAdvertisingPeer;

- (Boolean)isDeviceReady;

@property (weak, NS_NONATOMIC_IOSONLY, nullable) id<NCMCPeripheralServiceDelegate> delegate;

@end

@protocol NCMCPeripheralServiceDelegate <NSObject>

- (void) peripheralService:(NCMCPeripheralService *)peripheralService
         didReceiveInvitationFromPeer:(NCMCPeerID *)peerID
         invitationHandler:(void (^)(BOOL accept, NCMCSession *session, NCMCPeerID *peerID))invitationHandler;

- (void)peripheralService:(NCMCPeripheralService *)peripheralService didNotStartAdvertising:(NSError *)error;

@end

NS_ASSUME_NONNULL_END

//
//  NCMCPeripheralInfo.h
//  NCMultipeerConnectivity
//
//  Created by Chengzhao Li on 2016-06-21.
//  Copyright © 2016 Apportable. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface NCMCPeripheralInfo : NSObject
@property(strong, nonatomic)CBPeripheral *peripheral;
@property (strong, nonatomic) CBCharacteristic *readCharacteristic;
@property (strong, nonatomic) CBCharacteristic *writeCharacteristic;
@property(strong, nonatomic)NSString *name;
@end

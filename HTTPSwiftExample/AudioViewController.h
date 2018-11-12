//
//  AudioViewController.h
//  HTTPSwiftExample
//
//  Created by Jian Guo on 11/10/18.
//  Copyright © 2018 Eric Larson. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import "Novocaine.h"
#import "CircularBuffer.h"

NS_ASSUME_NONNULL_BEGIN

@interface AudioViewController : UIViewController
@property (strong, nonatomic) Novocaine *audioManager;
@property (strong, nonatomic) CircularBuffer *buffer;

@end

NS_ASSUME_NONNULL_END

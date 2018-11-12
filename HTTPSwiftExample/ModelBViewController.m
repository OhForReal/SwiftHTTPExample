//
//  ModelBViewController.m
//  HTTPSwiftExample
//
//  Created by Jian Guo on 11/11/18.
//  Copyright © 2018 Eric Larson. All rights reserved.
//

#import "ModelBViewController.h"
#import "RandomForestAccel.h"
#import "DecisionTreeAccel.h"
#import "GradientBoostingAccel.h"
#import "Novocaine.h"
#import "CircularBuffer.h"

#define BUFFER_SIZE 4096
#define kDeltaOfFrequency 44100.0/4096.0/2


@interface ModelBViewController ()

@property (weak, nonatomic) IBOutlet UILabel *predictionLabel;
@property (strong, nonatomic) NSString *selectedModel;
@property (strong,nonatomic) NSURLSession *session;
@property (weak, nonatomic) NSNumber* dsid;
@property (strong, nonatomic) RandomForestAccel* rf;
@property (strong, nonatomic) DecisionTreeAccel* dt;
@property (strong, nonatomic) GradientBoostingAccel* gb;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentModel;

@end

@implementation ModelBViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.audioManager setOutputBlock:nil];
    __block ModelBViewController * __weak  weakSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];
    [self.audioManager play];
    
}

//lazy audioManager
-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
    }
    return _audioManager;
}

- (RandomForestAccel *)rf {
    if(!_rf) {
        _rf = [[RandomForestAccel alloc] init];
    }
    return _rf;
}

- (DecisionTreeAccel *)dt {
    if (!_dt) {
        _dt = [[DecisionTreeAccel alloc] init];
    }
    return _dt;
}

- (GradientBoostingAccel *)gb {
    if (!_gb) {
        _gb = [[GradientBoostingAccel alloc] init];
    }
    return _gb;
}

// lazy buffer
-(CircularBuffer*)buffer{
    if(!_buffer){
        _buffer = [[CircularBuffer alloc]initWithNumChannels:1 andBufferSize:BUFFER_SIZE];
    }
    return _buffer;
}


- (NSString *)selectedModel {
    if(!_selectedModel) {
        _selectedModel = @"RF";
    }
    return _selectedModel;
}

- (IBAction)predict:(UIButton *)sender {
    // send the server new feature data and request back a prediction of the class
    
    
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    MLMultiArrayDataType dataType = MLMultiArrayDataTypeDouble;
    NSError *error = nil;
    NSArray *shape = @[@1, @BUFFER_SIZE];
    MLMultiArray *theMultiArray =  [[MLMultiArray alloc] initWithShape:(NSArray*)shape
                                                              dataType:(MLMultiArrayDataType)dataType
                                                                 error:&error] ;
    for (int i = 0; i < BUFFER_SIZE; i++) {
        [theMultiArray setObject:[NSNumber numberWithFloat: arrayData[i]] atIndexedSubscript:(NSInteger)i];
    }
    
    if ([self.selectedModel  isEqual: @"RF"]) {
        RandomForestAccelOutput * output = [self.rf predictionFromInput:theMultiArray error:&error];
        NSLog(@"Random Forest Model output = %@ -- %@", output.classLabel, output.classProbability );
        if (!error)
        {
            NSLog(@"Random Forest finished without error");
        }
        else
        {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        _predictionLabel.text = [NSString stringWithFormat:@"Random Forest Model output = %@ -- %@", output.classLabel, output.classProbability];
    } else if ([self.selectedModel  isEqual: @"DT"]){
        DecisionTreeAccelOutput * output = [self.dt predictionFromInput:theMultiArray error:&error];
        NSLog(@"Decision Tree Model output = %@ -- %@", output.classLabel, output.classProbability );
        if (!error)
        {
            NSLog(@"Decision Tree finished without error");
        }
        else
        {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        _predictionLabel.text = [NSString stringWithFormat:@"Decision Tree Model output = %@ -- %@", output.classLabel, output.classProbability];
    } else {
        GradientBoostingAccelOutput * output = [self.gb predictionFromInput:theMultiArray error:&error];
        NSLog(@"Gradient Boosting Model output = %@ -- %@", output.classLabel, output.classProbability );
        if (!error)
        {
            NSLog(@"Gradient Boosting finished without error");
        }
        else
        {
            NSLog(@"Error: %@", error.localizedDescription);
        }
        _predictionLabel.text = [NSString stringWithFormat:@"Gradient Boosting Model output = %@ -- %@", output.classLabel, output.classProbability];
    }
    
    
    
}

- (IBAction)selectModel:(UISegmentedControl *)sender {
    self.selectedModel = [sender titleForSegmentAtIndex:sender.selectedSegmentIndex];
}

@end

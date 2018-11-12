//
//  AudioViewController.m
//  HTTPSwiftExample
//
//  Created by Jian Guo on 11/10/18.
//  Copyright © 2018 Eric Larson. All rights reserved.
//

#import "AudioViewController.h"
#import "Novocaine.h"
#import "CircularBuffer.h"
#import "DecisionTreeAccel.h"
#import "RandomForestAccel.h"

#define BUFFER_SIZE 4096
#define kDeltaOfFrequency 44100.0/4096.0/2
#define SERVER_URL "http://192.168.0.5:8000"
#define UPDATE_INTERVL 1/10.0

@interface AudioViewController ()
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentControl;

@property (weak, nonatomic) IBOutlet UILabel *predictionLabel;
@property (strong, nonatomic) NSString *type;
@property (strong,nonatomic) NSURLSession *session;
@property (weak, nonatomic) NSNumber* dsid;
@property (strong, nonatomic) RandomForestAccel* rf;
@property (strong, nonatomic) DecisionTreeAccel* dt;
@end

@implementation AudioViewController

//lazy audioManager
-(Novocaine*)audioManager{
    if(!_audioManager){
        _audioManager = [Novocaine audioManager];
    }
    return _audioManager;
}
// lazy buffer
-(CircularBuffer*)buffer{
    if(!_buffer){
        _buffer = [[CircularBuffer alloc]initWithNumChannels:1 andBufferSize:BUFFER_SIZE];
    }
    return _buffer;
}

// sharedInstance
+(AudioViewController*)sharedInstance{
    static AudioViewController * _sharedInstance = nil;
    
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate,^{
        _sharedInstance = [[AudioViewController alloc] init];
    });
    
    return _sharedInstance;
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

- (NSString *)type {
    if(!_type) {
        _type = @"Dog";
    }
    return _type;
}

- (IBAction)audioSegment:(UISegmentedControl *)sender {
    self.type = [sender titleForSegmentAtIndex:sender.selectedSegmentIndex];

}

- (IBAction)updateModel:(UIButton *)sender {
    
    NSString *baseURL = [NSString stringWithFormat:@"%s/UpdateModel",SERVER_URL];
    NSString *query = [NSString stringWithFormat:@"?dsid=%d",[self.dsid intValue]];
    
    NSURL *getUrl = [NSURL URLWithString: [baseURL stringByAppendingString:query]];
    NSURLSessionDataTask *dataTask = [self.session dataTaskWithURL:getUrl
     completionHandler:^(NSData *data,
                         NSURLResponse *response,
                         NSError *error) {
         if(!error){
             // we should get back the accuracy of the model
             NSLog(@"%@",response);
             NSDictionary *responseData = [NSJSONSerialization JSONObjectWithData:data options: NSJSONReadingMutableContainers error: &error];
             NSLog(@"Accuracy using resubstitution: %@",responseData[@"resubAccuracy"]);
         }
     }];
    [dataTask resume]; // start the task
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.audioManager setOutputBlock:nil];
    __block AudioViewController * __weak  weakSelf = self;
    [self.audioManager setInputBlock:^(float *data, UInt32 numFrames, UInt32 numChannels){
        [weakSelf.buffer addNewFloatData:data withNumSamples:numFrames];
    }];
    [self.audioManager play];
    //setup NSURLSession (ephemeral)
    NSURLSessionConfiguration *sessionConfig =
    [NSURLSessionConfiguration ephemeralSessionConfiguration];
    
    sessionConfig.timeoutIntervalForRequest = 5.0;
    sessionConfig.timeoutIntervalForResource = 8.0;
    sessionConfig.HTTPMaximumConnectionsPerHost = 1;
    
    self.session =
    [NSURLSession sessionWithConfiguration:sessionConfig
                                  delegate:self
                             delegateQueue:nil];
    self.dsid = @5;
}

- (IBAction)addDataPoint:(UIButton *)sender {
    NSString *baseURL = [NSString stringWithFormat:@"%s/AddDataPoint",SERVER_URL];
    NSURL *postUrl = [NSURL URLWithString:baseURL];
    
    
    // make an array of feature data
    // and place inside a dictionary with the label and dsid
    NSError *error = nil;
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    NSMutableArray *myArray = [NSMutableArray array];
    for(int i = 0; i < BUFFER_SIZE; i++) {
        [myArray addObject:@(arrayData[i])];
    }
    NSDictionary *jsonUpload = @{@"feature":myArray,
                                 @"label":self.type,
                                 @"dsid":self.dsid};
    
    NSData *requestBody=[NSJSONSerialization dataWithJSONObject:jsonUpload options:NSJSONWritingPrettyPrinted error:&error];
    
    // create a custom HTTP POST request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:postUrl];
    
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:requestBody];
    
    // start the request, print the responses etc.
    NSURLSessionDataTask *postTask = [self.session dataTaskWithRequest:request
     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
         if(!error){
             NSLog(@"%@",response);
             NSDictionary *responseData = [NSJSONSerialization JSONObjectWithData:data options: NSJSONReadingMutableContainers error: &error];
             
             // we should get back the feature data from the server and the label it parsed
             NSString *featuresResponse = [NSString stringWithFormat:@"%@",[responseData valueForKey:@"feature"]];
             NSString *labelResponse = [NSString stringWithFormat:@"%@",[responseData valueForKey:@"label"]];
             NSLog(@"received %@ and %@",featuresResponse,labelResponse);
         }
     }];
    [postTask resume];
    free(arrayData);
}
- (IBAction)predict:(UIButton *)sender {
    // send the server new feature data and request back a prediction of the class
    
    // setup the url
    NSString *baseURL = [NSString stringWithFormat:@"%s/PredictOne",SERVER_URL];
    NSURL *postUrl = [NSURL URLWithString:baseURL];
    
    float* arrayData = malloc(sizeof(float)*BUFFER_SIZE);
    [self.buffer fetchFreshData:arrayData withNumSamples:BUFFER_SIZE];
    NSMutableArray *myArray = [NSMutableArray array];
    for(int i = 0; i < BUFFER_SIZE; i++) {
        [myArray addObject:@(arrayData[i])];
    }
    
    // data to send in body of post request (send arguments as json)
    NSError *error = nil;
    NSDictionary *jsonUpload = @{@"feature":myArray,
                                 @"dsid":self.dsid};
    
    NSData *requestBody=[NSJSONSerialization dataWithJSONObject:jsonUpload options:NSJSONWritingPrettyPrinted error:&error];
    
    // create a custom HTTP POST request
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:postUrl];
    
    [request setHTTPMethod:@"POST"];
    [request setHTTPBody:requestBody];
    
    // start the request, print the responses etc.
    NSURLSessionDataTask *postTask = [self.session dataTaskWithRequest:request
     completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
         if(!error){
             NSDictionary *responseData = [NSJSONSerialization JSONObjectWithData:data options: NSJSONReadingMutableContainers error: &error];
             
             NSString *labelResponse = [NSString stringWithFormat:@"%@",[responseData valueForKey:@"prediction"]];
             NSLog(@"%@",labelResponse);
             
             dispatch_async(dispatch_get_main_queue(), ^{
                 _predictionLabel.text = labelResponse;
             });
         }
     }];
    [postTask resume];
}

@end

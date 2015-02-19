//
//  LSQRCodeScannerController.m
//  LayerSample
//
//  Created by Kevin Coleman on 2/14/15.
//  Copyright (c) 2015 Layer, Inc. All rights reserved.
//

#import "LSQRCodeScannerController.h"
#import <AVFoundation/AVFoundation.h>
#import "LSOverlayView.h"
#import "LSRegistrationViewController.h"
#import "ATLMLayerClient.h"
#import "ATLMUtilities.h"

@interface LSQRCodeScannerController () <AVCaptureMetadataOutputObjectsDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic) BOOL isReading;

@end

@implementation LSQRCodeScannerController

NSString *const ATLMDidReceiveLayerAppID = @"ATLMDidRecieveLayerAppID";

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.isReading = NO;
    
    [self setupCaptureSession];
    [self setupOverlay];
    [self startStopReading];
    
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    [self.view addGestureRecognizer:recognizer];
}

- (void)handleTap
{
    [self setupLayerWithAppID:nil];
}

- (void)setupOverlay
{
    LSOverlayView *overlayView = [[LSOverlayView alloc] initWithFrame:self.view.frame];
    [self.view addSubview:overlayView];
}

- (void)setupCaptureSession
{
    NSError *error;
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice error:&error];
    if (!input) {
        NSLog(@"%@", [error localizedDescription]);
        return;
    }
    
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession addInput:input];
    
    AVCaptureMetadataOutput *captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [self.captureSession addOutput:captureMetadataOutput];
    
    dispatch_queue_t dispatchQueue;
    dispatchQueue = dispatch_queue_create("capture-queue", NULL);
    [captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatchQueue];
    [captureMetadataOutput setMetadataObjectTypes:[NSArray arrayWithObject:AVMetadataObjectTypeQRCode]];
    
    self.videoPreviewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    [self.videoPreviewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [self.videoPreviewLayer setFrame:self.view.layer.bounds];
    [self.view.layer addSublayer:self.videoPreviewLayer];
}

- (void)startStopReading
{
    if (!_isReading) {
        [self startReading];
    } else {
        [self stopReading];
    }
    _isReading = !_isReading;
}

- (void)startReading
{
    [self.captureSession startRunning];
}

-(void)stopReading
{
    [self.captureSession stopRunning];
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
    if (metadataObjects != nil && [metadataObjects count] > 0) {
        AVMetadataMachineReadableCodeObject *metadataObj = [metadataObjects objectAtIndex:0];
        if ([[metadataObj type] isEqualToString:AVMetadataObjectTypeQRCode]) {
            NSLog(@"%@", metadataObj.stringValue);
            dispatch_async(dispatch_get_main_queue(), ^{
                [self stopReading];
                [self setupLayerWithAppID:metadataObj.stringValue];
            });
            _isReading = NO;
        }
    }
}

- (void)setupLayerWithAppID:(NSString *)appID
{
    [[NSUserDefaults standardUserDefaults] setValue:appID forKey:ATLMLayerApplicationID];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:ATLMDidReceiveLayerAppID object:appID];
    
    [self presentRegistrationViewController];
}

- (void)presentRegistrationViewController
{
    LSRegistrationViewController *controller = [[LSRegistrationViewController alloc] init];
    controller.applicationController = self.applicationController;
    [self.navigationController pushViewController:controller animated:YES];
}

@end
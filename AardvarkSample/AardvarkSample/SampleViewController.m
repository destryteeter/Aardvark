//
//  SampleViewController.m
//  AardvarkSample
//
//  Created by Dan Federman on 10/11/14.
//  Copyright (c) 2014 Square, Inc. All rights reserved.
//

#import <Aardvark/ARKDefaultLogFormatter.h>
#import <Aardvark/ARKEmailBugReporter.h>
#import <Aardvark/ARKLogTableViewController.h>
#import <Aardvark/ARKLogMessage.h>
#import <Aardvark/ARKLogStore.h>

#import "SampleAppDelegate.h"
#import "SampleViewController.h"


NSString *const SampleViewControllerTapLogKey = @"SampleViewControllerTapLog";


@interface SampleViewController ()

@property (nonatomic, readwrite, strong) ARKLogStore *tapGestureLogStore;
@property (nonatomic, strong, readwrite) UITapGestureRecognizer *tapRecognizer;

@end


@implementation SampleViewController

#pragma mark - UIViewController

- (void)viewDidLoad;
{
    [super viewDidLoad];
    
    self.tapGestureLogStore = [ARKLogStore new];
    self.tapGestureLogStore.name = @"Taps";
    
    // Ensure that the tap log store will only store tap logs.
    self.tapGestureLogStore.observeLogPredicate = ^(ARKLogMessage *logMessage) {
        return [logMessage.userInfo[SampleViewControllerTapLogKey] boolValue];
    };
    
    // Do not log tap logs to the main tap log store.
    [ARKLogDistributor defaultDistributor].defaultLogStore.observeLogPredicate = ^(ARKLogMessage *logMessage) {
        return (BOOL)![logMessage.userInfo[SampleViewControllerTapLogKey] boolValue];
    };
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportDirectory = paths.firstObject;
    self.tapGestureLogStore.persistedLogsFileURL = [NSURL fileURLWithPath:[applicationSupportDirectory stringByAppendingPathComponent:@"SampleTapLogs.data"]];
    
    [[ARKLogDistributor defaultDistributor] addLogObserver:self.tapGestureLogStore];
    
    ARKEmailBugReporter *bugReporter = ((SampleAppDelegate *)[UIApplication sharedApplication].delegate).bugReporter;
    [bugReporter addLogStores:@[self.tapGestureLogStore]];
}

- (void)viewDidAppear:(BOOL)animated;
{
    ARKLog(@"%s", __PRETTY_FUNCTION__);
    
    self.tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tapDetected:)];
    self.tapRecognizer.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:self.tapRecognizer];
    
    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated;
{
    ARKLog(@"%s", __PRETTY_FUNCTION__);
    
    [self.tapRecognizer.view removeGestureRecognizer:self.tapRecognizer];
    self.tapRecognizer = nil;
    
    [super viewDidDisappear:animated];
}

#pragma mark - Actions

- (IBAction)viewARKLogMessages:(id)sender;
{
    ARKLog(@"%s", __PRETTY_FUNCTION__);
    ARKLogTableViewController *defaultLogsViewController = [ARKLogTableViewController new];
    [self.navigationController pushViewController:defaultLogsViewController animated:YES];
}

- (IBAction)viewTapLogs:(id)sender;
{
    ARKLog(@"%s", __PRETTY_FUNCTION__);
    ARKLogTableViewController *tapLogsViewController = [[ARKLogTableViewController alloc] initWithLogStore:self.tapGestureLogStore logFormatter:[ARKDefaultLogFormatter new]];
    [self.navigationController pushViewController:tapLogsViewController animated:YES];
}

- (IBAction)blueButtonPressed:(id)sender;
{
    ARKLog(@"Blue");
}

- (IBAction)redButtonPressed:(id)sender;
{
    ARKLog(@"Red");
}

- (IBAction)greenButtonPressed:(id)sender;
{
    ARKLog(@"Green");
}

- (IBAction)yellowButtonPressed:(id)sender;
{
    ARKLog(@"Yellow");
}

#pragma mark - Private Methods

- (void)_tapDetected:(UITapGestureRecognizer *)tapRecognizer;
{
    if (tapRecognizer == self.tapRecognizer && tapRecognizer.state == UIGestureRecognizerStateEnded) {
        ARKTypeLog(ARKLogTypeDefault, @{ SampleViewControllerTapLogKey : @YES }, @"Tapped %@", NSStringFromCGPoint([tapRecognizer locationInView:nil]));
    }
}

@end

//
//  ARKLogDistributorTests.m
//  Aardvark
//
//  Created by Dan Federman on 10/5/14.
//  Copyright (c) 2014 Square, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>

#import "ARKLogDistributor.h"
#import "ARKLogDistributor_Testing.h"
#import "ARKLogMessage.h"
#import "ARKLogObserver.h"
#import "ARKLogStore.h"


@interface ARKLogDistributorTests : XCTestCase

@property (nonatomic, weak, readwrite) ARKLogDistributor *defaultLogDistributor;
@property (nonatomic, weak, readwrite) ARKLogStore *logStore;

@end


typedef void (^LogHandlingBlock)(ARKLogMessage *logMessage);


@interface ARKTestLogObserver : NSObject <ARKLogObserver>

@property (nonatomic, copy, readwrite) LogHandlingBlock logHandlingBlock;

@end


@implementation ARKTestLogObserver

- (void)observeLogMessage:(ARKLogMessage *)logMessage;
{
    if (self.logHandlingBlock) {
        self.logHandlingBlock(logMessage);
    }
}

@end


@interface ARKLogMessageTestSubclass : ARKLogMessage
@end

@implementation ARKLogMessageTestSubclass
@end


@implementation ARKLogDistributorTests

#pragma mark - Setup

- (void)setUp;
{
    [super setUp];
    
    self.defaultLogDistributor = [ARKLogDistributor defaultDistributor];
    
    ARKLogStore *logStore = [ARKLogStore new];
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *applicationSupportDirectory = paths.firstObject;
    logStore.persistedLogsFileURL = [NSURL fileURLWithPath:[[applicationSupportDirectory stringByAppendingPathComponent:[NSBundle mainBundle].bundleIdentifier] stringByAppendingPathComponent:@"ARKLogDistributorTests.data"]];
    
    [ARKLogDistributor defaultDistributor].defaultLogStore = logStore;
    
    self.logStore = logStore;
}

- (void)tearDown;
{
    [self.logStore clearLogs];
    
    // Wait for logs to be cleared.
    (void)[self.logStore allLogMessages];
    
    // Remove the default store.
    [ARKLogDistributor defaultDistributor].defaultLogStore = nil;
    
    [super tearDown];
}

#pragma mark - Behavior Tests

- (void)test_setLogMessageClass_appendedLogsAreCorrectClass;
{
    ARKLogDistributor *logDistributor = [ARKLogDistributor new];
    [logDistributor addLogObserver:self.logStore];
    
    [logDistributor logWithFormat:@"This log should be an ARKLogMessage"];
    
    [logDistributor.logDistributingQueue waitUntilAllOperationsAreFinished];
    
    XCTAssertEqual(self.logStore.allLogMessages.count, 1);
    XCTAssertEqual([self.logStore.allLogMessages.firstObject class], [ARKLogMessage class]);
    
    [self.logStore clearLogs];
    XCTAssertEqual(self.logStore.allLogMessages.count, 0);
    
    logDistributor.logMessageClass = [ARKLogMessageTestSubclass class];
    [logDistributor logWithFormat:@"This log should be an ARKLogMessageTestSubclass"];
    
    [logDistributor.logDistributingQueue waitUntilAllOperationsAreFinished];
    
    XCTAssertEqual(self.logStore.allLogMessages.count, 1);
    XCTAssertEqual([self.logStore.allLogMessages.firstObject class], [ARKLogMessageTestSubclass class]);
}

- (void)test_logWithFormat_callsLogObservers;
{
    ARKLogDistributor *logDistributor = [ARKLogDistributor new];
    
    NSMutableArray *logObserverTest = [NSMutableArray new];
    ARKTestLogObserver *testLogObserver = [ARKTestLogObserver new];
    testLogObserver.logHandlingBlock = ^(ARKLogMessage *logMessage) {
        [logObserverTest addObject:logMessage];
    };
    [logDistributor addLogObserver:testLogObserver];
    
    [logDistributor logWithFormat:@"Log"];
    
    [logDistributor.logDistributingQueue waitUntilAllOperationsAreFinished];
    XCTAssertEqual(logObserverTest.count, 1);
}

- (void)test_addLogObserver_notifiesLogObserverOnlog;
{
    NSMutableArray *logObserverTest = [NSMutableArray new];
    ARKTestLogObserver *testLogObserver = [ARKTestLogObserver new];
    testLogObserver.logHandlingBlock = ^(ARKLogMessage *logMessage) {
        [logObserverTest addObject:logMessage];
    };
    [self.defaultLogDistributor addLogObserver:testLogObserver];
    
    XCTAssertEqual(logObserverTest.count, 0);
    
    for (NSUInteger i  = 0; i < self.logStore.maximumLogMessageCount; i++) {
        ARKLog(@"Log %@", @(i));
    }
    
    XCTAssertGreaterThan(self.logStore.allLogMessages.count, 0);
    [self.logStore.allLogMessages enumerateObjectsUsingBlock:^(ARKLogMessage *logMessage, NSUInteger idx, BOOL *stop) {
        XCTAssertEqualObjects(logMessage, logObserverTest[idx]);
    }];
    
    [self.defaultLogDistributor removeLogObserver:testLogObserver];
}

- (void)test_removeLogHandler_removesLogObserver;
{
    ARKLogDistributor *logDistributor = [ARKLogDistributor new];
    
    NSMutableArray *logObserverTest = [NSMutableArray new];
    ARKTestLogObserver *testLogObserver = [ARKTestLogObserver new];
    testLogObserver.logHandlingBlock = ^(ARKLogMessage *logMessage) {
        [logObserverTest addObject:logMessage];
    };
    
    [logDistributor addLogObserver:testLogObserver];
    [logDistributor.logDistributingQueue waitUntilAllOperationsAreFinished];
    
    XCTAssertEqual(logDistributor.logObservers.count, 1);
    
    [logDistributor removeLogObserver:testLogObserver];
    [logDistributor.logDistributingQueue waitUntilAllOperationsAreFinished];
    
    XCTAssertEqual(logDistributor.logObservers.count, 0);
    
    for (NSUInteger i  = 0; i < 100; i++) {
        [logDistributor logWithFormat:@"Log %@", @(i)];
    }
    
    [logDistributor.logDistributingQueue waitUntilAllOperationsAreFinished];
    XCTAssertEqual(logObserverTest.count, 0);
}

- (void)test_flushLogDistributingQueue_finishesAppendingLogs;
{
    NSMutableArray *numbers = [NSMutableArray new];
    for (NSUInteger i  = 0; i < 100; i++) {
        [numbers addObject:[NSString stringWithFormat:@"%@", @(i)]];
    }
    
    [numbers enumerateObjectsUsingBlock:^(NSString *text, NSUInteger idx, BOOL *stop) {
        ARKLog(@"%@", text);
        XCTAssertEqualObjects([(ARKLogMessage *)self.logStore.allLogMessages.lastObject text], text);
    }];
}

@end

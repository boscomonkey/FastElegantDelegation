//
//  FEDProxyTests.m
//  FEDelegation
//
//  Created by Yan Rabovik on 17.04.13.
//  Copyright (c) 2013 Yan Rabovik. All rights reserved.
//

#import "FEDTests.h"

#pragma mark - PROXY TESTS -

@interface FEDProxyTests : FEDTests
@property (nonatomic,strong) FEDExampleDelegate *strongDelegate;
@property (nonatomic,strong) id strongProxy;
@end

@implementation FEDProxyTests{
    
}

#pragma mark - Setup
-(void)setUp{
    [super setUp];
    _strongDelegate = [FEDExampleDelegate new];
    _strongProxy = [FEDProxy proxyWithDelegate:_strongDelegate
                                      protocol:@protocol(FEDExampleProtocol)];
}

-(void)tearDown{
    _strongDelegate = nil;
    _strongProxy = nil;
    [super tearDown];
}

#pragma mark - Signatures
-(void)runMethodSignatureTestForSelector:(SEL)selector{
    NSMethodSignature *delegateSignature =
        [self.strongDelegate methodSignatureForSelector:selector];
    NSMethodSignature *proxySignature = [self.strongProxy methodSignatureForSelector:selector];
    XCTAssertNotNil(delegateSignature,
                   @"Selector: %@",
                   NSStringFromSelector(selector));
    XCTAssertNotNil(proxySignature,
                   @"Selector: %@",
                   NSStringFromSelector(selector));
    XCTAssertEqualObjects(delegateSignature,
                         proxySignature,
                         @"Selector: %@",
                         NSStringFromSelector(selector));
}

-(void)testMethodSignatures{
    // required
    [self runMethodSignatureTestForSelector:@selector(requiredMethod)];
    // optional
    [self runMethodSignatureTestForSelector:@selector(methodWithArgument:)];
    // method in adopted protocol
    [self runMethodSignatureTestForSelector:@selector(self)];
}

-(void)testSignatureForNonExistentSelector{
    SEL selector = @selector(selector_doesNot_exists);
    XCTAssertThrows([self.strongProxy methodSignatureForSelector:selector],@"");
}

-(void)testMethodsInProtocol{
    RTProtocol *protocol = [RTProtocol
                            protocolWithObjCProtocol:@protocol(FEDExampleProtocol)];
    NSArray *methods = [[protocol methodsRequired:YES instance:YES incorporated:YES]
                        arrayByAddingObjectsFromArray:
                        [protocol methodsRequired:NO instance:YES incorporated:YES]];
    for (RTMethod *method in methods) {
        NSLog(@"%@",method.selectorName);
    }
}

#pragma mark - Delegation
-(void)testRequiredImplementedMethod{
    XCTAssertTrue(13 == [self.strongProxy requiredMethodReturns13], @"");
}

-(void)testOptionalImplementedMethod{
    XCTAssertTrue(42 == [self.strongProxy parentOptionalMethodReturns42], @"");
}

-(void)testNotImplementedMethods{
    id __attribute__((objc_precise_lifetime)) delegate = [NSObject new];
    id proxy = [FEDProxy
                proxyWithDelegate:delegate
                protocol:@protocol(FEDExampleProtocolWithNotExistentMethods)];
    XCTAssertThrows([proxy requiredNotImplementedMethod], @"");
    XCTAssertNoThrow([proxy optionalNotImplementedMethod], @"");
    // test method not present in protocol
    XCTAssertThrows([proxy testNotImplementedMethods], @"");
}

-(void)testRespondsToSelector{
    XCTAssertTrue([self.strongProxy respondsToSelector:@selector(requiredMethodReturns13)], @"");
    XCTAssertTrue([self.strongProxy
                  respondsToSelector:@selector(parentOptionalMethodReturns42)], @"");
    XCTAssertFalse([self.strongProxy
                   respondsToSelector:@selector(optionalNotImplementedMethod)], @"");
}

#pragma mark - Weak references compatibility
// see http://stackoverflow.com/questions/13800136/nsproxy-weak-reference-bug-under-arc-on-ios-5
-(void)testWeakReferencesCompatibilityOnIOS5{
    __weak id weakProxy = self.strongProxy;
    XCTAssertNotNil(weakProxy, @"");
}

#pragma mark - Retaining
-(void)testRetainedByDelegate{
    __weak id weakProxy;
    @autoreleasepool {
        id proxy = [FEDProxy proxyWithDelegate:self.strongDelegate
                                      protocol:@protocol(FEDExampleProtocol)
                            retainedByDelegate:YES];
        weakProxy = proxy;
    }
    id strongProxy = weakProxy;
    XCTAssertNotNil(strongProxy, @"");
}

-(void)testTwoProxiesRetainedByOneDelegate{
    __weak id weakProxy1;
    __weak id weakProxy2;
    @autoreleasepool {
        id proxy1 = [FEDProxy proxyWithDelegate:self.strongDelegate
                                       protocol:@protocol(FEDExampleProtocol)
                             retainedByDelegate:YES];
        id proxy2 = [FEDProxy proxyWithDelegate:self.strongDelegate
                                       protocol:@protocol(FEDExampleProtocol)
                             retainedByDelegate:YES];
        weakProxy1 = proxy1;
        weakProxy2 = proxy2;
    }
    id strongProxy1 = weakProxy1;
    id strongProxy2 = weakProxy2;
    XCTAssertNotNil(strongProxy1, @"");
    XCTAssertNotNil(strongProxy2, @"");
}

-(void)testRetainDelegate{
    id proxy;
    @autoreleasepool {
        FEDExampleDelegate *delegate = [FEDExampleDelegate new];
        proxy = [FEDProxy proxyWithDelegate:delegate
                                   protocol:@protocol(FEDExampleProtocol)
                             retainDelegate:YES];
        delegate = nil;
    }
    XCTAssertTrue(42 == [proxy parentOptionalMethodReturns42], @"");
}

#pragma mark - OnDealloc
-(void)testOnDeallocBlock{
    __block BOOL dispatched = NO;
    @autoreleasepool {
        id proxy = [FEDProxy proxyWithDelegate:[NSObject new]
                                      protocol:@protocol(FEDExampleProtocol)
                            retainedByDelegate:YES
                                     onDealloc:^{
                                         dispatched = YES;
                                     }];
        proxy = nil;
    }
    XCTAssertTrue(dispatched, @"");
}

@end

#pragma mark - DELAGATOR TESTS -

@interface FEDProxyDelegatorTests : FEDTests
@property (nonatomic,strong) FEDExampleDelegator *delegator;
@property (nonatomic,strong) FEDExampleDelegate *strongDelegate;
@end

@implementation FEDProxyDelegatorTests{
    NSLock *lock;
    BOOL _testDone;
    NSUInteger _testStep;
}

#pragma mark - Setup
- (void)waitForCompletion:(NSTimeInterval)timeoutSecs{
    NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:timeoutSecs];
    do{
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:timeoutDate];
        if ([timeoutDate timeIntervalSinceNow] < 0.0){
            XCTFail(@"TimeOut");
            break;
        }
    }
    while (!_testDone);
}

-(void)setUp{
    [super setUp];
    _delegator = [FEDExampleDelegator new];
    _strongDelegate = [FEDExampleDelegate new];
    _testDone = NO;
    _testStep = 0;
}

-(void)tearDown{
    _strongDelegate = nil;
    _delegator = nil;
    [super tearDown];
}

#pragma mark - Tests
-(void)testDelegatorWorks{
    @autoreleasepool {
        self.delegator.delegate = self.strongDelegate;
        self.delegator.strongDelegate = [FEDExampleDelegate new];
    }
    XCTAssertTrue(42 == [self.delegator parentOptionalMethodReturns42], @"");
    XCTAssertTrue(42 == [self.delegator.strongDelegate parentOptionalMethodReturns42],@"");
    XCTAssertNoThrow([self.delegator.delegate parentOptionalMethod], @"");
    XCTAssertNoThrow([self.delegator.strongDelegate parentOptionalMethod], @"");
}

-(void)testDelegateIsAliveIfProxyIsAlive{
    lock = [NSLock new];
    [lock lock];
    XCTAssertTrue(1 == ++_testStep, @"");
    // Step 1. Create real delegate;
    __block id delegate = [FEDExampleDelegate new];
    @autoreleasepool {
        self.delegator.delegate = delegate;
    }
    [self
     performSelectorInBackground:@selector(delegateIsAliveIfProxyIsAliveBackgroundTest)
     withObject:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.01 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
        XCTAssertTrue(3 == ++_testStep, @"");
        // Step 3. Destroy real delegate
        delegate = nil;
        [lock unlock];
    });
    [self waitForCompletion:5];
    XCTAssertTrue(5 == ++_testStep, @"");
    // Step 5. Finish test.
    lock = nil;
}

-(void)delegateIsAliveIfProxyIsAliveBackgroundTest{
    XCTAssertTrue(2 == ++_testStep, @"");
    // Step 2. Save strong reference to proxy;
    id delegate = self.delegator.delegate;
    [lock lock];
    XCTAssertTrue(4 == ++_testStep, @"");
    // Step 4. Normally real delegate should be nil here.
    // But we extended it's lifetime in delegator's 'delegate' getter
    // so it is still alive
    XCTAssertTrue(42 == [delegate parentOptionalMethodReturns42], @"");
    [lock unlock];
    dispatch_async(dispatch_get_main_queue(), ^{
        _testDone = YES;
    });
}


@end

//
//  FEDHelpers.m
//  FEDelegation
//
//  Created by Yan Rabovik on 17.04.13.
//  Copyright (c) 2013 Yan Rabovik. All rights reserved.
//

#import "FEDHelpers.h"
#import "FEDProxy.h"
#import "FEDMultiProxy.h"

@implementation FEDExampleDelegate

-(void)requiredMethod{};

-(int)requiredMethodReturns13{
    return 13;
}

-(int)parentOptionalMethodReturns42{
    return 42;
}

@end

@implementation FEDExampleDelegator
fed_use_proxy_for_delegate
fed_use_proxy_for_property(strongDelegate,setStrongDelegate)

-(int)parentOptionalMethodReturns42{
    return [self.delegate parentOptionalMethodReturns42];
}

@end

@implementation FEDExamplePerson{
    NSString *_name;
    NSUInteger _age;
}

+(id)personWithName:(NSString *)name age:(NSUInteger)age{
    FEDExamplePerson *person = [[self alloc] init];
    person->_name = [name copy];
    person->_age = age;
    return person;
}

-(NSString *)name{
    return _name;
}

-(NSUInteger)age{
    return _age;
}

@end

@implementation FEDExampleMultiDelegator

-(id)delegates{
    static char key;
    id proxy;
    @synchronized(self){
        proxy = [FEDRuntime associatedObjectFromTarget:self withKey:&key];
        if (nil == proxy) {
            proxy = [FEDMultiProxy proxyWithProtocol:@protocol(FEDExamplePersonProtocol)];
            [FEDRuntime associateRetainedObject:proxy toObject:self withKey:&key];
        }
    }
    return proxy;
}

-(void)addDelegate:(id<FEDExamplePersonProtocol>)delegate{
    [self.delegates addDelegate:delegate];
}

-(void)removeDelegate:(id<FEDExamplePersonProtocol>)delegate{
    [self.delegates removeDelegate:delegate];
}

-(NSArray *)names{
    NSMutableArray *array = [NSMutableArray array];
    [[self.delegates mapToArray:array] name];
    return array;
}

-(NSUInteger)maxAge{
    __block NSUInteger maxAge = 0;
    [[self.delegates mapToBlock:^(NSInvocation *invocation) {
        NSUInteger age;
        [invocation getReturnValue:&age];
        maxAge = MAX(maxAge,age);
    }] age];
    return maxAge;
}

@end

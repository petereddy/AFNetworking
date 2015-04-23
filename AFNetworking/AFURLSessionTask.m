// AFHTTPSessionTask.m
//
// Copyright (c) 2013-2015 AFNetworking (http://afnetworking.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "AFURLSessionTask.h"

#pragma mark -

/*
 A workaround for issues related to key-value observing the `state` of an `NSURLSessionTask`.
 
 See https://github.com/AFNetworking/AFNetworking/issues/1477
 */

static inline void af_swizzleSelector(Class class, SEL originalSelector, SEL swizzledSelector) {
  Method originalMethod = class_getInstanceMethod(class, originalSelector);
  Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
  if (class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
    class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
  } else {
    method_exchangeImplementations(originalMethod, swizzledMethod);
  }
}

static inline void af_addMethod(Class class, SEL selector, Method method) {
  class_addMethod(class, selector,  method_getImplementation(method),  method_getTypeEncoding(method));
}

@interface NSURLSessionTask (_AFStateObserving)
@end

@implementation NSURLSessionTask (_AFStateObserving)

+ (void)load {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if ([NSURLSessionDataTask class]) {
      NSURLSessionDataTask *dataTask = [[NSURLSession sessionWithConfiguration:nil] dataTaskWithURL:nil];
      Class taskClass = [dataTask superclass];
      
      af_addMethod(taskClass, @selector(af_resume),  class_getInstanceMethod(self, @selector(af_resume)));
      af_addMethod(taskClass, @selector(af_suspend), class_getInstanceMethod(self, @selector(af_suspend)));
      af_swizzleSelector(taskClass, @selector(resume), @selector(af_resume));
      af_swizzleSelector(taskClass, @selector(suspend), @selector(af_suspend));
      
      [dataTask cancel];
    }
  });
}

#pragma mark -

- (void)af_resume {
  NSURLSessionTaskState state = self.state;
  [self af_resume];
  
  if (state != NSURLSessionTaskStateRunning) {
    [[NSNotificationCenter defaultCenter] postNotificationName:AFNSURLSessionTaskDidResumeNotification object:self];
  }
}

- (void)af_suspend {
  NSURLSessionTaskState state = self.state;
  [self af_suspend];
  
  if (state != NSURLSessionTaskStateSuspended) {
    [[NSNotificationCenter defaultCenter] postNotificationName:AFNSURLSessionTaskDidSuspendNotification object:self];
  }
}

@end

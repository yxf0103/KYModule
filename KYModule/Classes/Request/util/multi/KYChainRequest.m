//
//  KYChainRequest.m
//  AFNetworking
//
//  Created by yxf on 2020/8/8.
//

#import "KYChainRequest.h"

@interface KYChainRequest ()

@property (nonatomic,copy)NSArray<KYRequest *> *requestArr;

@property (nonatomic,weak)KYRequest *currentRequest;

@property (nonatomic,strong)dispatch_semaphore_t sema;

@end

@implementation KYChainRequest

-(instancetype)initWithRequestArr:(NSArray<KYRequest *> *)requestArr{
    if (self = [super init]) {
        _requestArr = [requestArr copy];
    }
    return self;
}

-(dispatch_semaphore_t)sema{
    if (!_sema) {
        _sema = dispatch_semaphore_create(1);
    }
    return _sema;
}

///每个子请求都会通过completion回调，因此需要区别处理
-(NSURLSessionTask *)startRequestWithCompletion:(KYRequestComplete)completion{
    NSString *queueName = [NSString stringWithFormat:@"ky_chain_request_queue_%p",self];
    dispatch_queue_t queue = dispatch_queue_create(queueName.UTF8String, DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        BOOL *shouldContinue = NULL;
        *shouldContinue = YES;
        [self.requestArr enumerateObjectsUsingBlock:^(KYRequest * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            dispatch_semaphore_wait(self.sema, DISPATCH_TIME_FOREVER);
            if (!shouldContinue) {
                *stop = YES;
                dispatch_semaphore_signal(self.sema);
                return;
            }
            self.currentRequest = obj;
            [obj startRequestWithCompletion:^(KYRequest * _Nullable request, NSDictionary * _Nullable result, NSError * _Nullable error) {
//                if (request != obj) {
//                    !completion ? : completion(request,result,error);
//                    return;
//                }
                if (error.code == NSURLErrorCancelled) {
                    *shouldContinue = NO;
                    dispatch_semaphore_signal(self.sema);
                    return;
                }
                !completion ? : completion(request,result,error);
                *shouldContinue = request.shouldContinue;
                dispatch_semaphore_signal(self.sema);
            }];
        }];
        if (*shouldContinue) {
            dispatch_sync(dispatch_get_main_queue(), ^{
                !completion ? : completion(self,@{},nil);
            });
        }
    });
    return nil;
}

-(void)cancel{
    [_currentRequest cancel];
}

@end

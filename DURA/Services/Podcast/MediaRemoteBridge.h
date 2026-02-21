#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C bridge to the private MediaRemote framework for reading
/// other apps' now-playing state. This uses dlopen/dlsym and WILL be
/// rejected by App Store review. For personal use only.
///
/// To make App Store compatible, replace this with a manual-entry UI
/// or share-link parser in NowPlayingService.swift.
@interface MediaRemoteBridge : NSObject

+ (void)getNowPlayingInfoWithCompletion:(void (^)(NSDictionary * _Nullable info))completion;

@end

NS_ASSUME_NONNULL_END

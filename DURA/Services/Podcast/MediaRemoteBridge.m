#import "MediaRemoteBridge.h"
#import <dlfcn.h>

// Function pointer type for MRMediaRemoteGetNowPlayingInfo
typedef void (*MRMediaRemoteGetNowPlayingInfoFunction)(dispatch_queue_t queue, void (^handler)(NSDictionary *info));

@implementation MediaRemoteBridge

+ (void)getNowPlayingInfoWithCompletion:(void (^)(NSDictionary * _Nullable))completion {
    // Load the private MediaRemote framework
    void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    if (!handle) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil);
        });
        return;
    }

    // Resolve the MRMediaRemoteGetNowPlayingInfo symbol
    MRMediaRemoteGetNowPlayingInfoFunction getNowPlayingInfo =
        (MRMediaRemoteGetNowPlayingInfoFunction)dlsym(handle, "MRMediaRemoteGetNowPlayingInfo");

    if (!getNowPlayingInfo) {
        dlclose(handle);
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil);
        });
        return;
    }

    // Call the private API on a background queue
    getNowPlayingInfo(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^(NSDictionary *info) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(info);
        });
    });
}

@end

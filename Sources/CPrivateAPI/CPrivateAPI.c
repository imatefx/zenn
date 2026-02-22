#include "CPrivateAPI.h"
#include <dlfcn.h>

// Private API declaration — available without SIP disable
extern AXError _AXUIElementGetWindow(AXUIElementRef element, CGWindowID *outWindowID);

// CGS function types resolved via dlsym at runtime
typedef int (*CGSDefaultConnection_t)(void);
typedef CGError (*CGSOrderWindow_t)(int cid, CGWindowID wid, int order, CGWindowID relativeToWID);

static CGSDefaultConnection_t _CGSDefaultConnection = NULL;
static CGSOrderWindow_t _CGSOrderWindow = NULL;
static bool _cgs_resolved = false;

static void resolve_cgs_functions(void) {
    if (_cgs_resolved) return;
    _cgs_resolved = true;

    void *handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
    if (!handle) return;

    _CGSDefaultConnection = (CGSDefaultConnection_t)dlsym(handle, "CGSDefaultConnection");
    _CGSOrderWindow = (CGSOrderWindow_t)dlsym(handle, "CGSOrderWindow");
}

CGWindowID CPrivateAPI_GetWindowID(AXUIElementRef element) {
    CGWindowID windowID = 0;
    AXError error = _AXUIElementGetWindow(element, &windowID);
    if (error != kAXErrorSuccess) {
        return 0; // kCGNullWindowID
    }
    return windowID;
}

bool CPrivateAPI_HideWindow(CGWindowID windowID) {
    resolve_cgs_functions();
    if (!_CGSDefaultConnection || !_CGSOrderWindow) return false;
    int cid = _CGSDefaultConnection();
    return _CGSOrderWindow(cid, windowID, 0 /*kCGSOrderOut*/, 0) == 0;
}

bool CPrivateAPI_ShowWindow(CGWindowID windowID) {
    resolve_cgs_functions();
    if (!_CGSDefaultConnection || !_CGSOrderWindow) return false;
    int cid = _CGSDefaultConnection();
    return _CGSOrderWindow(cid, windowID, 1 /*kCGSOrderAbove*/, 0) == 0;
}

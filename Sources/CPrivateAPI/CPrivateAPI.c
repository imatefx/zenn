#include "CPrivateAPI.h"

// Private API declaration — available without SIP disable
extern AXError _AXUIElementGetWindow(AXUIElementRef element, CGWindowID *outWindowID);

CGWindowID CPrivateAPI_GetWindowID(AXUIElementRef element) {
    CGWindowID windowID = 0;
    AXError error = _AXUIElementGetWindow(element, &windowID);
    if (error != kAXErrorSuccess) {
        return 0; // kCGNullWindowID
    }
    return windowID;
}

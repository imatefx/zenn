#ifndef CPrivateAPI_h
#define CPrivateAPI_h

#include <ApplicationServices/ApplicationServices.h>

/// Get the CGWindowID for an AXUIElement.
/// This is a private API that maps an accessibility element to its window ID.
/// Returns kCGNullWindowID (0) on failure.
CGWindowID CPrivateAPI_GetWindowID(AXUIElementRef element);

#endif /* CPrivateAPI_h */

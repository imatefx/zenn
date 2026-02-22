#ifndef CPrivateAPI_h
#define CPrivateAPI_h

#include <ApplicationServices/ApplicationServices.h>

/// Get the CGWindowID for an AXUIElement.
/// This is a private API that maps an accessibility element to its window ID.
/// Returns kCGNullWindowID (0) on failure.
CGWindowID CPrivateAPI_GetWindowID(AXUIElementRef element);

/// Hide a window by ordering it out of the visible window list.
/// Uses the private CGSOrderWindow API (does not require SIP disable).
bool CPrivateAPI_HideWindow(CGWindowID windowID);

/// Show a previously hidden window by ordering it back into the window list.
bool CPrivateAPI_ShowWindow(CGWindowID windowID);

#endif /* CPrivateAPI_h */

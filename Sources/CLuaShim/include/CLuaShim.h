#ifndef CLuaShim_h
#define CLuaShim_h

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

// Re-expose C macros as inline functions for Swift

static inline int clua_LUA_REGISTRYINDEX(void) {
    return LUA_REGISTRYINDEX;
}

static inline int clua_dostring(lua_State *L, const char *s) {
    return luaL_dostring(L, s);
}

static inline int clua_dofile(lua_State *L, const char *fn) {
    return luaL_dofile(L, fn);
}

static inline int clua_ref(lua_State *L, int t) {
    return luaL_ref(L, t);
}

static inline void clua_unref(lua_State *L, int t, int ref) {
    luaL_unref(L, t, ref);
}

static inline void clua_getmetatable(lua_State *L, const char *n) {
    lua_getfield(L, LUA_REGISTRYINDEX, n);
}

static inline int clua_pcall(lua_State *L, int nargs, int nresults, int errfunc) {
    return lua_pcallk(L, nargs, nresults, errfunc, 0, NULL);
}

#endif /* CLuaShim_h */

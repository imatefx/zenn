import Foundation
import CLua
import CLuaShim

/// The Lua registry index (from C macro LUA_REGISTRYINDEX).
let LUA_REGISTRY_IDX: Int32 = clua_LUA_REGISTRYINDEX()

/// Manages a Lua 5.4 state for configuration scripting.
public class LuaVM {
    /// The underlying Lua state.
    let L: OpaquePointer

    /// Error log.
    public var errors: [String] = []

    public init() {
        L = luaL_newstate()
        luaL_openlibs(L)
    }

    deinit {
        lua_close(L)
    }

    /// Execute a Lua string.
    @discardableResult
    public func execute(_ code: String) -> Bool {
        let result = clua_dostring(L, code)
        if result != LUA_OK {
            let error = String(cString: lua_tolstring(L, -1, nil))
            errors.append(error)
            lua_settop(L, -(1)-1) // pop error
            return false
        }
        return true
    }

    /// Execute a Lua file.
    @discardableResult
    public func executeFile(_ path: String) -> Bool {
        let result = clua_dofile(L, path)
        if result != LUA_OK {
            let error = String(cString: lua_tolstring(L, -1, nil))
            errors.append(error)
            lua_settop(L, -(1)-1) // pop error
            return false
        }
        return true
    }

    /// Push a Swift closure as a Lua function.
    public func registerFunction(name: String, function: @escaping @convention(c) (OpaquePointer?) -> Int32) {
        lua_pushcclosure(L, function, 0)
        lua_setglobal(L, name)
    }

    /// Push a string onto the Lua stack.
    public func pushString(_ value: String) {
        lua_pushstring(L, value)
    }

    /// Push a number onto the Lua stack.
    public func pushNumber(_ value: Double) {
        lua_pushnumber(L, value)
    }

    /// Push an integer onto the Lua stack.
    public func pushInteger(_ value: Int) {
        lua_pushinteger(L, lua_Integer(value))
    }

    /// Push a boolean onto the Lua stack.
    public func pushBool(_ value: Bool) {
        lua_pushboolean(L, value ? 1 : 0)
    }

    /// Push nil onto the Lua stack.
    public func pushNil() {
        lua_pushnil(L)
    }

    /// Get a string from the Lua stack.
    public func toString(at index: Int32) -> String? {
        guard lua_type(L, index) == LUA_TSTRING else { return nil }
        guard let ptr = lua_tolstring(L, index, nil) else { return nil }
        return String(cString: ptr)
    }

    /// Get a number from the Lua stack.
    public func toNumber(at index: Int32) -> Double? {
        guard lua_type(L, index) == LUA_TNUMBER else { return nil }
        return lua_tonumberx(L, index, nil)
    }

    /// Get an integer from the Lua stack.
    public func toInteger(at index: Int32) -> Int? {
        guard lua_type(L, index) == LUA_TNUMBER else { return nil }
        return Int(lua_tointegerx(L, index, nil))
    }

    /// Get a boolean from the Lua stack.
    public func toBool(at index: Int32) -> Bool {
        lua_toboolean(L, index) != 0
    }

    /// Check if the value at an index is a function.
    public func isFunction(at index: Int32) -> Bool {
        lua_type(L, index) == LUA_TFUNCTION
    }

    /// Check if the value at an index is a table.
    public func isTable(at index: Int32) -> Bool {
        lua_type(L, index) == LUA_TTABLE
    }

    /// Get the number of elements on the stack.
    public var stackSize: Int32 {
        lua_gettop(L)
    }

    /// Pop n values from the stack.
    public func pop(_ n: Int32 = 1) {
        lua_settop(L, -(n)-1)
    }

    /// Create a new table and push it.
    public func newTable() {
        lua_createtable(L, 0, 0)
    }

    /// Set a field on the table at the top of the stack.
    public func setField(_ name: String) {
        lua_setfield(L, -2, name)
    }

    /// Get a field from the table at the given index.
    public func getField(_ name: String, from index: Int32 = -1) {
        lua_getfield(L, index, name)
    }

    /// Create a reference to the value at the top of the stack.
    public func createRef() -> Int32 {
        clua_ref(L, LUA_REGISTRY_IDX)
    }

    /// Push a referenced value onto the stack.
    public func pushRef(_ ref: Int32) {
        lua_rawgeti(L, LUA_REGISTRY_IDX, lua_Integer(ref))
    }

    /// Release a reference.
    public func releaseRef(_ ref: Int32) {
        clua_unref(L, LUA_REGISTRY_IDX, ref)
    }

    /// Call a function on the stack with given arg count and result count.
    @discardableResult
    public func call(nargs: Int32, nresults: Int32) -> Bool {
        let result = clua_pcall(L, nargs, nresults, 0)
        if result != LUA_OK {
            let error = toString(at: -1) ?? "unknown Lua error"
            errors.append(error)
            pop()
            return false
        }
        return true
    }

    /// Get a string array from a table at the given stack index.
    public func toStringArray(at index: Int32) -> [String] {
        guard isTable(at: index) else { return [] }
        var result: [String] = []
        lua_pushnil(L) // first key
        let absIndex = index < 0 ? (stackSize + index + 1) : index
        while lua_next(L, absIndex) != 0 {
            if let str = toString(at: -1) {
                result.append(str)
            }
            pop() // pop value, keep key
        }
        return result
    }

    /// Store a Swift object pointer in the Lua registry for access from C callbacks.
    public func storeSwiftObject(_ object: AnyObject, key: String) {
        let ptr = Unmanaged.passUnretained(object).toOpaque()
        lua_pushlightuserdata(L, ptr)
        lua_setfield(L, LUA_REGISTRY_IDX, key)
    }

    /// Retrieve a stored Swift object from the Lua registry.
    public func retrieveSwiftObject<T: AnyObject>(_ type: T.Type, key: String) -> T? {
        lua_getfield(L, LUA_REGISTRY_IDX, key)
        guard lua_type(L, -1) == LUA_TLIGHTUSERDATA else {
            pop()
            return nil
        }
        let ptr = lua_touserdata(L, -1)
        pop()
        guard let ptr = ptr else { return nil }
        return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
    }
}

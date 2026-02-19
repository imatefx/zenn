import XCTest
@testable import ZennLua

final class LuaVMTests: XCTestCase {

    func testExecuteSimpleCode() {
        let vm = LuaVM()
        let result = vm.execute("x = 1 + 1")
        XCTAssertTrue(result)
        XCTAssertTrue(vm.errors.isEmpty)
    }

    func testExecuteInvalidCode() {
        let vm = LuaVM()
        let result = vm.execute("this is not valid lua!!!")
        XCTAssertFalse(result)
        XCTAssertFalse(vm.errors.isEmpty)
    }

    func testPushAndReadString() {
        let vm = LuaVM()
        vm.pushString("hello")
        let str = vm.toString(at: -1)
        XCTAssertEqual(str, "hello")
        vm.pop()
    }

    func testPushAndReadNumber() {
        let vm = LuaVM()
        vm.pushNumber(42.5)
        let num = vm.toNumber(at: -1)
        XCTAssertEqual(num, 42.5)
        vm.pop()
    }

    func testPushAndReadBool() {
        let vm = LuaVM()
        vm.pushBool(true)
        XCTAssertTrue(vm.toBool(at: -1))
        vm.pop()

        vm.pushBool(false)
        XCTAssertFalse(vm.toBool(at: -1))
        vm.pop()
    }

    func testTableOperations() {
        let vm = LuaVM()
        vm.newTable()
        vm.pushString("world")
        vm.setField("hello")

        vm.getField("hello")
        let value = vm.toString(at: -1)
        XCTAssertEqual(value, "world")
    }

    func testGlobalVariable() {
        let vm = LuaVM()
        vm.execute("test_var = 'success'")
        vm.execute("_ = test_var") // push to stack
        // Access via lua code
        let result = vm.execute("assert(test_var == 'success')")
        XCTAssertTrue(result)
    }

    func testFunctionRef() {
        let vm = LuaVM()
        vm.execute("function test_fn() return 42 end")

        // Get the function
        vm.execute("return test_fn")

        // This leaves the function result on the stack
        // Let's verify it worked by checking via Lua
        let result = vm.execute("assert(test_fn() == 42)")
        XCTAssertTrue(result)
    }
}

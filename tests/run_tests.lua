local lu = require("luaunit")

-- 加载所有测试文件
require("tests.test_encoder")
require("tests.test_error")
require("tests.test_logger")
require("tests.test_handshake")

-- 运行所有测试
os.exit(lu.LuaUnit.run())

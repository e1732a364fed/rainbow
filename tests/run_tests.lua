local lu = require("luaunit")
-- local inspect = require("tests.inspect")

-- 加载所有测试文件
TestError = require("tests.test_error")
TestLogger = require("tests.test_logger")
TestMain = require("tests.test_main")
TestCompress = require("tests.test_compress")
TestUtils = require("tests.test_utils")

-- 加载 stego 目录下的测试文件
TestFontStego = require("tests.stego.test_font_stego")
TestGridStego = require("tests.stego.test_grid_stego")
TestHtmlStego = require("tests.stego.test_html_stego")
TestJsonStego = require("tests.stego.test_json_stego")
TestPrismStego = require("tests.stego.test_prism_stego")
TestRssStego = require("tests.stego.test_rss_stego")
TestSvgPathStego = require("tests.stego.test_svg_path_stego")
TestXmlStego = require("tests.stego.test_xml_stego")
TestCssStego = require("tests.stego.test_css_stego")

-- os.exit(lu.LuaUnit.run())

-- 创建简单的自定义输出
local MyOutput = lu.LuaUnit.outputType
MyOutput.verbosity = 1

function MyOutput:startTest(testName)
    print(string.format("运行测试: %s", testName))
end

function MyOutput:endTest(node)
    local status = node.status
    local testName = node.testName
    print(string.format("测试完成: %s -> %s", testName, status))
end

-- 解析命令行参数
local function parseArgs()
    local args = {}
    local run_count = 1
    local delay = 0

    local i = 1
    while i <= #arg do
        if tonumber(arg[i]) and run_count == 1 then
            run_count = tonumber(arg[i])
        elseif tonumber(arg[i]) and delay == 0 then
            delay = tonumber(arg[i])
        else
            table.insert(args, arg[i])
        end
        i = i + 1
    end

    return args, run_count, delay
end

-- 主程序
local args, run_count, delay = parseArgs()

-- 统计结果
local total_success = 0
local total_failures = 0
local total_errors = 0
local total_runs = 0

for i = 1, run_count do
    print(string.format("\n=== 第 %d/%d 次运行 ===", i, run_count))

    -- 运行测试
    local runner = lu.LuaUnit.new()
    local result = runner:runSuite(table.unpack(args))

    -- 更新统计
    if runner.result then
        total_runs = total_runs + runner.result.runCount
        total_success = total_success + runner.result.successCount
        total_failures = total_failures + runner.result.failureCount
        total_errors = total_errors + runner.result.errorCount
    end

    -- 延迟
    if i < run_count and delay > 0 then
        print(string.format("\n等待 %d 秒...", delay))
        os.execute("sleep " .. delay)
    end
end

-- 打印总结
print(string.format("\n=== 总运行统计 (%d 轮) ===", run_count))
print(string.format("总测试数: %d", total_runs))
print(string.format("成功: %d", total_success))
print(string.format("失败: %d", total_failures))
print(string.format("错误: %d", total_errors))
if total_runs > 0 then
    print(string.format("成功率: %.2f%%", (total_success / total_runs) * 100))
else
    print("成功率: 0%")
end

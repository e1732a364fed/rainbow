local lu = require("luaunit")

-- 加载所有测试文件
local TestEncoder = require("tests.test_encoder")
local TestError = require("tests.test_error")
local TestLogger = require("tests.test_logger")
local TestHandshake = require("tests.test_handshake")
local TestMain = require("tests.test_main")
local TestCompress = require("tests.test_compress")
local TestUtils = require("tests.test_utils")

-- 加载 stego 目录下的测试文件
-- local TestAudioStego = require("tests.stego.test_audio_stego") --太慢，暂时跳过
local TestFontStego = require("tests.stego.test_font_stego")
local TestGridStego = require("tests.stego.test_grid_stego")
local TestHtmlStego = require("tests.stego.test_html_stego")
local TestJsonStego = require("tests.stego.test_json_stego")
local TestPrismStego = require("tests.stego.test_prism_stego")
local TestRssStego = require("tests.stego.test_rss_stego")
local TestSvgPathStego = require("tests.stego.test_svg_path_stego")
local TestXmlStego = require("tests.stego.test_xml_stego")
local TestCssStego = require("tests.stego.test_css_stego")

-- 运行所有测试
os.exit(lu.LuaUnit.run())

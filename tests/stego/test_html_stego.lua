local lu = require("luaunit")
local html_stego = require("rainbow.stego.html_stego")

TestHtmlStego = {}

function TestHtmlStego:test_empty_data()
    local result = html_stego.encode("")
    lu.assertNotNil(result)
    lu.assertTrue(#result > 0)
    lu.assertStrContains(result, "<!DOCTYPE html>")

    local decoded = html_stego.decode(result)
    lu.assertEquals(decoded, "")
end

function TestHtmlStego:test_normal_data()
    local test_data = "Hello, World!"
    local result = html_stego.encode(test_data)
    lu.assertNotNil(result)
    lu.assertTrue(#result > 0)
    lu.assertStrContains(result, test_data)

    local decoded = html_stego.decode(result)
    lu.assertEquals(decoded, test_data)
end

function TestHtmlStego:test_special_chars()
    local test_data = "Data with -- comment markers"
    local result = html_stego.encode(test_data)
    lu.assertNotNil(result)
    lu.assertTrue(#result > 0)

    local decoded = html_stego.decode(result)
    lu.assertEquals(decoded, test_data)
end

function TestHtmlStego:test_invalid_input()
    local decoded = html_stego.decode(nil)
    lu.assertEquals(decoded, "")

    decoded = html_stego.decode("")
    lu.assertEquals(decoded, "")

    decoded = html_stego.decode("<html><body>No comments here</body></html>")
    lu.assertEquals(decoded, "")
end

return TestHtmlStego

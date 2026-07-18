local dependency = reqscript('fixture/dependency')
local required = require('fixture.require')

result = dependency.value + required.value + global_offset

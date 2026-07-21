rockspec_format = "3.0"

package = "soulsearch"
version = "0.1.0-1"

source = {
    url = "git+https://github.com/dsisco11/SoulSearch.git",
    tag = "v0.1.0",
}

description = {
    summary = "SoulSearch is a DFHack plugin that provides a powerful search and filtering interface based on attributes for units in Dwarf Fortress.",
    detailed = [[]],
    homepage = "https://github.com/dsisco11/SoulSearch",
    license = "MIT",
}

dependencies = {
    "lua >= 5.3",
}

test_dependencies = {
    "dwarfspec ~> 0.1",
}

build = {
    type = "none",
}

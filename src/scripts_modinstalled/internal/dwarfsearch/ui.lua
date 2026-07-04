--@ module=true

local residents = reqscript('internal/dwarfsearch/residents')
local search = reqscript('internal/dwarfsearch/search')

function open(...)
    local rows, err = residents.collect_residents()
    if not rows then
        print(err)
        return
    end

    local results = search.apply(rows)
    local descriptors = search.get_filter_descriptors()
    print(('DwarfSearch collected %d residents and prepared %d trait filters and %d mental attribute filters. The search panel will be implemented in Phase 4.'):format(
        #results,
        #descriptors.traits,
        #descriptors.mental_attributes))
end

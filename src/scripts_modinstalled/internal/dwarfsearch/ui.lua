--@ module=true

local residents = reqscript('internal/dwarfsearch/residents')

function open(...)
    local rows, err = residents.collect_residents()
    if not rows then
        print(err)
        return
    end

    print(('DwarfSearch collected %d residents. The search panel will be implemented in Phase 4.'):format(#rows))
end

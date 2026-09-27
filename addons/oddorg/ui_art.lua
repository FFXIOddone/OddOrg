-- Measured atlas regions; generated rows are not assumed to be an exact grid.
local art = { width=1448, height=1086 }
local names = {
    {'inventory', 'satchel', 'sack', 'case'},
    {'safe', 'safe2', 'storage', 'locker'},
    {'wardrobe', 'moogle', 'locked', 'ignored'},
}
local rows = { {0,325}, {325,675}, {675,1040} }
art.destinations = {}
for row, entries in ipairs(names) do
    for col, name in ipairs(entries) do
        local x, y = (col-1)*362, rows[row][1]
        art.destinations[name] = { x/1448, y/1086, (x+362)/1448, rows[row][2]/1086 }
    end
end
art.surfaces = {
    panel={0.002,0.002,0.498,0.498}, slot={0.502,0.002,0.998,0.498},
    button={0.002,0.502,0.498,0.998}, route={0.502,0.502,0.998,0.998},
}
art.bags = {
    [0]='inventory', [1]='safe', [2]='storage', [4]='locker',
    [5]='satchel', [6]='sack', [7]='case', [8]='wardrobe', [9]='safe2',
    [10]='wardrobe', [11]='wardrobe', [12]='wardrobe', [13]='wardrobe',
    [14]='wardrobe', [15]='wardrobe', [16]='wardrobe',
}
return art

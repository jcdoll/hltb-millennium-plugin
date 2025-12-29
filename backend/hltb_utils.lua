--[[
    HLTB String Utilities

    Provides string manipulation functions for game name matching:
    - sanitize_game_name: Remove trademark symbols for comparison
    - simplify_game_name: Strip edition suffixes for fallback search
    - levenshtein_distance: Calculate edit distance between strings
    - calculate_similarity: Compute 0.0-1.0 similarity score
    - seconds_to_hours: Convert HLTB time values to hours
]]

local M = {}

-- Calculate Levenshtein distance between two strings
function M.levenshtein_distance(s1, s2)
    local len1, len2 = #s1, #s2
    local matrix = {}

    for i = 0, len1 do
        matrix[i] = { [0] = i }
    end
    for j = 0, len2 do
        matrix[0][j] = j
    end

    for i = 1, len1 do
        for j = 1, len2 do
            local cost = (s1:sub(i, i) == s2:sub(j, j)) and 0 or 1
            matrix[i][j] = math.min(
                matrix[i - 1][j] + 1,
                matrix[i][j - 1] + 1,
                matrix[i - 1][j - 1] + cost
            )
        end
    end

    return matrix[len1][len2]
end

-- Sanitize game name for comparison (remove TM/copyright symbols)
function M.sanitize_game_name(name)
    name = name:gsub("™", "")
    name = name:gsub("®", "")
    name = name:gsub("©", "")
    name = name:gsub("%s+", " ")
    name = name:match("^%s*(.-)%s*$") or name
    return name
end

--[[
    Simplify game name for fallback search by stripping common suffixes.

    Stripped patterns:
    - Edition suffixes: Enhanced, Complete, Definitive, Ultimate, Special, Legacy, Maximum, GOTY
    - Anniversary Edition (including "40th Anniversary Edition" etc.)
    - Remastered, Director's Cut, Collection
    - Year tags: (2013), (2020), etc.
    - Trailing punctuation: dashes, colons

    Loops until no more changes to handle stacked suffixes like "Enhanced Edition Director's Cut".
]]
function M.simplify_game_name(name)
    -- Normalize Unicode dashes to ASCII hyphen for pattern matching
    name = name:gsub("–", "-")  -- en-dash U+2013
    name = name:gsub("—", "-")  -- em-dash U+2014

    -- Loop until no more changes
    local prev
    repeat
        prev = name

        -- Anniversary patterns (longer patterns first)
        name = name:gsub("%s+%d+[snrt][tdh]%s+[Aa]nniversary%s+[Ee]dition$", "")
        name = name:gsub("%s+[-:]%s*[Aa]nniversary%s+[Ee]dition$", "")
        name = name:gsub("%s+[Aa]nniversary%s+[Ee]dition$", "")

        -- Edition suffixes (with optional dash/colon prefix)
        name = name:gsub("%s+[-:]%s*[Ee]nhanced%s+[Ee]dition$", "")
        name = name:gsub("%s+[Ee]nhanced%s+[Ee]dition$", "")
        name = name:gsub("%s+[-:]%s*[Cc]omplete%s+[Ee]dition$", "")
        name = name:gsub("%s+[Cc]omplete%s+[Ee]dition$", "")
        name = name:gsub("%s+[-:]%s*[Dd]efinitive%s+[Ee]dition$", "")
        name = name:gsub("%s+[Dd]efinitive%s+[Ee]dition$", "")
        name = name:gsub("%s+[-:]%s*[Uu]ltimate%s+[Ee]dition$", "")
        name = name:gsub("%s+[Uu]ltimate%s+[Ee]dition$", "")
        name = name:gsub("%s+[-:]%s*[Ss]pecial%s+[Ee]dition$", "")
        name = name:gsub("%s+[Ss]pecial%s+[Ee]dition$", "")
        name = name:gsub("%s+[-:]%s*[Ll]egacy%s+[Ee]dition$", "")
        name = name:gsub("%s+[Ll]egacy%s+[Ee]dition$", "")
        name = name:gsub("%s+[-:]%s*[Mm]aximum%s+[Ee]dition$", "")
        name = name:gsub("%s+[Mm]aximum%s+[Ee]dition$", "")
        name = name:gsub("%s+[-:]%s*GOTY%s*[Ee]?d?i?t?i?o?n?$", "")
        name = name:gsub("%s+[-:]%s*[Gg]ame%s+of%s+the%s+[Yy]ear%s*[Ee]?d?i?t?i?o?n?$", "")

        -- Remastered
        name = name:gsub("%s+[-:]%s*[Rr]emastered$", "")
        name = name:gsub("%s+[Rr]emastered$", "")

        -- Director's Cut
        name = name:gsub("%s+[-:]%s*[Dd]irector'?s?%s+[Cc]ut$", "")
        name = name:gsub("%s+[Dd]irector'?s?%s+[Cc]ut$", "")

        -- Collection
        name = name:gsub("%s+[Cc]ollection$", "")

        -- Year tags at end: (2013), (2020), etc.
        name = name:gsub("%s+%([12][09]%d%d%)$", "")

        -- Clean up trailing punctuation left after stripping (e.g., trailing " -")
        name = name:gsub("%s*[-:]%s*$", "")
    until name == prev

    -- Clean up whitespace
    name = name:gsub("%s+", " ")
    name = name:match("^%s*(.-)%s*$") or name

    return name
end

-- Calculate similarity between two strings (0.0 to 1.0)
function M.calculate_similarity(s1, s2)
    local norm_s1 = M.sanitize_game_name(s1):lower()
    local norm_s2 = M.sanitize_game_name(s2):lower()

    if norm_s1 == "" or norm_s2 == "" then
        return 0
    end

    if norm_s1 == norm_s2 then
        return 1.0
    end

    local distance = M.levenshtein_distance(norm_s1, norm_s2)
    local max_len = math.max(#norm_s1, #norm_s2)
    local similarity = 1.0 - (distance / max_len)

    return math.floor(similarity * 100) / 100
end

-- Convert seconds to hours (1 decimal place), nil for 0/missing
function M.seconds_to_hours(seconds)
    if not seconds or seconds <= 0 then
        return nil
    end
    return math.floor((seconds / 3600) * 10 + 0.5) / 10
end

return M

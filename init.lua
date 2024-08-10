-- Globals
tmtrainer = {
  settings = {
    swaps_per_item = tonumber(minetest.settings:get("tmtrainer.swaps_per_node",3) or 4),
    global_seed = tonumber(minetest.settings:get("tmtrainer.global_seed",0) or 0),
  },
  storage = minetest.get_mod_storage(),
}

-- Load + save seed
tmtrainer.seed = tonumber(tmtrainer.storage:get("seed") or (tmtrainer.settings.global_seed == 0 and math.random(1,4294967295) or tmtrainer.settings.global_seed))
tmtrainer.storage:set_int("seed",tmtrainer.seed)

-- Gibberish characters for extra scrambled text
local gibberish = {
  "!","¯","░","^","&","*","%","◙","-","_","€",
  "+","/",".","·"," ","`","ə",":","¾","?","¿",
  "œ","Œ","~","½","⅓","™","©","®","Æ","¬","¶",
  "§","≠","▄","&","◆","。","°"," ","●","」","æ",
  "▒","±","∞","—","$","0","Þ","²","³","1","2",
  "3","4","5","6","7","8","9","»","«","£","¥",
  "「","…","¹","¤"," "," "," "," "," ","¸","¡",
  "※","█","‽","▀","□","⇐","⇒",
}

-- Slice up a string into multiple glitchy substrings
local function glitchy_strings(s,rng)
  local gs = {}
  local slen = #s

  if slen < 5 then
    return {s}
  end

  for i = 1, rng:next(3,6) do
    local split = rng:next(3,slen - 2)
    local gstr = s:sub(rng:next(1,split),rng:next(split,slen))
    gstr = gstr:sub(1,8)
    local gsplice = rng:next(1,#gstr)
    gstr = gstr:sub(1,gsplice) .. gibberish[rng:next(1,#gibberish)] .. gstr:sub(gsplice + 1)
    table.insert(gs,gstr)
  end
  return gs
end

-- Get a random color
local hex = {"1","2","3","4","5","6","7","8","9","0","a","b","c","d","e","f"}
local function random_color(rng)
  local color = "#"
  for i = 1, 6 do
    color = color .. hex[rng:next(1,16)]
  end
  return color
end

-- Effects for scrambling textures
local texture_effects = {
  function() return "^[invert:rgb" end,
  function() return "^[brighten" end,
  function() return "^[transformFXR90" end,
  function() return "^[transformFYR90" end,
  function(rng) return "^[hsl:" .. rng:next(-180,180) .. ":" .. rng:next(0,150) .. ":" .. rng:next(-20,20) end,
  function(rng) return "^[multiply:" .. random_color(rng) end,
  function(rng) return "^[screen:" .. random_color(rng) end,
  function(rng) return "^[colorize:" .. random_color(rng) .. ":" .. rng:next(100,150) end,
  function(rng) return "^[lowpart:" .. rng:next(10,20) .. ":blank.png" end,
  function(rng,t)
    local offset = rng:next(4,12)
    return "^[combine:16x16:" .. offset .. "," .. offset .. "=" .. t .. "^[invert:rgb"
  end,
}

local function scramble_texture(t,rng)
  local scrambled = t:gsub("[()]","")
  for i = 1, rng:next(1,2) do
    scrambled = scrambled .. texture_effects[rng:next(1,#texture_effects)](rng,t)
  end
  return scrambled
end

-- Slice up a texture into multiple glitchy textures
local function glitchy_textures(t,rng)
  local gt = {}
  for _,texture in ipairs(t) do
    if type(texture) == "string" then
      table.insert(gt,scramble_texture(texture,rng))
    elseif type(texture) == "table" then
      local tile = table.copy(texture)
      tile.name = scramble_texture(texture.name or texture.image,rng)
      texture.image = nil
      tile.color = random_color(rng)
      table.insert(gt,tile)
    end
  end
  return gt
end

-- Combine multiple glitchy textures into one frankentexture
local function frankentexture(textures,rng)
  local ft = textures[1]:gsub("^","\\^")
  for i = #textures, 2, -1 do
    local texture = textures[i]
    if texture:find("%[inventorycube") then
      texture = texture:split("{")[rng:next(2,3)]
    end
    ft = ft .. "^[lowpart:" .. rng:next(20,40) .. ":" .. texture:gsub("^","\\^")
    ft = ft .. (rng:next(1,2) == 1 and "^[transformFYR90" or "^[transformFXR90")
  end
  ft = ft:sub(3):gsub("[()]","")
  return ft
end

minetest.register_on_mods_loaded(function()
  -- Get a random number generator based on the world seed
  local rng = PcgRandom(tmtrainer.seed)

  -- Use a holding array for all items and their relevant metadata
  local a = {}
  local alen = 0

  -- Use a set to collect all available node sounds
  local soundset = {}
  local sounds = {}
  soundslen = 0

  -- Collect the internal names of all items and nodes
  for name,def in pairs(minetest.registered_items) do
    if def.drawtype ~= "airlike" and name ~= "" then
      alen = alen + 1
      a[alen] = name
    end
  end

  -- Sort the list of item names
  table.sort(a)

  -- Process the list of items
  for i,name in ipairs(a) do
    -- Get item definition
    local def = minetest.registered_items[name]

    -- Store relevant item metadata
    a[i] = {
      name = name,
      description = def.description and glitchy_strings(def.description:gsub("%cE?",""):gsub("^%(.+%)",""),rng) or glitchy_strings(placeholder,rng),
      short_description = def.short_description and glitchy_strings(def.short_description,rng) or nil,
      inventory_image = def.inventory_image and #def.inventory_image > 0 and scramble_texture(def.inventory_image,rng) or nil,
      tiles = glitchy_textures(def.tiles or (def.inventory_image and {def.inventory_image} or (def.wield_image and {def.wield_image} or {"no_texture.png"})),rng),
      special_tiles = def.special_tiles and glitchy_textures(def.special_tiles,rng) or nil,
      overlay_tiles = def.overlay_tiles and glitchy_textures(def.overlay_tiles,rng) or nil,
      post_effect_color = def.post_effect_color,
      swaps = (function()
        local s = {}
        for i = 1, tmtrainer.settings.swaps_per_item do
          table.insert(s,rng:next(1,32768))
        end
        return s
      end)(),
    }

    -- Collect item sounds
    if def.sounds then
      for _,sound in ipairs({
        "footstep",
        "dig",
        "dug",
        "place",
        "place_failed",
        "fall",
      }) do
        sound = def.sounds[sound]
        if sound then
          if type(sound) == "string" and sound ~= "" then
            soundset[sound] = true
          elseif type(sound) == "table" and sound.name and sound.name ~= "" then
            soundset[sound.name] = true
          end
        end
      end
    end
  end

  -- Process sound set into list
  for sound,_ in pairs(soundset) do
    table.insert(sounds,sound)
    soundslen = soundslen + 1
  end

  -- Sort sounds list
  table.sort(sounds)

  -- Get a random sound
  local function random_sound()
    return {
      name = sounds[rng:next(1,soundslen)],
      gain = 10 / rng:next(30,50),
      pitch = 100 / rng:next(50,400),
    }
  end

  -- Override items with shuffled counterparts
  for i = 1, alen do
    local item = a[i]
    local swaps = {}
    for i = 1, tmtrainer.settings.swaps_per_item do
      swaps[i] = a[item.swaps[i] % alen + 1]
    end

    -- Random Swap Selector™ over n swaps
    local function rss(n,fn)
      local r = rng:next(1,#swaps)
      local s = {}
      local slen = #swaps
      for i = r, r + math.min(n,tmtrainer.settings.swaps_per_item) do
        table.insert(s,swaps[i % slen + 1])
      end
      return fn(s)
    end

    -- Override the item with scrambled descriptions, textures, and sounds
    minetest.override_item(item.name,{
      use_texture_alpha = "clip",
      description = rss(3,function(s)
        local d = ""
        for _,swap in ipairs(s) do
          d = d .. swap.description[rng:next(1,#swap.description)]
        end
        return d
      end),
      short_description = item.short_description and rss(3,function(s)
        local d = ""
        for _,swap in ipairs(s) do
          if d.short_description then
            d = d .. swap.short_description[rng:next(1,#swap.short_description)]
          else
            d = d .. swap.description[rng:next(1,#swap.description)]
          end
        end
        return d
      end) or nil,
      inventory_image = item.inventory_image and rss(2,function(s)
        local t = {}
        for _,i in ipairs(s) do
          table.insert(t,i.inventory_image or (i.tiles and (i.tiles[1].name or i.tiles[1])) or "no_texture.png")
        end
        return frankentexture(t,rng)
      end) or nil,
      wield_image = "",
      wield_overlay = "",
      tiles = minetest.registered_nodes[item.name] and rss(2,function(s)
        local t = {}
        local ss = {}
        for _,i in ipairs(s) do
          local tile = i.tiles[rng:next(1,#i.tiles)]
          table.insert(ss,tile.name or tile)
        end
        for i = 1, #item.tiles do
          if item.tiles[i].name or item.tiles[i].image then
            local tile = table.copy(item.tiles[i])
            tile.image = nil
            tile.animation = nil
            tile.name = frankentexture(ss,rng)
            tile.color = random_color(rng)
            table.insert(t,tile)
          else
            table.insert(t,frankentexture(ss,rng))
          end
        end
        return t
      end) or nil,
      special_tiles = item.special_tiles and rss(2,function(s)
        local t = {}
        local ss = {}
        for _,i in ipairs(s) do
          local tile = i.tiles[rng:next(1,#i.tiles)]
          table.insert(ss,tile.name or tile)
        end
        for i = 1, #item.special_tiles do
          if item.special_tiles[i].name or item.special_tiles[i].image then
            local tile = table.copy(item.special_tiles[i])
            tile.image = nil
            tile.animation = nil
            tile.name = frankentexture(ss,rng)
            tile.color = random_color(rng)
            table.insert(t,tile)
          else
            table.insert(t,frankentexture(ss,rng))
          end
        end
        return t
      end) or nil,
      overlay_tiles = item.overlay_tiles and rss(2,function(s)
        local t = {}
        local ss = {}
        for _,i in ipairs(s) do
          local tile = i.tiles[rng:next(1,#i.tiles)]
          table.insert(ss,tile.name or tile)
        end
        for i = 1, #item.overlay_tiles do
          if item.overlay_tiles[i].name or item.overlay_tiles[i].image then
            local tile = table.copy(item.overlay_tiles[i])
            tile.image = nil
            tile.animation = nil
            tile.name = frankentexture(ss,rng)
            tile.color = random_color(rng)
            table.insert(t,tile)
          else
            table.insert(t,frankentexture(ss,rng))
          end
        end
        return t
      end) or nil,
      sounds = minetest.registered_nodes[item.name] and (function()
        local soundlist = {}
        for _,sound in ipairs({
          "footstep",
          "dig",
          "dug",
          "place",
          "place_failed",
          "fall",
        }) do
          soundlist[sound] = random_sound()
        end
        return soundlist
      end)() or nil,
      post_effect_color = item.post_effect_color and {
        a = item.post_effect_color.a,
        r = rng:next(0,255),
        g = rng:next(0,255),
        b = rng:next(0,255),
      } or nil,
    })
  end

  -- Set parameters for random sky, sun, and moon
  local random_env = {
    sky = {
      type = "regular",
      clouds = false,
      sky_color = {
        day_sky = random_color(rng),
        day_horizon = random_color(rng),
        dawn_sky = random_color(rng),
        dawn_horizon = random_color(rng),
        night_sky = random_color(rng),
        night_horizon = random_color(rng),
        indoors = random_color(rng),
        fog_sun_tint = random_color(rng),
        fog_moon_tint = random_color(rng),
      },
      fog = {
        fog_color = random_color(rng),
        fog_distance = 99999999,
        fog_start = 0.99,
      },
    },
    sun = {
      texture = (function()
        local t = a[rng:next(1,alen)]
        return t.inventory_image or (t.tiles and (t.tiles[1].name or t.tiles[1])) or "no_texture.png"
      end)(),
      scale = 20 / rng:next(10,25),
      sunrise_visible = false,
    },
    moon = {
      texture = (function()
        local t = a[rng:next(1,alen)]
        return t.inventory_image or (t.tiles and (t.tiles[1].name or t.tiles[1])) or "no_texture.png"
      end)(),
      scale = 20 / rng:next(10,25),
    },
    stars = {
      visible = false,
    },
  }

  -- Separate random number generator for player and entity overrides
  local erng = PcgRandom(tmtrainer.seed)

  -- Set player sky and textures
  minetest.register_on_joinplayer(function(player)
    player:set_sky(random_env.sky)
    player:set_sun(random_env.sun)
    player:set_moon(random_env.moon)
    player:set_stars(random_env.stars)
    local textures = player:get_properties().textures
    player:set_properties({
      textures = (function()
        local rt = {}
        local s = (function()
          local r = erng:next(1,alen)
          local s = {}
          for i = 1, #textures do
            table.insert(s,a[(r + 1) % alen + 1])
          end
          return s
        end)()
        local ss = {}
        for _,i in ipairs(s) do
          local tile = i.tiles[erng:next(1,#i.tiles)]
          table.insert(ss,tile.name or tile)
        end
        for i = 1, #textures do
          table.insert(rt,(function(texture)
            if texture.name or texture.image then
              local tile = table.copy(texture)
              tile.image = nil
              tile.animation = nil
              tile.name = frankentexture(ss,erng)
              tile.color = random_color(erng)
              return tile
            else
              return frankentexture(ss,erng)
            end
          end)(textures[i]))
        end
        return rt
      end)(),
    })
  end)

  -- Identify registered entity definitions
  local e = {}
  for name,entity in pairs(minetest.registered_entities) do
    table.insert(e,name)
  end

  -- Sort entity table
  table.sort(e)

  -- Process entities
  for _,entity in ipairs(e) do
    entity = minetest.registered_entities[entity]
    local ogoa = entity.on_activate or function() end
    entity.on_activate = function(self,...)
      local retval = ogoa(self,...)

      local textures
      if not (self.object and self.object:get_properties()) then
        return retval
      else
        textures = self.object:get_properties().textures
      end

      if textures then
        local rt = {}
        local s = (function()
          local r = erng:next(1,alen)
          local s = {}
          for i = 1, #textures do
            table.insert(s,a[(r + 1) % alen + 1])
          end
          return s
        end)()
        local t = {}
        local ss = {}
        for _,i in ipairs(s) do
          local tile = i.tiles[erng:next(1,#i.tiles)]
          table.insert(ss,tile.name or tile)
        end
        for i = 1, #textures do
          table.insert(rt,(function(texture)
            if texture.name or texture.image then
              local tile = table.copy(texture)
              tile.image = nil
              tile.animation = nil
              tile.name = frankentexture(ss,erng)
              tile.color = random_color(erng)
              return tile
            else
              return frankentexture(ss,erng)
            end
          end)(textures[i]))
        end
        self.object:set_properties({
          textures = rt,
        })
      end
      return retval
    end
  end
end)

-- Register /tmtrainer privilege
minetest.register_privilege("tmtrainer",{
  description = "Privilege required to use the /tmtrainer command",
  give_to_singleplayer = false,
  give_to_admin = true,
})

-- Register /tmtrainer command
minetest.register_chatcommand("tmtrainer",{
  params = "<seed> [value]",
  description = "interact with TMTRAINER",
  privs = { tmtrainer = true },
  func = function(name,params)
    local player = minetest.get_player_by_name(name)

    if not minetest.check_player_privs("tmtrainer") then
      return false, "You do not have the 'tmtrainer' privilege necessary to use this command."
    end

    if params == "seed" then
      return true, "Current TMTRAINER seed is " .. tmtrainer.seed
    end

    if params:find("^seed %d+$") then
      tmtrainer.seed = tonumber(params:split(' ')[2])
      tmtrainer.storage:set_int("seed",tmtrainer.seed)
      return true, "New TMTRAINER seed is " .. tmtrainer.seed
    end

    if params == "seed random" then
      tmtrainer.seed = math.random(1,4294967295)
      tmtrainer.storage:set_int("seed",tmtrainer.seed)
      return true, "New TMTRAINER seed is " .. tmtrainer.seed
    end

    return false, "Unknown or incorrect TMTRAINER command"
  end
})
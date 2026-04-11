
local library, themes = loadstring(game:HttpGet("https://raw.githubusercontent.com/lorte12/roblox-interface/main/Library.lua"))()
task.wait()

local HAS_GETGC       = type(getgc) == "function"
local HAS_MOUSE1CLICK = type(mouse1click) == "function"
local HAS_MOUSE1PRESS = type(mouse1press) == "function" and type(mouse1release) == "function"
local HAS_MOUSEMOVEREL = type(mousemoverel) == "function"
local HAS_GETSENV     = type(getsenv) == "function"
local HAS_GETCONNS    = type(getconnections) == "function"

local function capLabel(has) return has and "" or " [N/A]" end

local _executorName = "Unknown"
pcall(function()
    if identifyexecutor then _executorName = identifyexecutor() or "Unknown" end
end)

do
    local lp = game:GetService("Players").LocalPlayer
    local function waitForChar(char)
        if char then
            char:WaitForChild("Humanoid", 5)
            char:WaitForChild("HumanoidRootPart", 5)
        end
    end
    if lp.Character then
        waitForChar(lp.Character)
    else
        waitForChar(lp.CharacterAdded:Wait())
    end
    lp.CharacterAdded:Connect(waitForChar)
end
task.wait()

local dim2 = UDim2.new
local hex = Color3.fromHex

makefolder("unlock-rivals")
local DUMP_FILE   = "dump_viewmodels.json"
local DEBUG_FILE  = "unlock-rivals/unlock_debug.txt"
local CONFIG_FILE = "unlock-rivals/rivals_config.json"

local HttpService = game:GetService("HttpService")
task.wait()

local Assets = game:GetService("Players").LocalPlayer.PlayerScripts.Assets
local ViewModels = Assets.ViewModels
local WrapTextures = Assets:FindFirstChild("WrapTextures")
task.wait()

local RS = game:GetService("ReplicatedStorage")

-- Lazy-loaded modules: require() only on first access to avoid startup lag
local ViewModelSoundsModule, ItemSoundsModule
local _soundModulesLoaded = false
local function _ensureSoundModules()
    if _soundModulesLoaded then return end
    _soundModulesLoaded = true
    local ok1, r1 = pcall(require, RS.Modules.SoundLibrary.ViewModelSounds)
    local ok2, r2 = pcall(require, RS.Modules.SoundLibrary.ItemSounds)
    ViewModelSoundsModule = ok1 and r1 or {}
    ItemSoundsModule      = ok2 and r2 or {}
end
local _originalItemSounds = nil
local _originalVMSounds = nil

local AnimLibModule = nil
local AnimLibInfo   = nil
local _animLibLoaded = false
local function _ensureAnimLib()
    if _animLibLoaded then return end
    _animLibLoaded = true
    local ok, r = pcall(require, RS.Modules.AnimationLibrary)
    if ok and r then
        AnimLibModule = r
        AnimLibInfo   = r.Info or r
    end
end

local ScrapedAnimSoundsModule = nil
local _scrapedLoaded = false
local function _ensureScrapedSounds()
    if _scrapedLoaded then return end
    _scrapedLoaded = true
    local ok, r = pcall(require, RS.Modules.SoundLibrary.ScrapedAnimationSounds)
    if ok and r then ScrapedAnimSoundsModule = r end
end
task.wait()

local jsonData = {Weapons = {}, SkinCases = {}, WrapTextures = {}, WorkspacePlayer = {}}
local jsonLoaded = false

local function loadJsonData()
    local ok, result = pcall(function()
        return HttpService:JSONDecode(readfile(DUMP_FILE))
    end)
    if ok and result then
        jsonData = result
        jsonLoaded = true
    else
        jsonLoaded = false
    end
end

local function dumpViewModelsJson()
    local _Assets = game:GetService("Players").LocalPlayer.PlayerScripts.Assets
    local _ViewModels = _Assets.ViewModels
    local _Weapons = _ViewModels.Weapons

    local lines = {}
    table.insert(lines, "{")

    table.insert(lines, '  "Weapons": {')
    local _weaponList = _Weapons:GetChildren()
    for wi, weapon in ipairs(_weaponList) do
        local children = weapon:GetChildren()
        local childLines = {}
        for ci, child in ipairs(children) do
            local comma = ci < #children and "," or ""
            table.insert(childLines, string.format('      { "Name": "%s", "Class": "%s" }%s', child.Name, child.ClassName, comma))
        end
        local comma = wi < #_weaponList and "," or ""
        table.insert(lines, string.format('    "%s": [', weapon.Name))
        for _, cl in ipairs(childLines) do
            table.insert(lines, cl)
        end
        table.insert(lines, "    ]" .. comma)
    end
    table.insert(lines, "  },")
    task.wait()

    table.insert(lines, '  "SkinCases": {')
    local _folders = _ViewModels:GetChildren()
    local _skinFolders = {}
    for _, f in ipairs(_folders) do
        if f.Name ~= "Weapons" then
            table.insert(_skinFolders, f)
        end
    end
    for fi, folder in ipairs(_skinFolders) do
        local skins = folder:GetChildren()
        local comma = fi < #_skinFolders and "," or ""
        table.insert(lines, string.format('    "%s": {', folder.Name))
        for si, skin in ipairs(skins) do
            local children = skin:GetChildren()
            local childNames = {}
            for _, child in ipairs(children) do
                table.insert(childNames, string.format('"%s"', child.Name))
            end
            local skinComma = si < #skins and "," or ""
            table.insert(lines, string.format('      "%s": [%s]%s', skin.Name, table.concat(childNames, ", "), skinComma))
        end
        table.insert(lines, "    }" .. comma)
    end
    table.insert(lines, "  },")
    task.wait()

    table.insert(lines, '  "WrapTextures": {')
    local _wtOk, _wtChildren = pcall(function() return _Assets.WrapTextures:GetChildren() end)
    if _wtOk then
        for fi, folder in ipairs(_wtChildren) do
            local items = folder:GetChildren()
            local itemLines = {}
            for ii, item in ipairs(items) do
                local comma = ii < #items and "," or ""
                table.insert(itemLines, string.format('      { "Name": "%s", "Class": "%s" }%s', item.Name, item.ClassName, comma))
            end
            local comma = fi < #_wtChildren and "," or ""
            table.insert(lines, string.format('    "%s": [', folder.Name))
            for _, il in ipairs(itemLines) do
                table.insert(lines, il)
            end
            table.insert(lines, "    ]" .. comma)
        end
    end
    table.insert(lines, "  },")
    task.wait()

    table.insert(lines, '  "WorkspacePlayer": {')
    local _lp = game:GetService("Players").LocalPlayer
    local _playerFolder = workspace:FindFirstChild(_lp.Name)
    if not _playerFolder then
        _playerFolder = workspace:FindFirstChild(tostring(_lp.UserId))
    end
    if not _playerFolder then
        for _, v in ipairs(workspace:GetChildren()) do
            if string.find(v.Name, _lp.Name, 1, true) then
                _playerFolder = v
                break
            end
        end
    end
    if _playerFolder then
        table.insert(lines, string.format('  "FolderName": "%s",', _playerFolder.Name))
        table.insert(lines, '  "Children": {')
        local children = _playerFolder:GetChildren()
        for ci, child in ipairs(children) do
            local comma = ci < #children and "," or ""
            local val = ""
            if child:IsA("IntValue") or child:IsA("NumberValue") or child:IsA("StringValue") or child:IsA("BoolValue") then
                val = string.format(', "Value": "%s"', tostring(child.Value))
            end
            table.insert(lines, string.format('    "%s": { "Class": "%s"%s }%s', child.Name, child.ClassName, val, comma))
            local subChildren = child:GetChildren()
            if #subChildren > 0 then
                lines[#lines] = string.format('    "%s": { "Class": "%s"%s, "Children": {', child.Name, child.ClassName, val)
                for sci, sub in ipairs(subChildren) do
                    local subVal = ""
                    if sub:IsA("IntValue") or sub:IsA("NumberValue") or sub:IsA("StringValue") or sub:IsA("BoolValue") then
                        subVal = string.format(', "Value": "%s"', tostring(sub.Value))
                    end
                    local subComma = sci < #subChildren and "," or ""
                    table.insert(lines, string.format('      "%s": { "Class": "%s"%s }%s', sub.Name, sub.ClassName, subVal, subComma))
                end
                table.insert(lines, "    } }" .. comma)
            end
        end
        table.insert(lines, "  }")
    else
        table.insert(lines, '  "Error": "Dossier joueur introuvable dans workspace"')
    end
    table.insert(lines, "  }")

    table.insert(lines, "}")

    local json = table.concat(lines, "\n")
    writefile(DUMP_FILE, json)
end

loadJsonData()
if not jsonLoaded then
    pcall(dumpViewModelsJson)
    loadJsonData()
end
task.wait()

local TARGET_WEAPON = nil
local menuVisible = true
local _espUnlocked = false


-- ┌──────────────────────────────────────────────────────────┐
-- │  WEAPON LIST & COMPATIBILITY (pre-cached)                │
-- └──────────────────────────────────────────────────────────┘

local weaponList = {}
for name in pairs(jsonData.Weapons or {}) do
    if name ~= "Unobtainable" then
        table.insert(weaponList, name)
    end
end
table.sort(weaponList)

-- Pre-cache weapon child sets (évite de recalculer à chaque check)
local weaponChildCache = {}
for wName, children in pairs(jsonData.Weapons or {}) do
    local set, count = {}, 0
    for _, child in ipairs(children) do
        set[child.Name] = true
        count = count + 1
    end
    weaponChildCache[wName] = {set = set, count = count}
end
task.wait()


local originalColors = {}

local function getAllParts(model, result)
    result = result or {}
    for _, v in ipairs(model:GetChildren()) do
        if v:IsA("BasePart") then
            table.insert(result, v)
        elseif v:IsA("Model") or v:IsA("Folder") then
            getAllParts(v, result)
        end
    end
    return result
end

-- ┌──────────────────────────────────────────────────────────┐
-- │  IMAGE DATABASE                                          │
-- └──────────────────────────────────────────────────────────┘

local ITEMS = {
    {name="Medkit", image="rbxassetid://17160800734", hd="rbxassetid://13717497368"},
    {name="Briefcase", image="rbxassetid://18142172067", hd="rbxassetid://18142174697"},
    {name="Sandwich", image="rbxassetid://17838232333", hd="rbxassetid://17838233196"},
    {name="Laptop", image="rbxassetid://18770164868", hd="rbxassetid://18766906510"},
    {name="Bucket of Candy", image="rbxassetid://93791981490691", hd="rbxassetid://95706110401359"},
    {name="Milk & Cookies", image="rbxassetid://99156135330432", hd="rbxassetid://73601847002267"},
    {name="Medkitty", image="rbxassetid://125732280509514", hd="rbxassetid://126646607101307"},
    {name="Glorious Medkit", image="rbxassetid://73358160718523", hd="rbxassetid://73397457340415"},
    {name="Box of Chocolates", image="rbxassetid://132421415091712", hd="rbxassetid://119971229318198"},
    {name="Subspace Tripmine", image="rbxassetid://17160799418", hd="rbxassetid://17098773688"},
    {name="Don't Press", image="rbxassetid://17821233203", hd="rbxassetid://17821264419"},
    {name="Spring", image="rbxassetid://18766860615", hd="rbxassetid://18766904035"},
    {name="Trick or Treat", image="rbxassetid://101693036028491", hd="rbxassetid://105864401236960"},
    {name="Dev-in-the-Box", image="rbxassetid://125056115146240", hd="rbxassetid://93100882010950"},
    {name="DIY Tripmine", image="rbxassetid://85747991601740", hd="rbxassetid://105200997776122"},
    {name="Glorious Subspace Tripmine", image="rbxassetid://112555928142930", hd="rbxassetid://80869057489077"},
    {name="Pot o' Keys", image="rbxassetid://125355191847719", hd="rbxassetid://70372236634885"},
    {name="Flamethrower", image="rbxassetid://89455038280473", hd="rbxassetid://85223987405833"},
    {name="Pixel Flamethrower", image="rbxassetid://17771752104", hd="rbxassetid://17771753119"},
    {name="Lamethrower", image="rbxassetid://18766862822", hd="rbxassetid://18766906741"},
    {name="Jack O'Thrower", image="rbxassetid://140280020818514", hd="rbxassetid://81280342017495"},
    {name="Snowblower", image="rbxassetid://128743586418880", hd="rbxassetid://80434566532022"},
    {name="Glitterthrower", image="rbxassetid://88920581735649", hd="rbxassetid://83419562243412"},
    {name="Glorious Flamethrower", image="rbxassetid://71676635953177", hd="rbxassetid://88697784394796"},
    {name="Keythrower", image="rbxassetid://130308634220965", hd="rbxassetid://113419665254766"},
    {name="Rainbowthrower", image="rbxassetid://102070206928252", hd="rbxassetid://119525701444507"},
    {name="Grenade", image="rbxassetid://17160801411", hd="rbxassetid://14526777692"},
    {name="Whoopee Cushion", image="rbxassetid://17672062933", hd="rbxassetid://17672086704"},
    {name="Water Balloon", image="rbxassetid://18766859819", hd="rbxassetid://18769001397"},
    {name="Soul Grenade", image="rbxassetid://85903097459179", hd="rbxassetid://126980255892476"},
    {name="Jingle Grenade", image="rbxassetid://97646859596860", hd="rbxassetid://117226824301607"},
    {name="Dynamite", image="rbxassetid://119066463640901", hd="rbxassetid://97225646481020"},
    {name="Keynade", image="rbxassetid://102785971311114", hd="rbxassetid://122922810220976"},
    {name="Glorious Grenade", image="rbxassetid://103034870490455", hd="rbxassetid://102502933883025"},
    {name="Frozen Grenade", image="rbxassetid://96120996159611", hd="rbxassetid://101932886938992"},
    {name="Cuddle Bomb", image="rbxassetid://116801887274189", hd="rbxassetid://122359407681537"},
    {name="Molotov", image="rbxassetid://109264750627289", hd="rbxassetid://83303332331234"},
    {name="Coffee", image="rbxassetid://17672061538", hd="rbxassetid://17672089358"},
    {name="Torch", image="rbxassetid://115586189235552", hd="rbxassetid://120882142047198"},
    {name="Vexed Candle", image="rbxassetid://78128648928195", hd="rbxassetid://136079178184476"},
    {name="Hot Coals", image="rbxassetid://110423024723304", hd="rbxassetid://98070129509602"},
    {name="Lava Lamp", image="rbxassetid://79616583726432", hd="rbxassetid://76191080417885"},
    {name="Glorious Molotov", image="rbxassetid://108930340066987", hd="rbxassetid://95650602989880"},
    {name="Arch Molotov", image="rbxassetid://96589300342777", hd="rbxassetid://136971342091354"},
    {name="Flashbang", image="rbxassetid://17160801529", hd="rbxassetid://14664488253"},
    {name="Disco Ball", image="rbxassetid://17672061796", hd="rbxassetid://17672089136"},
    {name="Camera", image="rbxassetid://18766865640", hd="rbxassetid://18766908915"},
    {name="Pixel Flashbang", image="rbxassetid://132815625474597", hd="rbxassetid://82894448978638"},
    {name="Skullbang", image="rbxassetid://73796957224972", hd="rbxassetid://94894233513600"},
    {name="Shining Star", image="rbxassetid://108392227354212", hd="rbxassetid://73486952957582"},
    {name="Lightbulb", image="rbxassetid://125489177573287", hd="rbxassetid://78421244256536"},
    {name="Glorious Flashbang", image="rbxassetid://96760506528185", hd="rbxassetid://131190784940519"},
    {name="Smoke Grenade", image="rbxassetid://17160799767", hd="rbxassetid://16373283577"},
    {name="Emoji Cloud", image="rbxassetid://17821234077", hd="rbxassetid://17821265237"},
    {name="Balance", image="rbxassetid://18766866168", hd="rbxassetid://18766909964"},
    {name="Eyeball", image="rbxassetid://135911399763146", hd="rbxassetid://103493376163318"},
    {name="Snowglobe", image="rbxassetid://119390465944051", hd="rbxassetid://86696224913566"},
    {name="Hourglass", image="rbxassetid://108311418974073", hd="rbxassetid://70423041582442"},
    {name="Glorious Smoke Grenade", image="rbxassetid://139714146508398", hd="rbxassetid://121565824954563"},
    {name="Fists", image="rbxassetid://17160801745", hd="rbxassetid://16560051320"},
    {name="Boxing Gloves", image="rbxassetid://17672060486", hd="rbxassetid://17672089761"},
    {name="Brass Knuckles", image="rbxassetid://18766866012", hd="rbxassetid://18766909587"},
    {name="Pumpkin Claws", image="rbxassetid://90996407819750", hd="rbxassetid://110587168549532"},
    {name="Festive Fists", image="rbxassetid://102757458529795", hd="rbxassetid://98061476050478"},
    {name="Fists of Hurt", image="rbxassetid://140103672289959", hd="rbxassetid://71585039030211"},
    {name="Glorious Fists", image="rbxassetid://82492165200104", hd="rbxassetid://79755997614985"},
    {name="Fist", image="rbxassetid://109585706680035", hd="rbxassetid://78704206164484"},
    {name="Knife", image="rbxassetid://17160800983", hd="rbxassetid://13197583583"},
    {name="Chancla", image="rbxassetid://17672060795", hd="rbxassetid://17672089600"},
    {name="Karambit", image="rbxassetid://18766863586", hd="rbxassetid://18766907079"},
    {name="Machete", image="rbxassetid://84364955819899", hd="rbxassetid://90332754966135"},
    {name="Candy Cane", image="rbxassetid://124021545052910", hd="rbxassetid://84302121354096"},
    {name="Balisong", image="rbxassetid://93303458333011", hd="rbxassetid://114825371645118"},
    {name="Armature.001", image="rbxassetid://104026327618871", hd="rbxassetid://91555068782550"},
    {name="Glorious Knife", image="rbxassetid://77448895595314", hd="rbxassetid://122760026905111"},
    {name="Keyrambit", image="rbxassetid://108512337101248", hd="rbxassetid://73252950434501"},
    {name="Keylisong", image="rbxassetid://100084654831857", hd="rbxassetid://118944160521617"},
    {name="Caladbolg", image="rbxassetid://101180142582964", hd="rbxassetid://72181228743456"},
    {name="Chainsaw", image="rbxassetid://17160801873", hd="rbxassetid://13717445410"},
    {name="Blobsaw", image="rbxassetid://17825963589", hd="rbxassetid://17825961425"},
    {name="Handsaws", image="rbxassetid://18766864583", hd="rbxassetid://18769002596"},
    {name="Buzzsaw", image="rbxassetid://74057448201836", hd="rbxassetid://128354991167944"},
    {name="Festive Buzzsaw", image="rbxassetid://80811854818775", hd="rbxassetid://111566667788893"},
    {name="Mega Drill", image="rbxassetid://76663867023998", hd="rbxassetid://78828669740807"},
    {name="Glorious Chainsaw", image="rbxassetid://122622447397834", hd="rbxassetid://140353527719287"},
    {name="Katana", image="rbxassetid://17160801158", hd="rbxassetid://13968137196"},
    {name="Saber", image="rbxassetid://17672062341", hd="rbxassetid://17672087756"},
    {name="Lightning Bolt", image="rbxassetid://18768968241", hd="rbxassetid://18769002278"},
    {name="Pixel Katana", image="rbxassetid://127922483074145", hd="rbxassetid://83686692916164"},
    {name="Evil Trident", image="rbxassetid://101234805269080", hd="rbxassetid://91973056969213"},
    {name="New Year Katana", image="rbxassetid://102866488046710", hd="rbxassetid://79288379571855"},
    {name="Keytana", image="rbxassetid://118899310989170", hd="rbxassetid://120478111112813"},
    {name="Stellar Katana", image="rbxassetid://72617738655198", hd="rbxassetid://90901679194899"},
    {name="Glorious Katana", image="rbxassetid://75588958786035", hd="rbxassetid://94429900086533"},
    {name="Arch Katana", image="rbxassetid://94679283541658", hd="rbxassetid://98068422294741"},
    {name="Crystal Katana", image="rbxassetid://88872493010693", hd="rbxassetid://107573852829996"},
    {name="Linked Sword", image="rbxassetid://83575725004177", hd="rbxassetid://131281564276137"},
    {name="Scythe", image="rbxassetid://17160800186", hd="rbxassetid://13834995858"},
    {name="Scythe of Death", image="rbxassetid://17825996537", hd="rbxassetid://17825961272"},
    {name="Anchor", image="rbxassetid://18766866743", hd="rbxassetid://18769023932"},
    {name="Keythe", image="rbxassetid://114560926055433", hd="rbxassetid://75967374711732"},
    {name="Bat Scythe", image="rbxassetid://131711174838548", hd="rbxassetid://104168535403995"},
    {name="Cryo Scythe", image="rbxassetid://119930754357379", hd="rbxassetid://84690820919174"},
    {name="Bug Net", image="rbxassetid://115620701626004", hd="rbxassetid://99173928762511"},
    {name="Sakura Scythe", image="rbxassetid://133811689655966", hd="rbxassetid://115063494552764"},
    {name="Glorious Scythe", image="rbxassetid://115811939422419", hd="rbxassetid://113721128462866"},
    {name="Crystal Scythe", image="rbxassetid://73971549402646", hd="rbxassetid://88778703942724"},
    {name="Trowel", image="rbxassetid://17160799172", hd="rbxassetid://16560547384"},
    {name="Plastic Shovel", image="rbxassetid://17672062201", hd="rbxassetid://17672088012"},
    {name="Garden Shovel", image="rbxassetid://18766864873", hd="rbxassetid://18766908058"},
    {name="Pumpkin Carver", image="rbxassetid://78827307308671", hd="rbxassetid://130169648063116"},
    {name="Snow Shovel", image="rbxassetid://78271338778848", hd="rbxassetid://96400887574950"},
    {name="Paintbrush", image="rbxassetid://84687920829755", hd="rbxassetid://83196688094998"},
    {name="Glorious Trowel", image="rbxassetid://100888500368219", hd="rbxassetid://132433921578446"},
    {name="Flare Gun", image="rbxassetid://17160801627", hd="rbxassetid://13197583892"},
    {name="Firework Gun", image="rbxassetid://17691132917", hd="rbxassetid://17691136322"},
    {name="Dynamite Gun", image="rbxassetid://18766865384", hd="rbxassetid://18766908547"},
    {name="Vexed Flare Gun", image="rbxassetid://116287930550049", hd="rbxassetid://138983159218333"},
    {name="Wrapped Flare Gun", image="rbxassetid://135638020129378", hd="rbxassetid://135904023852615"},
    {name="Banana Flare", image="rbxassetid://123589213761955", hd="rbxassetid://135246839855870"},
    {name="Glorious Flare Gun", image="rbxassetid://115324763672074", hd="rbxassetid://128135635660577"},
    {name="Assault Rifle", image="rbxassetid://17160682738", hd="rbxassetid://13197584241"},
    {name="AK-47", image="rbxassetid://17691132793", hd="rbxassetid://17691136128"},
    {name="AUG", image="rbxassetid://18770192853", hd="rbxassetid://18770201102"},
    {name="Boneclaw Rifle", image="rbxassetid://100015754284323", hd="rbxassetid://116725320040796"},
    {name="AKEY-47", image="rbxassetid://80017496220683", hd="rbxassetid://77244120212187"},
    {name="Gingerbread AUG", image="rbxassetid://85584922619813", hd="rbxassetid://108476862508992"},
    {name="Phoenix Rifle", image="rbxassetid://140228738718621", hd="rbxassetid://115604025497445"},
    {name="Tommy Gun", image="rbxassetid://111251887761435", hd="rbxassetid://84369917689099"},
    {name="10B Visits", image="rbxassetid://122165086598560", hd="rbxassetid://101791753953377"},
    {name="Glorious Assault Rifle", image="rbxassetid://130669996688265", hd="rbxassetid://130592949312939"},
    {name="Handgun", image="rbxassetid://17160801282", hd="rbxassetid://13197583693"},
    {name="Blaster", image="rbxassetid://17821234554", hd="rbxassetid://17821265750"},
    {name="Hand Gun", image="rbxassetid://18837670624", hd="rbxassetid://18837677423"},
    {name="Pixel Handgun", image="rbxassetid://82199841278177", hd="rbxassetid://72665687846028"},
    {name="Pumpkin Handgun", image="rbxassetid://88495685924653", hd="rbxassetid://92824393890642"},
    {name="Gingerbread Handgun", image="rbxassetid://95881238590412", hd="rbxassetid://72714528734588"},
    {name="Gumball Handgun", image="rbxassetid://106890990556815", hd="rbxassetid://138794077251754"},
    {name="Stealth Handgun", image="rbxassetid://124919185835138", hd="rbxassetid://99321324367928"},
    {name="Glorious Handgun", image="rbxassetid://85129427786041", hd="rbxassetid://73041314820303"},
    {name="Warp Handgun", image="rbxassetid://102974911528828", hd="rbxassetid://117404871573487"},
    {name="Towerstone Handgun", image="rbxassetid://88654252790032", hd="rbxassetid://116418326352365"},
    {name="Burst Rifle", image="rbxassetid://17160801983", hd="rbxassetid://13482243466"},
    {name="Electro Rifle", image="rbxassetid://132227459821018", hd="rbxassetid://87621360986223"},
    {name="Aqua Burst", image="rbxassetid://18837670807", hd="rbxassetid://18837677725"},
    {name="Pixel Burst", image="rbxassetid://102648809593259", hd="rbxassetid://81440970309830"},
    {name="Spectral Burst", image="rbxassetid://135012309412679", hd="rbxassetid://135650382469411"},
    {name="Pine Burst", image="rbxassetid://132753732294083", hd="rbxassetid://100589243117991"},
    {name="FAMAS", image="rbxassetid://74974560606812", hd="rbxassetid://110423034763836"},
    {name="Glorious Burst Rifle", image="rbxassetid://78517330608597", hd="rbxassetid://125258150017244"},
    {name="Keyst Rifle", image="rbxassetid://78377522426003", hd="rbxassetid://138268719789353"},
    {name="Sniper", image="rbxassetid://17160799574", hd="rbxassetid://13197583098"},
    {name="Pixel Sniper", image="rbxassetid://17676081196", hd="rbxassetid://17676083400"},
    {name="Hyper Sniper", image="rbxassetid://18766864081", hd="rbxassetid://18766907266"},
    {name="Keyper", image="rbxassetid://85472935605264", hd="rbxassetid://122634584511896"},
    {name="Eyething Sniper", image="rbxassetid://103915302076013", hd="rbxassetid://96377501719526"},
    {name="Gingerbread Sniper", image="rbxassetid://99943841952995", hd="rbxassetid://120163896680390"},
    {name="Event Horizon", image="rbxassetid://80749667426815", hd="rbxassetid://82446563771968"},
    {name="Glorious Sniper", image="rbxassetid://118012090175286", hd="rbxassetid://94794978921271"},
    {name="RPG", image="rbxassetid://17160802243", hd="rbxassetid://13197583434"},
    {name="Nuke Launcher", image="rbxassetid://17672061995", hd="rbxassetid://17672088925"},
    {name="RPKEY", image="rbxassetid://108438721125410", hd="rbxassetid://122750504849596"},
    {name="Spaceship Launcher", image="rbxassetid://18766860860", hd="rbxassetid://18766904375"},
    {name="Pumpkin Launcher", image="rbxassetid://94648176067808", hd="rbxassetid://130301464984534"},
    {name="Firework Launcher", image="rbxassetid://75233372670156", hd="rbxassetid://93131277391830"},
    {name="Squid Launcher", image="rbxassetid://130764310743404", hd="rbxassetid://80877003243435"},
    {name="Pencil Launcher", image="rbxassetid://106934516693548", hd="rbxassetid://74125168400547"},
    {name="Glorious RPG", image="rbxassetid://130506879885802", hd="rbxassetid://77567945870953"},
    {name="Rocket Launcher", image="rbxassetid://116931956715309", hd="rbxassetid://90083302291399"},
    {name="Shorty", image="rbxassetid://17160800091", hd="rbxassetid://13255103172"},
    {name="Not So Shorty", image="rbxassetid://17672062572", hd="rbxassetid://17672087325"},
    {name="Too Shorty", image="rbxassetid://18129531276", hd="rbxassetid://18129532343"},
    {name="Lovely Shorty", image="rbxassetid://18766862000", hd="rbxassetid://18766906011"},
    {name="Demon Shorty", image="rbxassetid://116443498278384", hd="rbxassetid://110819203451709"},
    {name="Wrapped Shorty", image="rbxassetid://136522183669611", hd="rbxassetid://85255622402845"},
    {name="Balloon Shorty", image="rbxassetid://75590262133322", hd="rbxassetid://87872312114961"},
    {name="Glorious Shorty", image="rbxassetid://105834197552222", hd="rbxassetid://78845944937729"},
    {name="Shotgun", image="rbxassetid://17160800007", hd="rbxassetid://13197583302"},
    {name="Balloon Shotgun", image="rbxassetid://17821234823", hd="rbxassetid://17821266090"},
    {name="Hyper Shotgun", image="rbxassetid://18768968419", hd="rbxassetid://18768974410"},
    {name="Broomstick", image="rbxassetid://118061559757082", hd="rbxassetid://126607371232554"},
    {name="Wrapped Shotgun", image="rbxassetid://74894345245237", hd="rbxassetid://122560535811833"},
    {name="Cactus Shotgun", image="rbxassetid://131606483507460", hd="rbxassetid://128141817339029"},
    {name="Shotkey", image="rbxassetid://93004214983981", hd="rbxassetid://101615278610735"},
    {name="Glorious Shotgun", image="rbxassetid://71704618059601", hd="rbxassetid://104100596412940"},
    {name="Bow", image="rbxassetid://17160802080", hd="rbxassetid://13717212331"},
    {name="Compound Bow", image="rbxassetid://17672234242", hd="rbxassetid://17672229023"},
    {name="Raven Bow", image="rbxassetid://18766861627", hd="rbxassetid://18766905321"},
    {name="Bat Bow", image="rbxassetid://108984987378619", hd="rbxassetid://71508472340303"},
    {name="Frostbite Bow", image="rbxassetid://121895626623160", hd="rbxassetid://82246935699705"},
    {name="Dream Bow", image="rbxassetid://101089313144218", hd="rbxassetid://104571173348964"},
    {name="Key Bow", image="rbxassetid://122525140091212", hd="rbxassetid://101924188286368"},
    {name="Glorious Bow", image="rbxassetid://84201415206621", hd="rbxassetid://139021383472653"},
    {name="Balloon Bow", image="rbxassetid://128957010941029", hd="rbxassetid://123350417110914"},
    {name="Beloved Bow", image="rbxassetid://110219131386799", hd="rbxassetid://92379249333386"},
    {name="Uzi", image="rbxassetid://17160798908", hd="rbxassetid://14020829706"},
    {name="Water Uzi", image="rbxassetid://17821233590", hd="rbxassetid://17821264784"},
    {name="Electro Uzi", image="rbxassetid://96806694653207", hd="rbxassetid://98294074022488"},
    {name="Demon Uzi", image="rbxassetid://132973040482576", hd="rbxassetid://81076572654230"},
    {name="Pine Uzi", image="rbxassetid://82545206964916", hd="rbxassetid://80778273701013"},
    {name="Money Gun", image="rbxassetid://100705725115757", hd="rbxassetid://73092203311844"},
    {name="Keyzi", image="rbxassetid://100392703246534", hd="rbxassetid://127937206087121"},
    {name="Glorious Uzi", image="rbxassetid://120045334159124", hd="rbxassetid://121978889022374"},
    {name="Revolver", image="rbxassetid://17160800299", hd="rbxassetid://14020829500"},
    {name="Desert Eagle", image="rbxassetid://17821234372", hd="rbxassetid://17821265603"},
    {name="Sheriff", image="rbxassetid://18770192507", hd="rbxassetid://18770200449"},
    {name="Boneclaw Revolver", image="rbxassetid://119174697609264", hd="rbxassetid://134217952089145"},
    {name="Peppermint Sheriff", image="rbxassetid://95859403750768", hd="rbxassetid://71229586558137"},
    {name="Keyvolver", image="rbxassetid://87974031410344", hd="rbxassetid://73746116648532"},
    {name="Peppergun", image="rbxassetid://124178691056979", hd="rbxassetid://112311707478578"},
    {name="Glorious Revolver", image="rbxassetid://118135542031794", hd="rbxassetid://137749607553707"},
    {name="Paintball Gun", image="rbxassetid://17160853798", hd="rbxassetid://16560547676"},
    {name="Slime Gun", image="rbxassetid://17672062472", hd="rbxassetid://17672087561"},
    {name="Boba Gun", image="rbxassetid://18768830660", hd="rbxassetid://18768828072"},
    {name="Brain Gun", image="rbxassetid://85970592668118", hd="rbxassetid://135843933439701"},
    {name="Snowball Gun", image="rbxassetid://113685354916533", hd="rbxassetid://78161595959189"},
    {name="Ketchup Gun", image="rbxassetid://76083615050939", hd="rbxassetid://130402361506639"},
    {name="Glorious Paintball Gun", image="rbxassetid://86297318955856", hd="rbxassetid://92272641219379"},
    {name="Paintballoon Gun", image="rbxassetid://100129918948246", hd="rbxassetid://71822933033710"},
    {name="Slingshot", image="rbxassetid://17160799888", hd="rbxassetid://17095306079"},
    {name="Goalpost", image="rbxassetid://17672063165", hd="rbxassetid://17672086378"},
    {name="Stick", image="rbxassetid://17672063048", hd="rbxassetid://17672086502"},
    {name="Boneshot", image="rbxassetid://86606957688341", hd="rbxassetid://103283614012077"},
    {name="Reindeer Slingshot", image="rbxassetid://121612921203624", hd="rbxassetid://106406735551091"},
    {name="Harp", image="rbxassetid://80850043664453", hd="rbxassetid://89702051394732"},
    {name="Glorious Slingshot", image="rbxassetid://101195664167288", hd="rbxassetid://111031840425662"},
    {name="Lucky Horseshoe", image="rbxassetid://131242126669282", hd="rbxassetid://126152077516450"},
    {name="Grenade Launcher", image="rbxassetid://17250453814", hd="rbxassetid://17250456230"},
    {name="Swashbuckler", image="rbxassetid://17821233828", hd="rbxassetid://17821265007"},
    {name="Uranium Launcher", image="rbxassetid://18766860114", hd="rbxassetid://18766902983"},
    {name="Skull Launcher", image="rbxassetid://103257281022910", hd="rbxassetid://88061081371943"},
    {name="Snowball Launcher", image="rbxassetid://112349955391111", hd="rbxassetid://136762406657736"},
    {name="Gearnade Launcher", image="rbxassetid://133756750612042", hd="rbxassetid://91208130484582"},
    {name="Glorious Grenade Launcher", image="rbxassetid://134130354519919", hd="rbxassetid://133636006123737"},
    {name="Balloon Launcher", image="rbxassetid://137862701599991", hd="rbxassetid://104286567552270"},
    {name="Minigun", image="rbxassetid://17250458611", hd="rbxassetid://17250457775"},
    {name="Lasergun 3000", image="rbxassetid://103437974285778", hd="rbxassetid://116040043955852"},
    {name="Pixel Minigun", image="rbxassetid://18766861798", hd="rbxassetid://18769001642"},
    {name="Pumpkin Minigun", image="rbxassetid://77388785880854", hd="rbxassetid://101609024294564"},
    {name="Wrapped Minigun", image="rbxassetid://127077702465909", hd="rbxassetid://77902572458498"},
    {name="Fighter Jet", image="rbxassetid://70780739230558", hd="rbxassetid://95650502925488"},
    {name="Glorious Minigun", image="rbxassetid://84246894288637", hd="rbxassetid://99372535399034"},
    {name="Exogun", image="rbxassetid://17344796376", hd="rbxassetid://17344797370"},
    {name="Wondergun", image="rbxassetid://17672060360", hd="rbxassetid://17672086052"},
    {name="Singularity", image="rbxassetid://17676876756", hd="rbxassetid://17676875650"},
    {name="Ray Gun", image="rbxassetid://18766861454", hd="rbxassetid://18766905089"},
    {name="Exogourd", image="rbxassetid://137140750597688", hd="rbxassetid://125880131168138"},
    {name="Midnight Festive Exogun", image="rbxassetid://127612442529810", hd="rbxassetid://80015495064851"},
    {name="Repulsor", image="rbxassetid://109263387714628", hd="rbxassetid://130472229545721"},
    {name="Glorious Exogun", image="rbxassetid://129125201034206", hd="rbxassetid://105785189977176"},
    {name="Freeze Ray", image="rbxassetid://18429552328", hd="rbxassetid://18429549331"},
    {name="Temporal Ray", image="rbxassetid://18429552503", hd="rbxassetid://18429549663"},
    {name="Bubble Ray", image="rbxassetid://18766865819", hd="rbxassetid://18769002868"},
    {name="Spider Ray", image="rbxassetid://136838810668332", hd="rbxassetid://92621276006979"},
    {name="Wrapped Freeze Ray", image="rbxassetid://76183738050112", hd="rbxassetid://77624613843681"},
    {name="Gum Ray", image="rbxassetid://121504417727123", hd="rbxassetid://124339207784760"},
    {name="Glorious Freeze Ray", image="rbxassetid://120211873831101", hd="rbxassetid://96505833323714"},
    {name="War Horn", image="rbxassetid://104600246515190", hd="rbxassetid://97997387092919"},
    {name="Trumpet", image="rbxassetid://88975601634708", hd="rbxassetid://113408430051712"},
    {name="Mammoth Horn", image="rbxassetid://93076834584542", hd="rbxassetid://107659166723688"},
    {name="Megaphone", image="rbxassetid://107074211847347", hd="rbxassetid://100739584109870"},
    {name="Air Horn", image="rbxassetid://111168146142976", hd="rbxassetid://128732687072177"},
    {name="Glorious War Horn", image="rbxassetid://96293355496772", hd="rbxassetid://123021790391323"},
    {name="Boneclaw Horn", image="rbxassetid://138360812591331", hd="rbxassetid://126578341307256"},
    {name="Satchel", image="rbxassetid://82237471151891", hd="rbxassetid://132559258532984"},
    {name="Advanced Satchel", image="rbxassetid://113860326910548", hd="rbxassetid://118684510688617"},
    {name="Suspicious Gift", image="rbxassetid://76209303162814", hd="rbxassetid://131542627171282"},
    {name="Notebook Satchel", image="rbxassetid://124817464748150", hd="rbxassetid://85589408404069"},
    {name="Bag o' Money", image="rbxassetid://129192426700659", hd="rbxassetid://118634288543707"},
    {name="Glorious Satchel", image="rbxassetid://100521994805910", hd="rbxassetid://85737788428846"},
    {name="Potion Satchel", image="rbxassetid://76787046046890", hd="rbxassetid://112434777433399"},
    {name="Battle Axe", image="rbxassetid://93390542043222", hd="rbxassetid://78364101927650"},
    {name="The Shred", image="rbxassetid://71234381808727", hd="rbxassetid://95922136476180"},
    {name="Nordic Axe", image="rbxassetid://80052264197135", hd="rbxassetid://86476943038006"},
    {name="Ban Axe", image="rbxassetid://111046431576859", hd="rbxassetid://100159715604530"},
    {name="Cerulean Axe", image="rbxassetid://76353832683350", hd="rbxassetid://82989708806032"},
    {name="Glorious Battle Axe", image="rbxassetid://87227212476138", hd="rbxassetid://72356106057179"},
    {name="Mimic Axe", image="rbxassetid://111717370450373", hd="rbxassetid://96746396437552"},
    {name="Keyttle Axe", image="rbxassetid://122117068984402", hd="rbxassetid://100168194779130"},
    {name="Balloon Axe", image="rbxassetid://102429983628211", hd="rbxassetid://85852980135764"},
    {name="Riot Shield", image="rbxassetid://121172272442833", hd="rbxassetid://126785276332335"},
    {name="Door", image="rbxassetid://79242603995428", hd="rbxassetid://137027368393353"},
    {name="Sled", image="rbxassetid://73881731607231", hd="rbxassetid://127016476735322"},
    {name="Energy Shield", image="rbxassetid://90215439337413", hd="rbxassetid://127037252186171"},
    {name="Masterpiece", image="rbxassetid://79914271483818", hd="rbxassetid://72274483575028"},
    {name="Glorious Riot Shield", image="rbxassetid://132866851386509", hd="rbxassetid://117405461442739"},
    {name="Tombstone Shield", image="rbxassetid://125895528641243", hd="rbxassetid://114630737114417"},
    {name="Daggers", image="rbxassetid://91885384580845", hd="rbxassetid://138508026547275"},
    {name="Aces", image="rbxassetid://139089881483398", hd="rbxassetid://78850921968876"},
    {name="Cookies", image="rbxassetid://114482325531769", hd="rbxassetid://112581667413176"},
    {name="Crystal Daggers", image="rbxassetid://126221748659600", hd="rbxassetid://92405854307880"},
    {name="Paper Planes", image="rbxassetid://84003122595879", hd="rbxassetid://90572065167686"},
    {name="Shurikens", image="rbxassetid://135574097643275", hd="rbxassetid://118592510576313"},
    {name="Glorious Daggers", image="rbxassetid://76023189104485", hd="rbxassetid://89590724074968"},
    {name="Bat Daggers", image="rbxassetid://92001964015225", hd="rbxassetid://137570635514267"},
    {name="Keynais", image="rbxassetid://84562761142610", hd="rbxassetid://133742080595679"},
    {name="Broken Hearts", image="rbxassetid://74156924296351", hd="rbxassetid://136682361594607"},
    {name="Energy Pistols", image="rbxassetid://79471670126710", hd="rbxassetid://125338509278840"},
    {name="Hacker Pistols", image="rbxassetid://140621407555872", hd="rbxassetid://105705939354438"},
    {name="Apex Pistols", image="rbxassetid://136156057859453", hd="rbxassetid://132394469151873"},
    {name="New Year Energy Pistols", image="rbxassetid://126589959779039", hd="rbxassetid://88240834599421"},
    {name="Void Pistols", image="rbxassetid://111278471262300", hd="rbxassetid://114821885011907"},
    {name="Hydro Pistols", image="rbxassetid://115281889984097", hd="rbxassetid://102390688726302"},
    {name="Glorious Energy Pistols", image="rbxassetid://114418789647547", hd="rbxassetid://85080210873739"},
    {name="Soul Pistols", image="rbxassetid://72213738067158", hd="rbxassetid://95359207769282"},
    {name="Hyperlaser Guns", image="rbxassetid://106947526362970", hd="rbxassetid://97275763845090"},
    {name="Energy Rifle", image="rbxassetid://110259279810005", hd="rbxassetid://103736834693278"},
    {name="Hacker Rifle", image="rbxassetid://122816271917525", hd="rbxassetid://89213922790170"},
    {name="Apex Rifle", image="rbxassetid://88144772234151", hd="rbxassetid://111748806401551"},
    {name="New Year Energy Rifle", image="rbxassetid://111446782522703", hd="rbxassetid://101868484686291"},
    {name="Hydro Rifle", image="rbxassetid://73690448730060", hd="rbxassetid://101984348353475"},
    {name="Void Rifle", image="rbxassetid://95985016411441", hd="rbxassetid://107749233395884"},
    {name="Glorious Energy Rifle", image="rbxassetid://72632815443247", hd="rbxassetid://95552510838071"},
    {name="Soul Rifle", image="rbxassetid://129351366788323", hd="rbxassetid://140115840236565"},
    {name="Spray", image="rbxassetid://92882887485248", hd="rbxassetid://87291726953666"},
    {name="Lovely Spray", image="rbxassetid://131203015026683", hd="rbxassetid://138177960576401"},
    {name="Pine Spray", image="rbxassetid://128285758736343", hd="rbxassetid://79010014206302"},
    {name="Nail Gun", image="rbxassetid://110577809934251", hd="rbxassetid://79527532659144"},
    {name="Spray Bottle", image="rbxassetid://137955019285700", hd="rbxassetid://88384629194597"},
    {name="Glorious Spray", image="rbxassetid://138246745001490", hd="rbxassetid://103484739840527"},
    {name="Boneclaw Spray", image="rbxassetid://114078818081911", hd="rbxassetid://127336875478381"},
    {name="Key Spray", image="rbxassetid://94061940442700", hd="rbxassetid://104758575159924"},
    {name="Crossbow", image="rbxassetid://140211832612284", hd="rbxassetid://130065160832422"},
    {name="Pixel Crossbow", image="rbxassetid://115931961841903", hd="rbxassetid://129836248906904"},
    {name="Frostbite Crossbow", image="rbxassetid://101536997945363", hd="rbxassetid://116171878456521"},
    {name="Harpoon Crossbow", image="rbxassetid://107460405492001", hd="rbxassetid://127546301627893"},
    {name="Violin Crossbow", image="rbxassetid://74401302514014", hd="rbxassetid://119666131999240"},
    {name="Glorious Crossbow", image="rbxassetid://70875146419725", hd="rbxassetid://125494419498405"},
    {name="Crossbone", image="rbxassetid://103469183638638", hd="rbxassetid://81476287380261"},
    {name="Arch Crossbow", image="rbxassetid://94981733362451", hd="rbxassetid://107213949119266"},
    {name="Gunblade", image="rbxassetid://131231034374465", hd="rbxassetid://131462750179690"},
    {name="Hyper Gunblade", image="rbxassetid://134415898983004", hd="rbxassetid://134499903901922"},
    {name="Elf's Gunblade", image="rbxassetid://114103306647123", hd="rbxassetid://81214817732179"},
    {name="Crude Gunblade", image="rbxassetid://126996645502136", hd="rbxassetid://111573250598753"},
    {name="Gunsaw", image="rbxassetid://102700915422689", hd="rbxassetid://136642950174663"},
    {name="Glorious Gunblade", image="rbxassetid://88003799126136", hd="rbxassetid://88582922101753"},
    {name="Boneblade", image="rbxassetid://126327381608481", hd="rbxassetid://126287813768518"},
    {name="Jump Pad", image="rbxassetid://79459600453621", hd="rbxassetid://102532564314723"},
    {name="Trampoline", image="rbxassetid://103567857194140", hd="rbxassetid://92310435035049"},
    {name="Bounce House", image="rbxassetid://71226436012588", hd="rbxassetid://79326657484315"},
    {name="Shady Chicken Sandwich", image="rbxassetid://86361684164972", hd="rbxassetid://113753042073837"},
    {name="Glorious Jump Pad", image="rbxassetid://71803398862947", hd="rbxassetid://96408475917789"},
    {name="Spider Web", image="rbxassetid://84204578032332", hd="rbxassetid://133104747106136"},
    {name="Jolly Man", image="rbxassetid://97375473537804", hd="rbxassetid://98002300428288"},
    {name="Scepter", image="rbxassetid://99183402177823", hd="rbxassetid://89220212871603"},
    {name="Elixir", image="rbxassetid://123677194704684", hd="rbxassetid://96734141776078"},
    {name="Glass Cannon", image="rbxassetid://138882843694218", hd="rbxassetid://82999887306387"},
    {name="Glast Shard", image="rbxassetid://102980815872652", hd="rbxassetid://136181940429732"},
    {name="RNG Dice", image="rbxassetid://98372867049331", hd="rbxassetid://75601061529918"},
    {name="Distortion", image="rbxassetid://115712150398379", hd="rbxassetid://130153907701944"},
    {name="Glorious Distortion", image="rbxassetid://134722661973710", hd="rbxassetid://107736694179886"},
    {name="Electropunk Distortion", image="rbxassetid://109544539643046", hd="rbxassetid://91778033503945"},
    {name="Experiment D15", image="rbxassetid://103446773933340", hd="rbxassetid://118366946179457"},
    {name="Plasma Distortion", image="rbxassetid://126813935337091", hd="rbxassetid://83622093873798"},
    {name="Magma Distortion", image="rbxassetid://81103807698156", hd="rbxassetid://109079139956898"},
    {name="Cyber Distortion", image="rbxassetid://88995062151276", hd="rbxassetid://78940266607471"},
    {name="Sleighstortion", image="rbxassetid://111242141481650", hd="rbxassetid://113075083434001"},
    {name="Warper", image="rbxassetid://88033795039891", hd="rbxassetid://97537499062821"},
    {name="Glorious Warper", image="rbxassetid://95823647035211", hd="rbxassetid://117284572803988"},
    {name="Electropunk Warper", image="rbxassetid://75386728379756", hd="rbxassetid://96080679722284"},
    {name="Experiment W4", image="rbxassetid://126884960764998", hd="rbxassetid://77873591123909"},
    {name="Glitter Warper", image="rbxassetid://94607497565715", hd="rbxassetid://128289126916762"},
    {name="Arcane Warper", image="rbxassetid://83632373572638", hd="rbxassetid://92765478127490"},
    {name="Hotel Bell", image="rbxassetid://117742703173821", hd="rbxassetid://74303585805484"},
    {name="Frost Warper", image="rbxassetid://70539216094396", hd="rbxassetid://84458438183331"},
    {name="Warpstone", image="rbxassetid://94035693279005", hd="rbxassetid://99660718217521"},
    {name="Glorious Warpstone", image="rbxassetid://137583560042806", hd="rbxassetid://99142505492556"},
    {name="Unstable Warpstone", image="rbxassetid://110083777654388", hd="rbxassetid://71896071193185"},
    {name="Warpeye", image="rbxassetid://127023603234857", hd="rbxassetid://129554679066276"},
    {name="Warpbone", image="rbxassetid://96452209607150", hd="rbxassetid://132473085580193"},
    {name="Cyber Warpstone", image="rbxassetid://133002984228937", hd="rbxassetid://78671282003316"},
    {name="Teleport Disc", image="rbxassetid://104608154111107", hd="rbxassetid://81728761431901"},
    {name="Electropunk Warpstone", image="rbxassetid://75299042976369", hd="rbxassetid://121167052087315"},
    {name="Warpstar", image="rbxassetid://102652397897598", hd="rbxassetid://85728240647371"},
    {name="Maul", image="rbxassetid://81478141693597", hd="rbxassetid://96956174894354"},
    {name="Sleigh Maul", image="rbxassetid://114892026951995", hd="rbxassetid://112835874307935"},
    {name="Ice Maul", image="rbxassetid://100001888078290", hd="rbxassetid://79987597452893"},
    {name="Glorious Maul", image="rbxassetid://125917253783002", hd="rbxassetid://109898315901573"},
    {name="Ban Hammer", image="rbxassetid://126491383967029", hd="rbxassetid://139055067677915"},
    {name="Permafrost", image="rbxassetid://74353733133888", hd="rbxassetid://78468628083590"},
    {name="Snowman Permafrost", image="rbxassetid://100890626643184", hd="rbxassetid://70467865456788"},
    {name="Ice Permafrost", image="rbxassetid://83722160119335", hd="rbxassetid://122848886028890"},
    {name="Glorious Permafrost", image="rbxassetid://119977291442329", hd="rbxassetid://82134252571554"},
}

local IMAGE_DB = {}
for i, item in ipairs(ITEMS) do
    IMAGE_DB[item.name] = item
    if i % 50 == 0 then task.wait() end
end
ITEMS = nil -- libérer mémoire
task.wait()

-- ═══════ SKIN → WEAPON OVERRIDE MAP ═══════
local SKIN_WEAPON_OVERRIDE = {
    -- Knife (9)
    ["Karambit"]        = "Knife",
    ["Chancla"]         = "Knife",
    ["Candy Cane"]      = "Knife",
    ["Machete"]         = "Knife",
    ["Balisong"]        = "Knife",
    ["Caladbolg"]       = "Knife",
    ["Keylisong"]       = "Knife",
    ["Keyrambit"]       = "Knife",
    ["Glorious Knife"]  = "Knife",
    -- Daggers (9)
    ["Paper Planes"]       = "Daggers",
    ["Aces"]               = "Daggers",
    ["Bat Daggers"]        = "Daggers",
    ["Cookies"]            = "Daggers",
    ["Shurikens"]          = "Daggers",
    ["Crystal Daggers"]    = "Daggers",
    ["Keynais"]            = "Daggers",
    ["Broken Hearts"]      = "Daggers",
    ["Glorious Daggers"]   = "Daggers",
    -- Energy Pistols (8)
    ["Void Pistols"]              = "Energy Pistols",
    ["Hacker Pistols"]            = "Energy Pistols",
    ["Soul Pistols"]              = "Energy Pistols",
    ["New Year Energy Pistols"]   = "Energy Pistols",
    ["Hydro Pistols"]             = "Energy Pistols",
    ["Hyperlaser Guns"]           = "Energy Pistols",
    ["Apex Pistols"]              = "Energy Pistols",
    ["Glorious Energy Pistols"]   = "Energy Pistols",
    -- Slingshot (7)
    ["Goalpost"]              = "Slingshot",
    ["Stick"]                 = "Slingshot",
    ["Boneshot"]              = "Slingshot",
    ["Reindeer Slingshot"]    = "Slingshot",
    ["Lucky Horseshoe"]       = "Slingshot",
    ["Harp"]                  = "Slingshot",
    ["Glorious Slingshot"]    = "Slingshot",
    -- Subspace Tripmine (6)
    ["Spring"]                      = "Subspace Tripmine",
    ["Don't Press"]                 = "Subspace Tripmine",
    ["Trick or Treat"]              = "Subspace Tripmine",
    ["Dev-in-the-Box"]              = "Subspace Tripmine",
    ["DIY Tripmine"]                = "Subspace Tripmine",
    ["Glorious Subspace Tripmine"]  = "Subspace Tripmine",
    -- Paintball Gun (6)
    ["Boba Gun"]                = "Paintball Gun",
    ["Slime Gun"]               = "Paintball Gun",
    ["Brain Gun"]               = "Paintball Gun",
    ["Snowball Gun"]            = "Paintball Gun",
    ["Ketchup Gun"]             = "Paintball Gun",
    ["Glorious Paintball Gun"]  = "Paintball Gun",
    -- Flamethrower (8)
    ["Lamethrower"]             = "Flamethrower",
    ["Pixel Flamethrower"]      = "Flamethrower",
    ["Jack O'Thrower"]          = "Flamethrower",
    ["Snowblower"]              = "Flamethrower",
    ["Glitterthrower"]          = "Flamethrower",
    ["Keythrower"]              = "Flamethrower",
    ["Rainbowthrower"]          = "Flamethrower",
    ["Glorious Flamethrower"]   = "Flamethrower",
    -- Trowel (6)
    ["Paintbrush"]          = "Trowel",
    ["Garden Shovel"]       = "Trowel",
    ["Plastic Shovel"]      = "Trowel",
    ["Pumpkin Carver"]      = "Trowel",
    ["Snow Shovel"]         = "Trowel",
    ["Glorious Trowel"]     = "Trowel",
    -- Maul (4)
    ["Ban Hammer"]      = "Maul",
    ["Ice Maul"]        = "Maul",
    ["Sleigh Maul"]     = "Maul",
    ["Glorious Maul"]   = "Maul",
    -- Chainsaw (6)
    ["Blobsaw"]             = "Chainsaw",
    ["Handsaws"]            = "Chainsaw",
    ["Mega Drill"]          = "Chainsaw",
    ["Buzzsaw"]             = "Chainsaw",
    ["Festive Buzzsaw"]     = "Chainsaw",
    ["Glorious Chainsaw"]   = "Chainsaw",
    -- Revolver (7)
    ["Keyvolver"]           = "Revolver",
    ["Peppergun"]           = "Revolver",
    ["Peppermint Sheriff"]  = "Revolver",
    ["Sheriff"]             = "Revolver",
    ["Boneclaw Revolver"]   = "Revolver",
    ["Desert Eagle"]        = "Revolver",
    ["Glorious Revolver"]   = "Revolver",
    -- Crossbow (7)
    ["Arch Crossbow"]       = "Crossbow",
    ["Pixel Crossbow"]      = "Crossbow",
    ["Harpoon Crossbow"]    = "Crossbow",
    ["Violin Crossbow"]     = "Crossbow",
    ["Frostbite Crossbow"]  = "Crossbow",
    ["Crossbone"]           = "Crossbow",
    ["Glorious Crossbow"]   = "Crossbow",
    -- Gunblade (6)
    ["Hyper Gunblade"]      = "Gunblade",
    ["Gunsaw"]              = "Gunblade",
    ["Boneblade"]           = "Gunblade",
    ["Crude Gunblade"]      = "Gunblade",
    ["Elf's Gunblade"]      = "Gunblade",
    ["Glorious Gunblade"]   = "Gunblade",
    -- Exogun (7)
    ["Singularity"]             = "Exogun",
    ["Repulsor"]                = "Exogun",
    ["Ray Gun"]                 = "Exogun",
    ["Exogourd"]                = "Exogun",
    ["Wondergun"]               = "Exogun",
    ["Midnight Festive Exogun"] = "Exogun",
    ["Glorious Exogun"]         = "Exogun",
    -- Medkit (8)
    ["Box of Chocolates"]   = "Medkit",
    ["Medkitty"]            = "Medkit",
    ["Sandwich"]            = "Medkit",
    ["Laptop"]              = "Medkit",
    ["Bucket of Candy"]     = "Medkit",
    ["Milk & Cookies"]      = "Medkit",
    ["Briefcase"]           = "Medkit",
    ["Glorious Medkit"]     = "Medkit",
    -- Battle Axe (8)
    ["Keyttle Axe"]         = "Battle Axe",
    ["Balloon Axe"]         = "Battle Axe",
    ["Mimic Axe"]           = "Battle Axe",
    ["The Shred"]           = "Battle Axe",
    ["Cerulean Axe"]        = "Battle Axe",
    ["Ban Axe"]             = "Battle Axe",
    ["Nordic Axe"]          = "Battle Axe",
    ["Glorious Battle Axe"] = "Battle Axe",
    -- Katana (11)
    ["Crystal Katana"]      = "Katana",
    ["Arch Katana"]         = "Katana",
    ["Keytana"]             = "Katana",
    ["Linked Sword"]        = "Katana",
    ["Pixel Katana"]        = "Katana",
    ["Saber"]               = "Katana",
    ["Lightning Bolt"]      = "Katana",
    ["Stellar Katana"]      = "Katana",
    ["Evil Trident"]        = "Katana",
    ["New Year Katana"]     = "Katana",
    ["Glorious Katana"]     = "Katana",
    -- Riot Shield (6)
    ["Energy Shield"]           = "Riot Shield",
    ["Masterpiece"]             = "Riot Shield",
    ["Door"]                    = "Riot Shield",
    ["Sled"]                    = "Riot Shield",
    ["Tombstone Shield"]        = "Riot Shield",
    ["Glorious Riot Shield"]    = "Riot Shield",
    -- Scythe (9)
    ["Crystal Scythe"]      = "Scythe",
    ["Keythe"]              = "Scythe",
    ["Anchor"]              = "Scythe",
    ["Bat Scythe"]          = "Scythe",
    ["Cryo Scythe"]         = "Scythe",
    ["Scythe of Death"]     = "Scythe",
    ["Sakura Scythe"]       = "Scythe",
    ["Glorious Scythe"]     = "Scythe",
    ["Bug Net"]             = "Scythe",
    -- Warpstone (8)
    ["Warpeye"]                 = "Warpstone",
    ["Teleport Disc"]           = "Warpstone",
    ["Warpstar"]                = "Warpstone",
    ["Electropunk Warpstone"]   = "Warpstone",
    ["Unstable Warpstone"]      = "Warpstone",
    ["Warpbone"]                = "Warpstone",
    ["Cyber Warpstone"]         = "Warpstone",
    ["Glorious Warpstone"]      = "Warpstone",
    -- Flashbang (7)
    ["Pixel Flashbang"]         = "Flashbang",
    ["Camera"]                  = "Flashbang",
    ["Disco Ball"]              = "Flashbang",
    ["Shining Star"]            = "Flashbang",
    ["Skullbang"]               = "Flashbang",
    ["Lightbulb"]               = "Flashbang",
    ["Glorious Flashbang"]      = "Flashbang",
    -- Freeze Ray (6)
    ["Temporal Ray"]            = "Freeze Ray",
    ["Spider Ray"]              = "Freeze Ray",
    ["Bubble Ray"]              = "Freeze Ray",
    ["Gum Ray"]                 = "Freeze Ray",
    ["Wrapped Freeze Ray"]      = "Freeze Ray",
    ["Glorious Freeze Ray"]     = "Freeze Ray",
    -- Grenade (9)
    ["Keynade"]             = "Grenade",
    ["Cuddle Bomb"]         = "Grenade",
    ["Whoopee Cushion"]     = "Grenade",
    ["Soul Grenade"]        = "Grenade",
    ["Water Balloon"]       = "Grenade",
    ["Jingle Grenade"]      = "Grenade",
    ["Frozen Grenade"]      = "Grenade",
    ["Dynamite"]            = "Grenade",
    ["Glorious Grenade"]    = "Grenade",
    -- Jump Pad (6)
    ["Bounce House"]            = "Jump Pad",
    ["Shady Chicken Sandwich"]  = "Jump Pad",
    ["Jolly Man"]               = "Jump Pad",
    ["Spider Web"]              = "Jump Pad",
    ["Trampoline"]              = "Jump Pad",
    ["Glorious Jump Pad"]       = "Jump Pad",
    -- Molotov (6)
    ["Hot Coals"]           = "Molotov",
    ["Vexed Candle"]        = "Molotov",
    ["Lava Lamp"]           = "Molotov",
    ["Coffee"]              = "Molotov",
    ["Torch"]               = "Molotov",
    ["Glorious Molotov"]    = "Molotov",
    -- Satchel (6)
    ["Potion Satchel"]          = "Satchel",
    ["Advanced Satchel"]        = "Satchel",
    ["Notebook Satchel"]        = "Satchel",
    ["Bag o' Money"]            = "Satchel",
    ["Suspicious Gift"]         = "Satchel",
    ["Glorious Satchel"]        = "Satchel",
    -- Smoke Grenade (6)
    ["Eyeball"]                     = "Smoke Grenade",
    ["Emoji Cloud"]                 = "Smoke Grenade",
    ["Hourglass"]                   = "Smoke Grenade",
    ["Balance"]                     = "Smoke Grenade",
    ["Snowglobe"]                   = "Smoke Grenade",
    ["Glorious Smoke Grenade"]      = "Smoke Grenade",
    -- War Horn (6)
    ["Trumpet"]             = "War Horn",
    ["Air Horn"]            = "War Horn",
    ["Boneclaw Horn"]       = "War Horn",
    ["Megaphone"]           = "War Horn",
    ["Mammoth Horn"]        = "War Horn",
    ["Glorious War Horn"]   = "War Horn",
    -- Energy Rifle (7)
    ["Hacker Rifle"]            = "Energy Rifle",
    ["Hydro Rifle"]             = "Energy Rifle",
    ["Soul Rifle"]              = "Energy Rifle",
    ["Void Rifle"]              = "Energy Rifle",
    ["Apex Rifle"]              = "Energy Rifle",
    ["New Year Energy Rifle"]   = "Energy Rifle",
    ["Glorious Energy Rifle"]   = "Energy Rifle",
    -- Assault Rifle (9)
    ["AKEY-47"]                     = "Assault Rifle",
    ["AUG"]                         = "Assault Rifle",
    ["Tommy Gun"]                   = "Assault Rifle",
    ["Gingerbread AUG"]             = "Assault Rifle",
    ["AK-47"]                       = "Assault Rifle",
    ["Boneclaw Rifle"]              = "Assault Rifle",
    ["Phoenix Rifle"]               = "Assault Rifle",
    ["Glorious Assault Rifle"]      = "Assault Rifle",
    ["10B Visits"]                  = "Assault Rifle",
    -- Burst Rifle (8)
    ["Keyst Rifle"]             = "Burst Rifle",
    ["Electro Rifle"]           = "Burst Rifle",
    ["FAMAS"]                   = "Burst Rifle",
    ["Pixel Burst"]             = "Burst Rifle",
    ["Aqua Burst"]              = "Burst Rifle",
    ["Spectral Burst"]          = "Burst Rifle",
    ["Pine Burst"]              = "Burst Rifle",
    ["Glorious Burst Rifle"]    = "Burst Rifle",
    -- Sniper (7)
    ["Keyper"]              = "Sniper",
    ["Pixel Sniper"]        = "Sniper",
    ["Hyper Sniper"]        = "Sniper",
    ["Event Horizon"]       = "Sniper",
    ["Eyething Sniper"]     = "Sniper",
    ["Gingerbread Sniper"]  = "Sniper",
    ["Glorious Sniper"]     = "Sniper",
    -- Uzi (7)
    ["Keyzi"]           = "Uzi",
    ["Electro Uzi"]     = "Uzi",
    ["Money Gun"]        = "Uzi",
    ["Water Uzi"]       = "Uzi",
    ["Demon Uzi"]       = "Uzi",
    ["Pine Uzi"]        = "Uzi",
    ["Glorious Uzi"]    = "Uzi",
    -- Handgun (8)
    ["Hand Gun"]            = "Handgun",
    ["Pixel Handgun"]       = "Handgun",
    ["Blaster"]             = "Handgun",
    ["Gingerbread Handgun"] = "Handgun",
    ["Gumball Handgun"]     = "Handgun",
    ["Pumpkin Handgun"]     = "Handgun",
    ["Towerstone Handgun"]  = "Handgun",
    ["Glorious Handgun"]    = "Handgun",
    -- Shorty (7)
    ["Balloon Shorty"]      = "Shorty",
    ["Demon Shorty"]        = "Shorty",
    ["Lovely Shorty"]       = "Shorty",
    ["Not So Shorty"]       = "Shorty",
    ["Too Shorty"]          = "Shorty",
    ["Wrapped Shorty"]      = "Shorty",
    ["Glorious Shorty"]     = "Shorty",
    -- Shotgun (7)
    ["Shotkey"]             = "Shotgun",
    ["Balloon Shotgun"]     = "Shotgun",
    ["Hyper Shotgun"]       = "Shotgun",
    ["Cactus Shotgun"]      = "Shotgun",
    ["Broomstick"]          = "Shotgun",
    ["Wrapped Shotgun"]     = "Shotgun",
    ["Glorious Shotgun"]    = "Shotgun",
    -- Minigun (6)
    ["Lasergun 3000"]       = "Minigun",
    ["Pixel Minigun"]       = "Minigun",
    ["Fighter Jet"]         = "Minigun",
    ["Pumpkin Minigun"]     = "Minigun",
    ["Wrapped Minigun"]     = "Minigun",
    ["Glorious Minigun"]    = "Minigun",
    -- RPG (9)
    ["RPKEY"]               = "RPG",
    ["Rocket Launcher"]     = "RPG",
    ["Firework Launcher"]   = "RPG",
    ["Nuke Launcher"]       = "RPG",
    ["Pumpkin Launcher"]    = "RPG",
    ["Spaceship Launcher"]  = "RPG",
    ["Squid Launcher"]      = "RPG",
    ["Pencil Launcher"]     = "RPG",
    ["Glorious RPG"]        = "RPG",
    -- Flare Gun (6)
    ["Firework Gun"]            = "Flare Gun",
    ["Banana Flare"]            = "Flare Gun",
    ["Vexed Flare Gun"]         = "Flare Gun",
    ["Dynamite Gun"]            = "Flare Gun",
    ["Wrapped Flare Gun"]       = "Flare Gun",
    ["Glorious Flare Gun"]      = "Flare Gun",
    -- Permafrost (3)
    ["Ice Permafrost"]          = "Permafrost",
    ["Snowman Permafrost"]      = "Permafrost",
    ["Glorious Permafrost"]     = "Permafrost",
    -- Grenade Launcher (6)
    ["Skull Launcher"]              = "Grenade Launcher",
    ["Swashbuckler"]                = "Grenade Launcher",
    ["Uranium Launcher"]            = "Grenade Launcher",
    ["Gearnade Launcher"]           = "Grenade Launcher",
    ["Snowball Launcher"]           = "Grenade Launcher",
    ["Glorious Grenade Launcher"]   = "Grenade Launcher",
    -- Distortion (7)
    ["Experiment D15"]          = "Distortion",
    ["Electropunk Distortion"]  = "Distortion",
    ["Plasma Distortion"]       = "Distortion",
    ["Magma Distortion"]        = "Distortion",
    ["Sleighstortion"]          = "Distortion",
    ["Cyber Distortion"]        = "Distortion",
    ["Glorious Distortion"]     = "Distortion",
    -- Fists (7)
    ["Fist"]                = "Fists",
    ["Boxing Gloves"]       = "Fists",
    ["Fists of Hurt"]       = "Fists",
    ["Brass Knuckles"]      = "Fists",
    ["Pumpkin Claws"]       = "Fists",
    ["Festive Fists"]       = "Fists",
    ["Glorious Fists"]      = "Fists",
    -- Bow (9)
    ["Key Bow"]         = "Bow",
    ["Balloon Bow"]     = "Bow",
    ["Beloved Bow"]     = "Bow",
    ["Raven Bow"]       = "Bow",
    ["Dream Bow"]       = "Bow",
    ["Bat Bow"]         = "Bow",
    ["Frostbite Bow"]   = "Bow",
    ["Compound Bow"]    = "Bow",
    ["Glorious Bow"]    = "Bow",
    -- Spray (7)
    ["Key Spray"]       = "Spray",
    ["Spray Bottle"]    = "Spray",
    ["Boneclaw Spray"]  = "Spray",
    ["Nail Gun"]        = "Spray",
    ["Lovely Spray"]    = "Spray",
    ["Pine Spray"]      = "Spray",
    ["Glorious Spray"]  = "Spray",
}

-- ═══════ COMPATIBILITY (computed async in task.spawn) ═══════

local SKIN_KEYWORDS = {
    {"Rifle",      "Energy Rifle"},
    {"Axe",        "Battle Axe"},
    {"Horn",       "War Horn"},
    {"Shield",     "Riot Shield"},
    {"thrower",    "Flamethrower"},
    {"blower",     "Flamethrower"},
    {"Shovel",     "Trowel"},
    {"blade",      "Gunblade"},
    {"Warp",       "Warpstone"},
    {"Hammer",     "Maul"},
    {"rambit",     "Knife"},
    {"Machete",    "Knife"},
    {"Ray",        "Freeze Ray"},
    {"bang",       "Flashbang"},
    {"Crossbone",  "Crossbow"},
    {"Crossbow",   "Crossbow"},
    {"Sword",      "Katana"},
    {"Saber",      "Katana"},
    {"Trident",    "Katana"},
    {"Katana",     "Katana"},
    {"Scythe",     "Scythe"},
    {"Drill",      "Chainsaw"},
    {"saw",        "Chainsaw"},
    {"Sheriff",    "Revolver"},
    {"Pistols",    "Energy Pistols"},
    {"Grenade",    "Grenade"},
    {"Bomb",       "Grenade"},
    {"Satchel",    "Satchel"},
    {"Medkit",     "Medkit"},
    {"Molotov",    "Molotov"},
    {"Launcher",   "RPG"},
    {"Sniper",     "Sniper"},
    {"Uzi",        "Uzi"},
    {"Handgun",    "Handgun"},
    {"Shorty",     "Shorty"},
    {"Shotgun",    "Shotgun"},
    {"Minigun",    "Minigun"},
    {"Flare",      "Flare Gun"},
    {"Permafrost", "Permafrost"},
    {"Distortion", "Distortion"},
    {"stortion",   "Distortion"},
    {"Fists",      "Fists"},
    {"Knuckles",   "Fists"},
    {"Gloves",     "Fists"},
    {"Bow",        "Bow"},
    {"Spray",      "Spray"},
    {"Burst",      "Burst Rifle"},
    {"AUG",        "Assault Rifle"},
}

local compatCache = {}
local compatReady = false

task.spawn(function()
    -- Build ambiguous weapon groups
    local childSetGroups = {}
    for wName, cache in pairs(weaponChildCache) do
        local names = {}
        for n in pairs(cache.set) do table.insert(names, n) end
        table.sort(names)
        local sig = table.concat(names, "|")
        if not childSetGroups[sig] then childSetGroups[sig] = {} end
        table.insert(childSetGroups[sig], wName)
    end

    local isAmbiguous = {}
    local ambiguousWeapons = {}
    for _, weapons in pairs(childSetGroups) do
        if #weapons > 1 then
            for _, wName in ipairs(weapons) do
                isAmbiguous[wName] = true
                table.insert(ambiguousWeapons, wName)
            end
        end
    end
    table.sort(ambiguousWeapons, function(a, b) return #a > #b end)
    task.wait()

    local function identifySkinWeapon(skinName)
        local lo = skinName:lower()
        for _, wName in ipairs(ambiguousWeapons) do
            if lo:find(wName:lower(), 1, true) then return wName end
        end
        for _, pair in ipairs(SKIN_KEYWORDS) do
            if lo:find(pair[1]:lower(), 1, true) then return pair[2] end
        end
        return nil
    end

    local function getGrandchildSig(instance)
        local names = {}
        for _, child in ipairs(instance:GetChildren()) do
            for _, gc in ipairs(child:GetChildren()) do
                table.insert(names, gc.Name)
            end
        end
        table.sort(names)
        return table.concat(names, "|")
    end

    -- Weapon grandchild sigs
    local weaponSigs = {}
    local c1 = 0
    for wName in pairs(isAmbiguous) do
        local weapon = ViewModels.Weapons:FindFirstChild(wName)
        if weapon then weaponSigs[wName] = getGrandchildSig(weapon) end
        c1 = c1 + 1
        if c1 % 3 == 0 then task.wait() end
    end
    task.wait()

    -- Skin grandchild sigs (only for ambiguous sets, skip overrides)
    local ambiguousSigs = {}
    for sig, weapons in pairs(childSetGroups) do
        if #weapons > 1 then ambiguousSigs[sig] = true end
    end

    local skinSigs = {}
    local c2 = 0
    for caseName, caseData in pairs(jsonData.SkinCases or {}) do
        local caseFolder = ViewModels:FindFirstChild(caseName)
        if caseFolder then
            for skinName, children in pairs(caseData) do
                if not SKIN_WEAPON_OVERRIDE[skinName] then
                    local sorted = {}
                    for _, cn in ipairs(children) do table.insert(sorted, cn) end
                    table.sort(sorted)
                    if ambiguousSigs[table.concat(sorted, "|")] then
                        local skin = caseFolder:FindFirstChild(skinName)
                        if skin then
                            skinSigs[caseName .. "/" .. skinName] = getGrandchildSig(skin)
                            c2 = c2 + 1
                            if c2 % 5 == 0 then task.wait() end
                        end
                    end
                end
            end
        end
        task.wait()
    end
    task.wait()

    -- isSkinCompatible (local to this scope)
    local function isSkinCompatible(caseName, skinName, weaponName)
        local overrideWeapon = SKIN_WEAPON_OVERRIDE[skinName]
        if overrideWeapon then return overrideWeapon == weaponName end
        local skinChildren = jsonData.SkinCases[caseName] and jsonData.SkinCases[caseName][skinName]
        if not skinChildren then return false end
        local cache = weaponChildCache[weaponName]
        if not cache then return false end
        if #skinChildren ~= cache.count then return false end
        for _, childName in ipairs(skinChildren) do
            if not cache.set[childName] then return false end
        end
        if isAmbiguous[weaponName] then
            local skinWeapon = identifySkinWeapon(skinName)
            if skinWeapon then return skinWeapon == weaponName end
            local wSig = weaponSigs[weaponName]
            local sSig = skinSigs[caseName .. "/" .. skinName]
            if wSig and sSig and wSig ~= sSig then return false end
        end
        return true
    end

    -- Build compatCache
    for wi, wName in ipairs(weaponList) do
        local result = {}
        for caseName, caseData in pairs(jsonData.SkinCases or {}) do
            for skinName in pairs(caseData) do
                if isSkinCompatible(caseName, skinName, wName) then
                    table.insert(result, {name = skinName, case = caseName})
                end
            end
        end
        table.sort(result, function(a, b) return a.name < b.name end)
        compatCache[wName] = result
        if wi % 2 == 0 then task.wait() end
    end

    compatReady = true
    print("[Cosmetic Changer V2] Compatibility cache ready")
end)

local skinCaseList = {}
for name in pairs(jsonData.SkinCases or {}) do
    table.insert(skinCaseList, name)
end
table.sort(skinCaseList)

-- ┌──────────────────────────────────────────────────────────┐
-- │  COSMETIC LIBRARY HOOK (unlock all) — deferred           │
-- └──────────────────────────────────────────────────────────┘

local function hookOwnership()
    if type(getgc) ~= "function" then return false end
    local best, bestScore = nil, 0
    for _, obj in ipairs(getgc(true)) do
        if type(obj) == "table"
            and type(rawget(obj, "OwnsCosmeticNormally")) == "function"
            and type(rawget(obj, "OwnsCosmeticForWeapon")) == "function"
            and type(rawget(obj, "OwnsCosmeticUniversally")) == "function"
        then
            local cosCount = 0
            local cos = rawget(obj, "Cosmetics")
            if type(cos) == "table" then
                for _ in pairs(cos) do cosCount = cosCount + 1 end
            end
            if cosCount > bestScore then
                bestScore = cosCount
                best = obj
            end
        end
    end
    if not best then return false end
    rawset(best, "OwnsCosmeticNormally", function() return true end)
    rawset(best, "OwnsCosmeticForWeapon", function() return true end)
    rawset(best, "OwnsCosmeticUniversally", function() return true end)
    return true
end
-- Defer hookOwnership to run AFTER GUI is built
task.delay(2, function() pcall(hookOwnership) end)

-- ┌──────────────────────────────────────────────────────────┐
-- │  SKIN APPLICATION                                        │
-- └──────────────────────────────────────────────────────────┘

local originalWeapons = {}
local originalSounds = {}
local originalAnims  = {} -- weaponName -> { [key] = origEntry }
local originalScrapedSounds = {} -- weaponName -> origData
local activeOverrides = {} -- weaponName -> {case, skin}

local function saveOriginal(weaponName)
    if originalWeapons[weaponName] then return end
    local weapon = ViewModels.Weapons[weaponName]
    if not weapon then return end
    originalWeapons[weaponName] = {}
    for _, v in ipairs(weapon:GetChildren()) do
        table.insert(originalWeapons[weaponName], v:Clone())
    end
end

-- Map weapon names to their animation prefix (lowercase, spaces removed for some)
local _animPrefixCache = {}
local function getAnimPrefix(weaponName)
    if _animPrefixCache[weaponName] then return _animPrefixCache[weaponName] end
    _ensureAnimLib()
    if not AnimLibInfo then return nil end
    -- Try the weapon name lowered with spaces as underscores, then without spaces
    local tests = {
        weaponName:lower():gsub(" ", ""),          -- "energypistols"
        weaponName:lower():gsub(" ", "_"),          -- "energy_pistols"
        weaponName:lower(),                         -- "energy pistols"
    }
    -- Find any key in AnimLibInfo that starts with one of these prefixes + "_"
    for key in pairs(AnimLibInfo) do
        local kl = key:lower()
        for _, prefix in ipairs(tests) do
            if kl:sub(1, #prefix + 1) == prefix .. "_" then
                -- Extract the actual prefix used (case-sensitive from key)
                local realPrefix = key:sub(1, #prefix)
                _animPrefixCache[weaponName] = realPrefix
                return realPrefix
            end
        end
    end
    return nil
end

local function getSkinAnimPrefix(weaponName, skinName)
    local weaponPrefix = getAnimPrefix(weaponName)
    if not weaponPrefix or not AnimLibInfo then return nil end
    local skinLower = skinName:lower():gsub(" ", "")
    local testKey = weaponPrefix .. "_" .. skinLower .. "_"
    for key in pairs(AnimLibInfo) do
        if key:lower():sub(1, #testKey) == testKey:lower() then
            return weaponPrefix .. "_" .. skinName:lower():gsub(" ", "")
        end
    end
    -- Try with underscores instead
    local skinUnder = skinName:lower():gsub(" ", "_")
    testKey = weaponPrefix .. "_" .. skinUnder .. "_"
    for key in pairs(AnimLibInfo) do
        if key:lower():sub(1, #testKey) == testKey:lower() then
            return weaponPrefix .. "_" .. skinUnder
        end
    end
    return nil
end

local function applySkinAnimations(weaponName, skinName)
    _ensureAnimLib()
    _ensureScrapedSounds()
    if not AnimLibInfo then return end
    local weaponPrefix = getAnimPrefix(weaponName)
    if not weaponPrefix then return end

    local skinAnimPrefix = getSkinAnimPrefix(weaponName, skinName)
    if not skinAnimPrefix then return end

    -- Save originals and remap: for each skin animation, overwrite the base weapon animation
    if not originalAnims[weaponName] then originalAnims[weaponName] = {} end

    local wpLower = weaponPrefix:lower()
    local spLower = skinAnimPrefix:lower()

    for key, entry in pairs(AnimLibInfo) do
        local kl = key:lower()
        -- Check if this is a skin-specific animation: prefix_skinname_action
        if kl:sub(1, #spLower + 1) == spLower .. "_" then
            local action = kl:sub(#spLower + 2) -- e.g. "equip", "shoot1", etc.
            local baseKey = nil
            -- Find the matching base weapon key
            for bk in pairs(AnimLibInfo) do
                local bkl = bk:lower()
                if bkl == wpLower .. "_" .. action then
                    baseKey = bk
                    break
                end
            end
            if baseKey and not originalAnims[weaponName][baseKey] then
                originalAnims[weaponName][baseKey] = AnimLibInfo[baseKey]
                AnimLibInfo[baseKey] = entry
            end
        end
    end

    -- Override ScrapedAnimationSounds if the skin has entries
    if ScrapedAnimSoundsModule then
        local skinKey = skinName
        local weaponKey = weaponName
        if ScrapedAnimSoundsModule[skinKey] and not originalScrapedSounds[weaponName] then
            originalScrapedSounds[weaponName] = ScrapedAnimSoundsModule[weaponKey]
            ScrapedAnimSoundsModule[weaponKey] = ScrapedAnimSoundsModule[skinKey]
        end
    end
end

local function resetSkinAnimations(weaponName)
    if originalAnims[weaponName] and AnimLibInfo then
        for key, origEntry in pairs(originalAnims[weaponName]) do
            AnimLibInfo[key] = origEntry
        end
        originalAnims[weaponName] = nil
    end
    if originalScrapedSounds[weaponName] and ScrapedAnimSoundsModule then
        ScrapedAnimSoundsModule[weaponName] = originalScrapedSounds[weaponName]
        originalScrapedSounds[weaponName] = nil
    end
end

local function applySkin(weaponName, caseName, skinName)
    _ensureSoundModules()
    _ensureAnimLib()
    _ensureScrapedSounds()
    -- Reset previous skin's animations/sounds BEFORE applying new ones
    -- (keeps originals intact, just restores base state first)
    pcall(function() resetSkinAnimations(weaponName) end)
    pcall(function()
        local sounds = originalSounds[weaponName]
        if sounds then
            ItemSoundsModule[weaponName] = sounds.item
            ViewModelSoundsModule[weaponName] = sounds.vm
        end
    end)

    local ok, err = pcall(function()
        saveOriginal(weaponName)
        local skin = ViewModels[caseName][skinName]
        local weapon = ViewModels.Weapons[weaponName]
        weapon:ClearAllChildren()
        for _, v in ipairs(skin:GetChildren()) do
            v:Clone().Parent = weapon
        end
    end)
    pcall(function()
        local skinSounds = ViewModelSoundsModule[skinName]
        if skinSounds and weaponName then
            if not originalSounds[weaponName] then
                originalSounds[weaponName] = {
                    item = ItemSoundsModule[weaponName],
                    vm = ViewModelSoundsModule[weaponName]
                }
            end
            ItemSoundsModule[weaponName] = skinSounds
            ViewModelSoundsModule[weaponName] = skinSounds
        end
    end)
    pcall(function()
        applySkinAnimations(weaponName, skinName)
    end)
    if ok then
        activeOverrides[weaponName] = {case = caseName, skin = skinName}
    end
    return ok
end

local function resetWeapon(weaponName)
    local saved = originalWeapons[weaponName]
    if not saved then return end
    pcall(function()
        local weapon = ViewModels.Weapons[weaponName]
        weapon:ClearAllChildren()
        for _, v in ipairs(saved) do
            v:Clone().Parent = weapon
        end
    end)
    local sounds = originalSounds[weaponName]
    if sounds then
        pcall(function()
            ItemSoundsModule[weaponName] = sounds.item
            ViewModelSoundsModule[weaponName] = sounds.vm
        end)
        originalSounds[weaponName] = nil
    end
    pcall(function() resetSkinAnimations(weaponName) end)
    originalWeapons[weaponName] = nil
    activeOverrides[weaponName] = nil
end

local function resetAllWeapons()
    local toReset = {}
    for name in pairs(activeOverrides) do
        table.insert(toReset, name)
    end
    for _, name in ipairs(toReset) do
        resetWeapon(name)
    end
end

-- ═══════ GUI HELPERS ═══════
local function getImage(name)
    local item = IMAGE_DB[name]
    if item then return item.hd or item.image end
    return ""
end

local selectedSkinData   = nil
local selectedCaseFilter = "All"
local weaponGrid         = nil
local skinGrid           = nil

local function refreshSkinGrid()
    if not skinGrid then return end
    skinGrid:clear_cards()
    if not TARGET_WEAPON then return end
    if not compatReady then
        skinGrid:add_card({name = "Loading...", image = ""})
        return
    end
    local skins = compatCache[TARGET_WEAPON] or {}
    for _, skinInfo in ipairs(skins) do
        if selectedCaseFilter == "All" or skinInfo.case == selectedCaseFilter then
            local info = skinInfo
            skinGrid:add_card({
                name     = info.name,
                image    = getImage(info.name),
                callback = function()
                    selectedSkinData = info
                end
            })
        end
    end
end


local window = library:window({name = "Rivals Skin Changer", size = dim2(0, 750, 0, 782)})

-- Hide UI during progressive loading
local _loadingUI = true
pcall(function()
    for _, gui in library.guis do
        if gui and gui:IsA("ScreenGui") then
            gui.Enabled = false
        end
    end
end)

do
    local _origSetMenuVis = window.set_menu_visibility

    window.set_menu_visibility = function(vis)
        if _loadingUI then return end
        menuVisible = (vis == true)
        if not menuVisible and not _espUnlocked then
            _espUnlocked = true
        end
        return _origSetMenuVis(vis)
    end
end

task.wait()

local _C = {}
do
    local Tab        = window:tab({name = "Skin Changer"})
    local TabStats   = window:tab({name = "Stats"})
    local TabVisuals = window:tab({name = "Visuals"})
    task.wait()
    local TabAim     = window:tab({name = "Aim"})
    local TabWorld   = window:tab({name = "World"})
    local TabExtras    = window:tab({name = "Extras"})
    local TabWeapons   = window:tab({name = "Weapons"})
    local TabInventory = window:tab({name = "Inventory"})
    task.wait()

    _C.skinCol      = Tab:column()
    _C.statsCol     = TabStats:column()
    _C.visualsCol   = TabVisuals:column()
    _C.aimCol       = TabAim:column()
    _C.worldCol     = TabWorld:column()
    _C.extrasCol    = TabExtras:column()
    _C.extrasCol2   = TabExtras:column()
    _C.weaponsCol   = TabWeapons:column()
    _C.weaponsCol2  = TabWeapons:column()
    _C.inventoryCol = TabInventory:column()
    _C.openTab      = Tab.open_tab
end

-- ═══════ WEAPON SECTION (V2 Image Grid) ═══════
local wSection = _C.skinCol:section({name = "Weapons"})

wSection:textbox({
    name     = "Search",
    flag     = "weapon_search",
    callback = function(text)
        if not weaponGrid then return end
        local q = text:lower()
        for _, card in ipairs(weaponGrid.cards) do
            card.outline.Visible = q == "" or card.name:lower():find(q, 1, true) ~= nil
        end
    end
})

weaponGrid = wSection:image_grid({
    height    = 210,
    card_size = UDim2.new(0, 75, 0, 90),
    callback  = function(wName)
        TARGET_WEAPON    = wName
        selectedSkinData = nil
        refreshSkinGrid()
    end
})

-- ═══════ COSMETIC SECTION ═══════
local cSection = _C.skinCol:section({name = "Cosmetics"})

local caseItems = {"All"}
for _, name in ipairs(skinCaseList) do
    table.insert(caseItems, name)
end

cSection:dropdown({
    name     = "Case",
    flag     = "case_filter",
    items    = caseItems,
    callback = function(selected)
        selectedCaseFilter = selected or "All"
        refreshSkinGrid()
    end
})

cSection:textbox({
    name     = "Search Skin",
    flag     = "skin_search",
    callback = function(text)
        if not skinGrid then return end
        local q = text:lower()
        for _, card in ipairs(skinGrid.cards) do
            card.outline.Visible = q == "" or card.name:lower():find(q, 1, true) ~= nil
        end
    end
})

skinGrid = cSection:image_grid({
    height    = 140,
    card_size = UDim2.new(0, 75, 0, 90),
})

cSection:button_holder({})
cSection:button({name = "Apply Skin", callback = function()
    if TARGET_WEAPON and selectedSkinData then
        applySkin(TARGET_WEAPON, selectedSkinData.case, selectedSkinData.name)
    end
end})

cSection:button_holder({})
cSection:button({name = "Reset Weapon", callback = function()
    if TARGET_WEAPON then resetWeapon(TARGET_WEAPON) end
end})
cSection:button({name = "Reset All", callback = resetAllWeapons})

-- ═══════ POPULATE WEAPON CARDS ═══════
task.spawn(function()
    for i, wName in ipairs(weaponList) do
        weaponGrid:add_card({
            name  = wName,
            image = getImage(wName),
        })
        if i % 8 == 0 then task.wait() end
    end
end)

-- ══════════════════════════════════════════════════════
--  TAB: INVENTORY (Unlock All / Wrap / Skin / Charm / Complementary)
-- ══════════════════════════════════════════════════════
do

_G._inv = {
    bypassActive = false,
    remotesActive = false,
    equipped = {},
    favorites = {},
    constructingWeapon = nil,
    viewingProfile = nil,
    lastUsedWeapon = nil,
    equipRemote = nil,
    favoriteRemote = nil,
    useItemRemote = nil,
    fighterController = nil,
    modules = {},
    weapons = {
        "Assault Rifle","Bow","Burst Rifle","Flamethrower",
        "Grenade Launcher","Minigun","Paintball Gun","RPG",
        "Shotgun","Sniper","Handgun","Flare Gun","Exogun",
        "Revolver","Shorty","Slingshot","Uzi","Fists",
        "Chainsaw","Katana","Knife","Scythe","Trowel",
        "Grenade","Flashbang","Medkit","Molotov","Smoke Grenade",
        "Subspace Tripmine","Freeze Ray","War Horn","Satchel",
        "Battle Axe","Riot Shield","Daggers","Energy Pistols",
        "Energy Rifle","Spray","Crossbow","Gunblade",
        "Jump Pad","Distortion","Warper","Warpstone",
        "Maul","Permafrost",
    },
}

function _G._inv.getModules()
    local s = _G._inv
    if s.modules.loaded then return s.modules end
    local lp = game:GetService("Players").LocalPlayer
    local RS = game:GetService("ReplicatedStorage")
    pcall(function() s.modules.EnumLib = require(RS.Modules:WaitForChild("EnumLibrary",5)); if s.modules.EnumLib then s.modules.EnumLib:WaitForEnumBuilder() end end)
    pcall(function() s.modules.CosLib = require(RS.Modules:WaitForChild("CosmeticLibrary",5)) end)
    pcall(function() s.modules.ItemLib = require(RS.Modules:WaitForChild("ItemLibrary",5)) end)
    pcall(function() s.modules.DC = require(lp.PlayerScripts.Controllers:WaitForChild("PlayerDataController",5)) end)
    if s.modules.DC then pcall(function() if s.modules.DC.WaitUntilLoaded then s.modules.DC:WaitUntilLoaded() end end) end
    s.modules.loaded = true
    return s.modules
end

function _G._inv.unlockWeapons()
    task.spawn(function()
        local m = _G._inv.getModules()
        if not m.DC then warn("[Inventory] DataController not found") return end
        local inv = m.DC:Get("WeaponInventory")
        if not inv then warn("[Inventory] WeaponInventory nil") return end
        local owned = {}
        for _,wd in pairs(inv) do if type(wd)=="table" and wd.Name then owned[wd.Name]=true end end
        local added = 0
        for _,name in ipairs(_G._inv.weapons) do
            if not owned[name] then table.insert(inv,{Name=name,Level=1,XP=0,IsFavorited=false}); added=added+1 end
        end
        if added>0 then pcall(function() m.DC.CurrentData:Replicate("WeaponInventory") end); print("[Inventory] "..added.." weapons unlocked!")
        else print("[Inventory] All weapons already unlocked") end
    end)
end

function _G._inv.unlockCosmetics(cosmeticType)
    task.spawn(function()
        local m = _G._inv.getModules()
        if not m.CosLib then warn("[Inventory] CosmeticLibrary not found") return end
        local count = 0
        for _,data in pairs(m.CosLib.Cosmetics or {}) do
            if cosmeticType==nil or (data.Type and tostring(data.Type):lower():find(cosmeticType:lower())) then count=count+1 end
        end
        m.CosLib.OwnsCosmeticNormally = function() return true end
        m.CosLib.OwnsCosmeticUniversally = function() return true end
        m.CosLib.OwnsCosmeticForWeapon = function() return true end
        local orig = m.CosLib.OwnsCosmetic
        if orig then m.CosLib.OwnsCosmetic = function(self,inv,n,w) if n and n:find("MISSING_") then return orig(self,inv,n,w) end; return true end end
        if m.DC then
            local origGet = m.DC.Get
            m.DC.Get = function(self,key)
                local d = origGet(self,key)
                if key=="CosmeticInventory" then local p={}; if d then for k,v in pairs(d) do p[k]=v end end; return setmetatable(p,{__index=function() return true end}) end
                return d
            end
        end
        print("[Inventory] "..(cosmeticType or "All").." unlocked! ("..count.." cosmetics)")
    end)
end

function _G._inv.runBypass()
    if _G._inv.bypassActive then print("[Inventory] Bypass already active") return end
    task.spawn(function()
        local s = _G._inv
        local lp = game:GetService("Players").LocalPlayer
        local RF = game:GetService("ReplicatedFirst")
        local fake = Instance.new("RemoteEvent"); fake.Name="ClientAlert"; fake.Parent=lp
        local pmt = getrawmetatable(lp); local oldPNc = pmt.__namecall
        setreadonly(pmt,false)
        pmt.__namecall = newcclosure(function(self,...)
            if getnamecallmethod()=="WaitForChild" and select(1,...)=="ClientAlert" then return fake end
            return oldPNc(self,...)
        end)
        setreadonly(pmt,true)
        task.wait()
        local mt = getrawmetatable(game); local origNc = mt.__namecall
        setreadonly(mt,false)
        mt.__namecall = newcclosure(function(self,...)
            local mn = getnamecallmethod()
            if self==lp and (mn=="Kick" or mn=="kick") then return end
            if mn=="Shutdown" then return end
            if mn=="FireServer" and self==fake then return end
            if s.remotesActive and mn=="FireServer" then
                local args = {...}
                if s.useItemRemote and self==s.useItemRemote and s.fighterController then
                    pcall(function() local f=s.fighterController:GetFighter(lp); if f and f.Items then for _,it in pairs(f.Items) do if it:Get("ObjectID")==args[1] then s.lastUsedWeapon=it.Name; break end end end end)
                end
                if s.equipRemote and self==s.equipRemote then
                    local m2 = s.getModules()
                    local wn,ct,cn,opt = args[1],args[2],args[3],args[4] or {}
                    if cn and cn~="None" and cn~="" then local inv = m2.DC and m2.DC:Get("CosmeticInventory"); if inv and rawget(inv,cn) then return origNc(self,...) end end
                    s.equipped[wn] = s.equipped[wn] or {}
                    if not cn or cn=="None" or cn=="" then s.equipped[wn][ct]=nil; if not next(s.equipped[wn]) then s.equipped[wn]=nil end
                    else local cl = s.cloneCosmetic(cn,ct,{inverted=opt.IsInverted,favoritesOnly=opt.OnlyUseFavorites}); if cl then s.equipped[wn][ct]=cl end end
                    task.defer(function() pcall(function() m2.DC.CurrentData:Replicate("WeaponInventory") end); task.wait(0.2); s.saveConfig() end)
                    return
                end
                if s.favoriteRemote and self==s.favoriteRemote then
                    s.favorites[args[1]] = s.favorites[args[1]] or {}; s.favorites[args[1]][args[2]] = args[3] or nil
                    s.saveConfig(); task.spawn(function() pcall(function() s.getModules().DC.CurrentData:Replicate("FavoritedCosmetics") end) end)
                    return
                end
            end
            return origNc(self,...)
        end)
        setreadonly(mt,true)
        task.wait()
        local ls3 = RF:WaitForChild("LocalScript3",10); task.wait()
        local n = 0
        if ls3 then
            local gc = getgc(false)
            for i,f in ipairs(gc) do
                if i%500==0 then task.wait() end
                if typeof(f)=="function" then
                    local ok,e = pcall(getfenv,f)
                    if ok and e then local scr=rawget(e,"script")
                        if scr and (scr==ls3 or tostring(scr):find("LoadingScreen")) then
                            local ok2,cs = pcall(debug.getconstants,f)
                            if ok2 then for _,k in ipairs(cs) do if typeof(k)=="string" and (k:find("TakeTheL") or k:find("ban") or k:find("kick")) then hookfunction(f,function() end); n=n+1; break end end end
                        end
                    end
                end
            end
            gc = nil
        end
        s.bypassActive = true
        print("[Inventory] Bypass AC enabled — "..n.." functions neutralized")
    end)
end

function _G._inv.cloneCosmetic(name,cosmeticType,options)
    local m = _G._inv.getModules()
    if not m.CosLib then return nil end
    local base = m.CosLib.Cosmetics[name]; if not base then return nil end
    local data = {}; for k,v in pairs(base) do data[k]=v end
    data.Name=name; data.Type=data.Type or cosmeticType; data.Seed=data.Seed or math.random(1,1000000)
    if m.EnumLib then local ok,eid = pcall(m.EnumLib.ToEnum,m.EnumLib,name); if ok and eid then data.Enum=eid; data.ObjectID=data.ObjectID or eid end end
    if options then if options.inverted~=nil then data.Inverted=options.inverted end; if options.favoritesOnly~=nil then data.OnlyUseFavorites=options.favoritesOnly end end
    return data
end

do
    local _invSavePending = false
    function _G._inv.saveConfig()
        if not writefile then return end
        if _invSavePending then return end
        _invSavePending = true
        task.delay(1, function()
            _invSavePending = false
            pcall(function()
                local cfg = {equipped={},favorites=_G._inv.favorites}
                for w,cos in pairs(_G._inv.equipped) do cfg.equipped[w]={}; for ct,cd in pairs(cos) do if cd and cd.Name then cfg.equipped[w][ct]={name=cd.Name,seed=cd.Seed,inverted=cd.Inverted} end end end
                makefolder("unlockall"); writefile("unlockall/config.json",game:GetService("HttpService"):JSONEncode(cfg))
            end)
        end)
    end
end

function _G._inv.loadConfig()
    if not readfile or not isfile or not isfile("unlockall/config.json") then return end
    pcall(function()
        local cfg = game:GetService("HttpService"):JSONDecode(readfile("unlockall/config.json"))
        if cfg.equipped then for w,cos in pairs(cfg.equipped) do _G._inv.equipped[w]={}; for ct,cd in pairs(cos) do local cl=_G._inv.cloneCosmetic(cd.name,ct,{inverted=cd.inverted}); if cl then cl.Seed=cd.seed; _G._inv.equipped[w][ct]=cl end end end end
        _G._inv.favorites = cfg.favorites or {}
    end)
end

function _G._inv.runRemoteHooks()
    if _G._inv.remotesActive then print("[Inventory] Remotes already hooked") return end
    task.spawn(function()
        local s = _G._inv
        local m = s.getModules()
        if not m.DC then warn("[Inventory] DataController required") return end
        local lp = game:GetService("Players").LocalPlayer
        local RS = game:GetService("ReplicatedStorage")
        if m.CosLib then
            m.CosLib.OwnsCosmeticNormally=function() return true end; m.CosLib.OwnsCosmeticUniversally=function() return true end; m.CosLib.OwnsCosmeticForWeapon=function() return true end
            local oo = m.CosLib.OwnsCosmetic; m.CosLib.OwnsCosmetic=function(self,inv,n,w) if n:find("MISSING_") then return oo(self,inv,n,w) end; return true end
        end; task.wait()
        local origGet = m.DC.Get
        m.DC.Get = function(self,key)
            local d = origGet(self,key)
            if key=="CosmeticInventory" then local p={}; if d then for k,v in pairs(d) do p[k]=v end end; return setmetatable(p,{__index=function() return true end}) end
            if key=="FavoritedCosmetics" then local r=d and table.clone(d) or {}; for w,fv in pairs(s.favorites) do r[w]=r[w] or {}; for n,f in pairs(fv) do r[w][n]=f end end; return r end
            return d
        end
        local origGWD = m.DC.GetWeaponData
        m.DC.GetWeaponData = function(self,wn) local d=origGWD(self,wn); if not d then return nil end; local mg={}; for k,v in pairs(d) do mg[k]=v end; mg.Name=wn; if s.equipped[wn] then for ct,cd in pairs(s.equipped[wn]) do mg[ct]=cd end end; return mg end
        task.wait()
        pcall(function() s.fighterController = require(lp.PlayerScripts.Controllers:WaitForChild("FighterController",5)) end)
        local rem = RS:FindFirstChild("Remotes"); local dr = rem and rem:FindFirstChild("Data")
        s.equipRemote = dr and dr:FindFirstChild("EquipCosmetic"); s.favoriteRemote = dr and dr:FindFirstChild("FavoriteCosmetic")
        local rr = rem and rem:FindFirstChild("Replication"); local fr = rr and rr:FindFirstChild("Fighter"); s.useItemRemote = fr and fr:FindFirstChild("UseItem")
        task.wait()
        local CI; pcall(function() CI=require(lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem) end); task.wait()
        if CI and CI._CreateViewModel then
            local oCVM = CI._CreateViewModel
            CI._CreateViewModel = function(self,vmRef)
                local wn,wp = self.Name, self.ClientFighter and self.ClientFighter.Player
                s.constructingWeapon = (wp==lp) and wn or nil
                if wp==lp and s.equipped[wn] and s.equipped[wn].Skin and vmRef then
                    local dk,sk,nk = self:ToEnum("Data"),self:ToEnum("Skin"),self:ToEnum("Name")
                    if vmRef[dk] then vmRef[dk][sk]=s.equipped[wn].Skin; vmRef[dk][nk]=s.equipped[wn].Skin.Name
                    elseif vmRef.Data then vmRef.Data.Skin=s.equipped[wn].Skin; vmRef.Data.Name=s.equipped[wn].Skin.Name end
                end
                local r = oCVM(self,vmRef); s.constructingWeapon=nil; return r
            end
        end; task.wait()
        local vmM; pcall(function() vmM=lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem:FindFirstChild("ClientViewModel") end); task.wait()
        if vmM then
            local CVM = require(vmM)
            if CVM.GetWrap then local oGW=CVM.GetWrap; CVM.GetWrap=function(self) local wn=self.ClientItem and self.ClientItem.Name; local wp=self.ClientItem and self.ClientItem.ClientFighter and self.ClientItem.ClientFighter.Player; if wn and wp==lp and s.equipped[wn] and s.equipped[wn].Wrap then return s.equipped[wn].Wrap end; return oGW(self) end end
            local oN = CVM.new
            CVM.new = function(rd,ci)
                local wp=ci.ClientFighter and ci.ClientFighter.Player; local wn=s.constructingWeapon or ci.Name
                if wp==lp and s.equipped[wn] then local RC=require(RS.Modules.ReplicatedClass); local dk=RC:ToEnum("Data"); rd[dk]=rd[dk] or {}; local c=s.equipped[wn]; if c.Skin then rd[dk][RC:ToEnum("Skin")]=c.Skin end; if c.Wrap then rd[dk][RC:ToEnum("Wrap")]=c.Wrap end; if c.Charm then rd[dk][RC:ToEnum("Charm")]=c.Charm end end
                local r = oN(rd,ci)
                if wp==lp and s.equipped[wn] and s.equipped[wn].Wrap and r._UpdateWrap then r:_UpdateWrap(); task.delay(0.1,function() if not r._destroyed then r:_UpdateWrap() end end) end
                return r
            end
        end; task.wait()
        if m.ItemLib and m.ItemLib.GetViewModelImageFromWeaponData then
            local oGV = m.ItemLib.GetViewModelImageFromWeaponData
            m.ItemLib.GetViewModelImageFromWeaponData = function(self,wd,hr)
                if not wd then return oGV(self,wd,hr) end; local wn=wd.Name
                local sh = (wd.Skin and s.equipped[wn] and wd.Skin==s.equipped[wn].Skin) or (s.viewingProfile==lp and s.equipped[wn] and s.equipped[wn].Skin)
                if sh and s.equipped[wn] and s.equipped[wn].Skin then local si=self.ViewModels[s.equipped[wn].Skin.Name]; if si then return si[hr and "ImageHighResolution" or "Image"] or si.Image end end
                return oGV(self,wd,hr)
            end
        end
        pcall(function() local VP=require(lp.PlayerScripts.Modules.Pages.ViewProfile); if VP and VP.Fetch then local oF=VP.Fetch; VP.Fetch=function(self,tp) s.viewingProfile=tp; return oF(self,tp) end end end); task.wait()
        local CE; pcall(function() CE=require(lp.PlayerScripts.Modules.ClientReplicatedClasses.ClientEntity) end); task.wait()
        if CE and CE.ReplicateFromServer then
            local oRFS = CE.ReplicateFromServer
            CE.ReplicateFromServer = function(self,action,...)
                if action=="FinisherEffect" then
                    local args={...}; local kn=args[3]; local dk=kn
                    if type(kn)=="userdata" and m.EnumLib and m.EnumLib.FromEnum then local ok,dec=pcall(m.EnumLib.FromEnum,m.EnumLib,kn); if ok and dec then dk=dec end end
                    local isO = tostring(dk)==lp.Name or tostring(dk):lower()==lp.Name:lower()
                    if isO and s.lastUsedWeapon and s.equipped[s.lastUsedWeapon] and s.equipped[s.lastUsedWeapon].Finisher then
                        local fd=s.equipped[s.lastUsedWeapon].Finisher; local fe=fd.Enum
                        if not fe and m.EnumLib then local ok,r=pcall(m.EnumLib.ToEnum,m.EnumLib,fd.Name); if ok and r then fe=r end end
                        if fe then args[1]=fe; return oRFS(self,action,unpack(args)) end
                    end
                end
                return oRFS(self,action,...)
            end
        end
        s.loadConfig()
        s.remotesActive = true
        print("[Inventory] Remotes + ViewModels + Finisher hooked!")
    end)
end

local secInv = _C.inventoryCol:section({name = "Inventory", toggle = false})

secInv:toggle({name = "Bypass Anti-Cheat", flag = "InvBypassAC", callback = function(v) if v then _G._inv.runBypass() end end})
secInv:toggle({name = "Remote Hooks", flag = "InvRemoteHooks", callback = function(v) if v then _G._inv.runRemoteHooks() end end})

local _invCooldown = false
local function invBtn(sec, name, fn)
    sec:button({name = name, callback = function()
        if _invCooldown then return end
        _invCooldown = true
        task.spawn(function()
            fn()
            task.wait(3)
            _invCooldown = false
        end)
    end})
end

secInv:button_holder({})
invBtn(secInv, "Unlock All", function() _G._inv.unlockWeapons(); task.wait(0.5); _G._inv.unlockCosmetics(nil) end)
invBtn(secInv, "Unlock Weapons", function() _G._inv.unlockWeapons() end)

secInv:button_holder({})
invBtn(secInv, "Unlock Wrap", function() _G._inv.unlockCosmetics("Wrap") end)
invBtn(secInv, "Unlock Skin", function() _G._inv.unlockCosmetics("Skin") end)

secInv:button_holder({})
invBtn(secInv, "Unlock Charm", function() _G._inv.unlockCosmetics("Charm") end)
invBtn(secInv, "Unlock Complementary", function() _G._inv.unlockCosmetics("Complementary") end)

end -- do Inventory

task.wait()

local lp = game:GetService("Players").LocalPlayer
local cls = lp:FindFirstChild("CustomLeaderstats")

local secStats = _C.statsCol:section({name = "Player Stats", toggle = false})

secStats:label({name = "Level"})
secStats:textbox({flag = "level_tb", placeholder = tostring(lp:GetAttribute("Level") or 0), callback = function(val)
    local n = tonumber(val)
    if n then lp:SetAttribute("Level", n) end
end})

secStats:label({name = "Win Streak"})
secStats:textbox({flag = "winstreak_tb", placeholder = tostring(lp:GetAttribute("StatisticDuelsWinStreak") or 0), callback = function(val)
    local n = tonumber(val)
    if n then lp:SetAttribute("StatisticDuelsWinStreak", n) end
end})

local eloVal = cls and cls:FindFirstChild("Current ELO")
if eloVal then
    secStats:label({name = "Current ELO"})
    secStats:textbox({flag = "elo_tb", placeholder = tostring(eloVal.Value), callback = function(val)
        local n = tonumber(val)
        if n then eloVal.Value = n end
    end})
end

secStats:button_holder({})
secStats:button({name = "Refresh stats", callback = function()
end})

task.wait()

local esp
local function update_elements()
    if esp and esp.refresh_elements then esp.refresh_elements() end
end

local secV = _C.visualsCol:section({name = "Visuals", toggle = false})

secV:toggle({name = "Enabled",  flag = "Enabled",  callback = update_elements})
secV:toggle({name = "Names",    flag = "Names",    callback = function() end})
    :colorpicker({flag = "Name_Color", color = Color3.new(1, 1, 1), callback = update_elements})
local boxSettings = secV:toggle({name = "Boxes", flag = "Boxes", callback = update_elements})
secV:dropdown({name = "Box Type", flag = "Box_Type", items = {"Corner", "Full", "3D Box"}, default = "Corner", callback = update_elements})
boxSettings:colorpicker({name = "Box Color", flag = "Box_Color", color = Color3.new(1, 1, 1), callback = update_elements})
local fillToggle = secV:toggle({name = "Box Fill", flag = "BoxFill", callback = function() end})
fillToggle:colorpicker({flag = "BoxFill_Color", color = Color3.fromRGB(255, 255, 255), callback = function() end})
secV:slider({name = "Fill Transparency %", flag = "BoxFill_Alpha", min = 1, max = 95, default = 75, callback = function() end})
local hdotToggle = secV:toggle({name = "Head Dot", flag = "HeadDot", callback = function() end})
hdotToggle:colorpicker({flag = "HeadDot_Color", color = Color3.fromRGB(255, 50, 50), callback = function() end})
local hpToggle = secV:toggle({name = "Healthbar", flag = "Healthbar", callback = update_elements})
hpToggle:colorpicker({name = "High HP Color", flag = "Health_High", color = Color3.fromRGB(0, 255, 0), callback = update_elements})
hpToggle:colorpicker({name = "Low HP Color",  flag = "Health_Low",  color = Color3.fromRGB(255, 0, 0), callback = update_elements})
secV:toggle({name = "Distance", flag = "Distance", callback = update_elements})
    :colorpicker({flag = "Distance_Color", color = Color3.new(1, 1, 1), callback = update_elements})
secV:slider({name = "Max Distance (studs)", flag = "Max_Distance", min = 10, max = 2000, default = 500, callback = function() end})
secV:toggle({name = "Weapon",   flag = "Weapon",   callback = update_elements})
    :colorpicker({flag = "Weapon_Color",   color = Color3.new(1, 1, 1), callback = update_elements})
local skelToggle = secV:toggle({name = "Skeleton", flag = "Skeleton", callback = update_elements})
skelToggle:colorpicker({flag = "Skeleton_Color", color = Color3.new(1, 1, 1), callback = update_elements})
local snapToggle = secV:toggle({name = "Snaplines", flag = "Snaplines", callback = update_elements})
snapToggle:colorpicker({flag = "Snapline_Color", color = Color3.fromRGB(255, 50, 50), callback = update_elements})
secV:dropdown({name = "Snapline Origin", flag = "SnaplineOrigin", items = {"Bottom", "Center", "Top", "Mouse"}, default = "Bottom", callback = update_elements})
secV:toggle({name = "Visible Check (dim behind walls)", flag = "VisCheck", callback = update_elements})
secV:toggle({name = "Team Check", flag = "ESPTeamCheck", callback = update_elements})

secV:toggle({name = "Chams", flag = "ChamsEnabled", callback = function() end})
    :colorpicker({flag = "Chams_Color", color = Color3.fromRGB(170, 0, 255), callback = function() end})
secV:toggle({name = "Chams Outline", flag = "ChamsOutline", callback = function() end})
    :colorpicker({flag = "ChamsOutline_Color", color = Color3.fromRGB(255, 255, 255), callback = function() end})
secV:slider({name = "Chams Fill Transparency", flag = "ChamsFillAlpha", min = 0, max = 100, default = 30, callback = function() end})
secV:slider({name = "Chams Outline Transparency", flag = "ChamsOutAlpha", min = 0, max = 100, default = 0, callback = function() end})
secV:dropdown({name = "Chams Depth", flag = "ChamsDepth", items = {"AlwaysOnTop", "Occluded"}, default = "AlwaysOnTop", callback = function() end})
secV:toggle({name = "China Hat", flag = "ChinaHat", callback = function() end})
    :colorpicker({flag = "ChinaHat_Color", color = Color3.fromRGB(190, 100, 255), callback = function() end})
secV:slider({name = "Hat Radius", flag = "ChinaHat_Radius", min = 5, max = 30, default = 13, callback = function() end})
secV:slider({name = "Hat Height", flag = "ChinaHat_Height", min = 1, max = 20, default = 7, callback = function() end})

local swToggle = secV:toggle({name = "Sound Waves", flag = "SoundWaves", callback = function() end})
    :colorpicker({flag = "SoundWaves_Color", color = Color3.fromRGB(0, 200, 255), callback = function() end})
secV:slider({name = "Wave Max Radius", flag = "SW_MaxRadius", min = 5, max = 40, default = 20, callback = function() end})
secV:slider({name = "Wave Duration (s)", flag = "SW_Duration", min = 5, max = 30, default = 15, suffix = "", callback = function() end})
secV:slider({name = "Wave Thickness", flag = "SW_Thickness", min = 1, max = 5, default = 2, callback = function() end})

local mtToggle = secV:toggle({name = "Motion Trails", flag = "MotionTrails", callback = function() end})
mtToggle:colorpicker({flag = "MT_Color", color = Color3.fromRGB(190, 100, 255), callback = function() end})
secV:slider({name = "Trail Duration (x0.1s)", flag = "MT_Duration", min = 3, max = 30, default = 12, callback = function() end})
secV:slider({name = "Trail Thickness", flag = "MT_Thickness", min = 1, max = 5, default = 1, callback = function() end})

task.wait()

local secAim = _C.aimCol:section({name = "Aim", toggle = false})

secAim:label({name = "— Silent Aim —"})
secAim:toggle({name = "Silent Aim", flag = "SilentAim", callback = function() end})
    :keybind({name = "Aim Key", flag = "AimKey", key = Enum.KeyCode.V, mode = "hold", callback = function() end})
secAim:dropdown({name = "Target Part", flag = "Aim_Part", items = {"Head", "UpperTorso", "HumanoidRootPart"}, default = "Head", callback = function() end})
secAim:slider({name = "FOV", flag = "AimFOV", min = 10, max = 800, default = 150, callback = function() end})
if HAS_MOUSE1CLICK then
    secAim:toggle({name = "Auto Fire (Hold Key)", flag = "AimAutoFire", callback = function() end})
else
    secAim:toggle({name = "Auto Fire [N/A]", flag = "AimAutoFire", callback = function(v)
        if v then library.flags["AimAutoFire"] = false end
    end})
end
secAim:toggle({name = "Silent Aim on LMB", flag = "SilentLMB", callback = function() end})
secAim:toggle({name = "Visible Check", flag = "AimVisCheck", callback = function() end})
secAim:toggle({name = "Team Check", flag = "AimTeamCheck", callback = function() end})
secAim:toggle({name = "Anti Katana", flag = "AntiKatana", callback = function() end})
secAim:toggle({name = "Show FOV Circle", flag = "ShowFOV", callback = function() end})
    :colorpicker({flag = "FOV_Color", color = Color3.new(1, 1, 1), callback = function() end})

secAim:label({name = "— Aimbot —"})
if HAS_MOUSEMOVEREL then
    secAim:toggle({name = "Aimbot", flag = "AimbotEnabled", callback = function() end})
        :keybind({name = "Aimbot Key", flag = "AimbotKey", key = Enum.KeyCode.C, mode = "hold", callback = function() end})
    secAim:toggle({name = "Show FOV", flag = "AimbotShowFOV", callback = function() end})
        :colorpicker({flag = "AimbotFOV_Color", color = Color3.new(1, 1, 1), callback = function() end})
    secAim:toggle({name = "Prediction", flag = "AimbotPrediction", callback = function() end})
    secAim:slider({name = "FOV Size", flag = "AimbotFOV", min = 50, max = 800, default = 150, callback = function() end})
    secAim:slider({name = "Smoothness", flag = "AimbotSmooth", min = 1, max = 50, default = 12, callback = function() end})
    secAim:slider({name = "Prediction Amount", flag = "AimbotPredAmt", min = 50, max = 200, default = 100, callback = function() end})
    secAim:slider({name = "Max Distance", flag = "AimbotMaxDist", min = 50, max = 2000, default = 800, callback = function() end})
    secAim:dropdown({name = "Target Part (Aimbot)", flag = "Aimbot_Part", items = {"Head", "UpperTorso", "HumanoidRootPart"}, default = "Head", callback = function() end})
    secAim:dropdown({name = "Aim Mode", flag = "AimbotMode", items = {"Hold Key", "Hold RMB", "Hold LMB", "Both Mouse"}, default = "Hold Key", callback = function() end})
else
    secAim:label({name = "Aimbot requires mousemoverel"})
    secAim:label({name = "Not supported on " .. _executorName})
end

task.wait()

local Lighting = game:GetService("Lighting")
local _origSky = nil
local _origLighting = {
    ClockTime       = Lighting.ClockTime,
    Brightness      = Lighting.Brightness,
    FogEnd          = Lighting.FogEnd,
    FogStart        = Lighting.FogStart,
    FogColor        = Lighting.FogColor,
    Ambient         = Lighting.Ambient,
    OutdoorAmbient  = Lighting.OutdoorAmbient,
    ColorShift_Top  = Lighting.ColorShift_Top,
    ColorShift_Bottom = Lighting.ColorShift_Bottom,
    EnvironmentDiffuseScale  = Lighting.EnvironmentDiffuseScale,
    EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
    GlobalShadows   = Lighting.GlobalShadows,
    ExposureCompensation = Lighting.ExposureCompensation,
}
local _origPostFX = {}
for _, fx in ipairs(Lighting:GetChildren()) do
    if fx:IsA("PostEffect") then
        _origPostFX[fx] = fx.Enabled
    end
end

task.wait()

local _worldReady = false

local function _restoreWorld()
    for k, v in pairs(_origLighting) do
        pcall(function() Lighting[k] = v end)
    end
    for fx, enabled in pairs(_origPostFX) do
        pcall(function() fx.Enabled = enabled end)
    end
    if _origSky then
        pcall(function()
            for _, s in ipairs(Lighting:GetChildren()) do
                if s:IsA("Sky") then s:Destroy() end
            end
            _origSky:Clone().Parent = Lighting
        end)
    end
end

local secWorld = _C.worldCol:section({name = "Lighting", toggle = false})

secWorld:slider({name = "Time", flag = "TimeOfDay", min = 0, max = 24, default = math.floor(Lighting.ClockTime), callback = function(v)
    if _worldReady then Lighting.ClockTime = v end
end})
secWorld:slider({name = "Brightness", flag = "WorldBrightness", min = 0, max = 5, default = math.floor(Lighting.Brightness), callback = function(v)
    if _worldReady then Lighting.Brightness = v end
end})
secWorld:slider({name = "Exposure", flag = "WorldExposure", min = -3, max = 3, default = 0, callback = function(v)
    if _worldReady then Lighting.ExposureCompensation = v end
end})
secWorld:slider({name = "Fog Start", flag = "FogStart", min = 0, max = 10000, default = math.min(10000, math.floor(Lighting.FogStart)), callback = function(v)
    if _worldReady then Lighting.FogStart = v end
end})
secWorld:slider({name = "Fog End", flag = "FogEnd", min = 100, max = 100000, default = math.min(100000, math.floor(Lighting.FogEnd)), callback = function(v)
    if _worldReady then Lighting.FogEnd = v end
end})

secWorld:toggle({name = "Ambient Override", flag = "AmbientOverride", callback = function(v)
    if not _worldReady then return end
    if not v then
        Lighting.Ambient = _origLighting.Ambient
        Lighting.OutdoorAmbient = _origLighting.OutdoorAmbient
    end
end})
    :colorpicker({name = "Ambient Color", color = Color3.fromRGB(128, 128, 128), flag = "AmbientColor", callback = function(val)
        if _worldReady and library.flags["AmbientOverride"] then
            local c = (type(val) == "table" and typeof(val.Color) == "Color3") and val.Color or val
            Lighting.Ambient = c
            Lighting.OutdoorAmbient = c
        end
    end})

secWorld:toggle({name = "Fog Color Override", flag = "FogColorOverride", callback = function(v)
    if not _worldReady then return end
    if not v then Lighting.FogColor = _origLighting.FogColor end
end})
    :colorpicker({name = "Fog Color", color = Color3.fromRGB(128, 128, 128), flag = "FogColorPick", callback = function(val)
        if _worldReady and library.flags["FogColorOverride"] then
            local c = (type(val) == "table" and typeof(val.Color) == "Color3") and val.Color or val
            Lighting.FogColor = c
        end
    end})

secWorld:toggle({name = "Color Shift Top", flag = "ColorShiftTopOn", callback = function(v)
    if not _worldReady then return end
    if not v then Lighting.ColorShift_Top = _origLighting.ColorShift_Top end
end})
    :colorpicker({name = "Top", color = Color3.fromRGB(255, 200, 150), flag = "ColorShiftTopColor", callback = function(val)
        if _worldReady and library.flags["ColorShiftTopOn"] then
            local c = (type(val) == "table" and typeof(val.Color) == "Color3") and val.Color or val
            Lighting.ColorShift_Top = c
        end
    end})

secWorld:toggle({name = "Color Shift Bottom", flag = "ColorShiftBotOn", callback = function(v)
    if not _worldReady then return end
    if not v then Lighting.ColorShift_Bottom = _origLighting.ColorShift_Bottom end
end})
    :colorpicker({name = "Bottom", color = Color3.fromRGB(100, 100, 255), flag = "ColorShiftBotColor", callback = function(val)
        if _worldReady and library.flags["ColorShiftBotOn"] then
            local c = (type(val) == "table" and typeof(val.Color) == "Color3") and val.Color or val
            Lighting.ColorShift_Bottom = c
        end
    end})

secWorld:slider({name = "Diffuse Scale", flag = "EnvDiffuse", min = 0, max = 100, default = math.floor(_origLighting.EnvironmentDiffuseScale * 100), callback = function(v)
    if _worldReady then Lighting.EnvironmentDiffuseScale = v / 100 end
end})
secWorld:slider({name = "Specular Scale", flag = "EnvSpecular", min = 0, max = 100, default = math.floor(_origLighting.EnvironmentSpecularScale * 100), callback = function(v)
    if _worldReady then Lighting.EnvironmentSpecularScale = v / 100 end
end})

secWorld:toggle({name = "Remove Sky", flag = "RemoveSky", callback = function(v)
    if not _worldReady then return end
    if v then
        _origSky = Lighting:FindFirstChildOfClass("Sky")
        if _origSky then _origSky.Parent = nil end
    elseif _origSky then
        _origSky.Parent = Lighting
    end
end})

secWorld:toggle({name = "No Shadows", flag = "NoShadows", callback = function(v)
    if not _worldReady then return end
    Lighting.GlobalShadows = not v
end})

secWorld:toggle({name = "No Post FX", flag = "NoPostFX", callback = function(v)
    if not _worldReady then return end
    for fx, orig in pairs(_origPostFX) do
        if fx and fx.Parent then
            fx.Enabled = v and false or orig
        end
    end
end})

secWorld:toggle({name = "Fullbright", flag = "Fullbright", callback = function(v)
    if not _worldReady then return end
    if v then
        Lighting.Ambient = Color3.new(1, 1, 1)
        Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
        Lighting.Brightness = 3
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient = _origLighting.Ambient
        Lighting.OutdoorAmbient = _origLighting.OutdoorAmbient
        Lighting.Brightness = _origLighting.Brightness
        Lighting.FogEnd = _origLighting.FogEnd
        Lighting.GlobalShadows = _origLighting.GlobalShadows
    end
end})

secWorld:toggle({name = "No Fog", flag = "NoFog", callback = function(v)
    if not _worldReady then return end
    if v then
        Lighting.FogStart = 0
        Lighting.FogEnd = 9999999
    else
        Lighting.FogStart = _origLighting.FogStart
        Lighting.FogEnd = _origLighting.FogEnd
    end
end})

secWorld:toggle({name = "Reset Lighting", flag = "ResetLightingToggle", callback = function(v)
    if not v then return end
    task.defer(function() library.flags["ResetLightingToggle"] = false end)
    for prop, val in pairs(_origLighting) do
        pcall(function() Lighting[prop] = val end)
    end
    for fx, orig in pairs(_origPostFX) do
        if fx and fx.Parent then fx.Enabled = orig end
    end
    if _origSky then _origSky.Parent = Lighting end
end})

local secEnv = _C.worldCol:section({name = "Environment", toggle = false})

do
    local _origParticles  = {}
    local _origDecals     = {}
    local _origMaterials  = {}
    local _origTransp     = {}
    local _origWater      = nil
    local _origQuality    = nil

    local function isCharPart(obj)
        for _, plr in ipairs(game:GetService("Players"):GetPlayers()) do
            if plr.Character and obj:IsDescendantOf(plr.Character) then return true end
        end
        return false
    end

    secEnv:toggle({name = "No Particles", flag = "NoParticles", callback = function(v)
        if not _worldReady then return end
        task.spawn(function()
            if v then
                _origParticles = {}
                local c = 0
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("ParticleEmitter") or obj:IsA("Fire") or obj:IsA("Smoke") or obj:IsA("Sparkles") then
                        _origParticles[obj] = obj.Enabled
                        obj.Enabled = false
                    end
                    c += 1; if c % 2000 == 0 then task.wait() end
                end
            else
                for obj, orig in pairs(_origParticles) do
                    pcall(function() obj.Enabled = orig end)
                end
                _origParticles = {}
            end
        end)
    end})

    secEnv:toggle({name = "Low Graphics", flag = "LowGraphics", callback = function(v)
        if not _worldReady then return end
        local ss = settings():GetService("RenderSettings")
        if v then
            _origQuality = ss.QualityLevel
            ss.QualityLevel = Enum.QualityLevel.Level01
        else
            ss.QualityLevel = _origQuality or Enum.QualityLevel.Automatic
        end
    end})

    secEnv:toggle({name = "Remove Decals", flag = "RemoveDecals", callback = function(v)
        if not _worldReady then return end
        task.spawn(function()
            if v then
                _origDecals = {}
                local c = 0
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("Decal") or obj:IsA("Texture") then
                        _origDecals[obj] = obj.Transparency
                        obj.Transparency = 1
                    end
                    c += 1; if c % 2000 == 0 then task.wait() end
                end
            else
                for obj, orig in pairs(_origDecals) do
                    pcall(function() obj.Transparency = orig end)
                end
                _origDecals = {}
            end
        end)
    end})

    secEnv:toggle({name = "Wireframe Parts", flag = "Wireframe", callback = function(v)
        if not _worldReady then return end
        task.spawn(function()
            if v then
                _origMaterials = {}
                local c = 0
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and obj ~= workspace.Terrain then
                        _origMaterials[obj] = obj.Material
                        obj.Material = Enum.Material.ForceField
                    end
                    c += 1; if c % 2000 == 0 then task.wait() end
                end
            else
                for obj, orig in pairs(_origMaterials) do
                    pcall(function() obj.Material = orig end)
                end
                _origMaterials = {}
            end
        end)
    end})

    secEnv:toggle({name = "Transparent Map", flag = "TransparentMap", callback = function(v)
        if not _worldReady then return end
        task.spawn(function()
            if v then
                _origTransp = {}
                local c = 0
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and obj ~= workspace.Terrain and not isCharPart(obj) then
                        _origTransp[obj] = obj.Transparency
                        obj.Transparency = 0.7
                    end
                    c += 1; if c % 2000 == 0 then task.wait() end
                end
            else
                for obj, orig in pairs(_origTransp) do
                    pcall(function() obj.Transparency = orig end)
                end
                _origTransp = {}
            end
        end)
    end})

    secEnv:slider({name = "Map Transparency", flag = "MapTranspSlider", min = 0, max = 100, default = 0, callback = function(val)
        if not _worldReady then return end
        task.spawn(function()
            local t = val / 100
            if t == 0 and next(_origTransp) then
                for obj, orig in pairs(_origTransp) do
                    pcall(function() obj.Transparency = orig end)
                end
                _origTransp = {}
                return
            end
            if not next(_origTransp) then
                _origTransp = {}
                local c = 0
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and obj ~= workspace.Terrain and not isCharPart(obj) then
                        _origTransp[obj] = obj.Transparency
                    end
                    c += 1; if c % 2000 == 0 then task.wait() end
                end
            end
            for obj in pairs(_origTransp) do
                pcall(function() obj.Transparency = t end)
            end
        end)
    end})

    secEnv:toggle({name = "No Terrain Water", flag = "NoWater", callback = function(v)
        if not _worldReady then return end
        if v then
            _origWater = {
                Transparency = workspace.Terrain.WaterTransparency,
                Reflectance  = workspace.Terrain.WaterReflectance,
            }
            workspace.Terrain.WaterTransparency = 1
            workspace.Terrain.WaterReflectance = 0
        else
            if _origWater then
                workspace.Terrain.WaterTransparency = _origWater.Transparency
                workspace.Terrain.WaterReflectance  = _origWater.Reflectance
            end
        end
    end})

end

do
    local _origTextures = {}
    local _textureApplied = false

    local function getAllTextureInstances()
        local results = {}
        for _, obj in ipairs(workspace:GetDescendants()) do
            if obj:IsA("Texture") or obj:IsA("Decal") then
                table.insert(results, {inst = obj, prop = "Texture"})
            elseif obj:IsA("SurfaceAppearance") then
                table.insert(results, {inst = obj, prop = "ColorMap"})
            elseif obj:IsA("SpecialMesh") and obj.TextureId ~= "" then
                table.insert(results, {inst = obj, prop = "TextureId"})
            elseif obj:IsA("MeshPart") and obj.TextureID ~= "" then
                table.insert(results, {inst = obj, prop = "TextureID"})
            end
        end
        return results
    end

    local function applyTexture(id)
        _origTextures = {}
        local tid = (id and id ~= "") and id or "rbxassetid://0"
        for _, entry in ipairs(getAllTextureInstances()) do
            local ok, orig = pcall(function() return entry.inst[entry.prop] end)
            if ok then
                table.insert(_origTextures, {inst = entry.inst, prop = entry.prop, orig = orig})
                pcall(function() entry.inst[entry.prop] = tid end)
            end
        end
        _textureApplied = true
    end

    local function restoreTextures()
        for _, entry in ipairs(_origTextures) do
            pcall(function() entry.inst[entry.prop] = entry.orig end)
        end
        _origTextures = {}
        _textureApplied = false
    end

end

local secWorld2 = _C.worldCol:section({name = "Sky & Colors", toggle = false})

do

    local function getSkyProfilesFolder()
        local lp = game:GetService("Players").LocalPlayer
        local scripts = lp and lp:FindFirstChild("PlayerScripts")
        local assets = scripts and scripts:FindFirstChild("Assets")
        return assets and assets:FindFirstChild("LightingProfiles")
    end

    local _skyProfiles = {
        { label = "Profil 1",  type = "profile", index = 1 },
        { label = "Profil 2",  type = "profile", index = 2 },
        { label = "Profil 3",  type = "profile", index = 3 },
        { label = "Sky 1",     type = "asset",   id = 136402262   },
        { label = "Sky 2",     type = "asset",   id = 143962526   },
        { label = "Sky 3",     type = "asset",   id = 17279880951 },
        { label = "Sky 4",     type = "asset",   id = 93768215    },
        { label = "Sky 5",     type = "asset",   id = 17148953842 },
        { label = "Sky 6",     type = "asset",   id = 10558373344 },
    }

    local function applySkyProfile(prof)
        local existingSky = Lighting:FindFirstChildOfClass("Sky")
        if existingSky then existingSky:Destroy() end

        if prof.type == "profile" then
            local folder = getSkyProfilesFolder()
            if not folder then return end
            local children = folder:GetChildren()
            local profile = children[prof.index]
            if not profile then return end
            for _, child in ipairs(profile:GetChildren()) do
                if child:IsA("Sky") then child:Clone().Parent = Lighting; break end
            end
        elseif prof.type == "asset" then
            local ok, objects = pcall(function()
                return game:GetObjects("rbxassetid://" .. prof.id)
            end)
            if not ok then return end
            for _, obj in ipairs(objects) do
                if obj:IsA("Sky") then obj.Parent = Lighting; return end
                local found = obj:FindFirstChildOfClass("Sky", true)
                if found then found.Parent = Lighting; return end
            end

        end
    end

    local _skyLabels = {}
    for _, p in ipairs(_skyProfiles) do table.insert(_skyLabels, p.label) end

    secWorld2:label({name = "— Sky Profiles —"})
    secWorld2:dropdown({name = "Sky Profile", flag = "SkyProfile", items = (function()
        local labels = {"-- None --"}
        for _, p in ipairs(_skyProfiles) do table.insert(labels, p.label) end
        return labels
    end)(), callback = function(name)
        if not name or name == "-- None --" then return end
        for _, prof in ipairs(_skyProfiles) do
            if prof.label == name then
                applySkyProfile(prof)
                break
            end
        end
    end})
    secWorld2:toggle({name = "Reset Sky", flag = "ResetSkyToggle", callback = function(v)
        if v then
            local s = Lighting:FindFirstChildOfClass("Sky")
            if s then s:Destroy() end
            task.defer(function()
                library.flags["ResetSkyToggle"] = false
            end)
        end
    end})
end

do
    local WALL_KW = { "wall", "mur", "floor", "sol", "ceiling", "plafond", "brick", "ground", "base" }

    local function getExcludedRoots()
        local Plrs = game:GetService("Players")
        local set = {}
        for _, plr in ipairs(Plrs:GetPlayers()) do
            local char = plr.Character
            if char then set[char] = true end
            local nm = workspace:FindFirstChild(plr.Name)
            if nm then set[nm] = true end
        end
        local vm = workspace:FindFirstChild("ViewModels"); if vm then set[vm] = true end
        local sre = workspace:FindFirstChild("ShootingRangeEntities"); if sre then set[sre] = true end
        local lobby = workspace:FindFirstChild("Lobby")
        if lobby then
            local sr = lobby:FindFirstChild("ShootingRange")
            if sr then
                local imp = sr:FindFirstChild("Important")
                if imp then
                    local tc = imp:FindFirstChild("Trash Cans")
                    if tc then set[tc] = true end
                end
            end
        end
        return set
    end

    local function isExcluded(obj, roots)
        for root in pairs(roots) do
            if obj == root or obj:IsDescendantOf(root) then return true end
        end
        return false
    end

    local function getPickedColor()
        local v = library.flags["ColorMapColor"]
        if type(v) == "table" and typeof(v.Color) == "Color3" then return v.Color end
        if typeof(v) == "Color3" then return v end
        return Color3.fromRGB(255, 0, 0)
    end

    local function applyColorMap()
        if not library.flags["ColorMapEnabled"] then return end
        task.spawn(function()
            local color = getPickedColor()
            local mode = library.flags["ColorMapMode"] or "Walls & Floors"
            local roots = getExcludedRoots()
            local count, c = 0, 0
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj ~= workspace.Terrain and not isExcluded(obj, roots) then
                    if mode == "Color All" then
                        obj.Color = color; count += 1
                    else
                        local n = obj.Name:lower()
                        for _, kw in ipairs(WALL_KW) do
                            if n:find(kw) then obj.Color = color; count += 1; break end
                        end
                    end
                end
                c += 1; if c % 2000 == 0 then task.wait() end
            end
        end)
    end

    local function resetColorMap()
        task.spawn(function()
            local roots = getExcludedRoots()
            local count, c = 0, 0
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("BasePart") and obj ~= workspace.Terrain and not isExcluded(obj, roots) then
                    obj.Color = Color3.fromRGB(163, 162, 165)
                    obj.Transparency = 0
                    count += 1
                end
                c += 1; if c % 2000 == 0 then task.wait() end
            end
        end)
    end

    secWorld2:toggle({name = "Color Map", flag = "ColorMapEnabled", callback = function(v)
        if v then applyColorMap() end
    end})
        :colorpicker({name = "Color", color = Color3.fromRGB(255, 0, 0), flag = "ColorMapColor", callback = function()
            applyColorMap()
        end})

    secWorld2:dropdown({name = "Mode", flag = "ColorMapMode", items = {"Walls & Floors", "Color All"}, default = "Walls & Floors", callback = function()
        applyColorMap()
    end})

    secWorld2:toggle({name = "Reset Map Colors", flag = "ColorMapReset", callback = function(v)
        if v then resetColorMap() end
    end})
end

secV:slider({name = "Arms Transparency",    flag = "ArmsTransp",    min = 0, max = 100, default = 0, callback = function() end})
secV:slider({name = "Bullets Transparency", flag = "BulletsTransp", min = 0, max = 100, default = 0, callback = function() end})

secV:toggle({name = "Custom Tracer", flag = "CustomTracer"})
    :colorpicker({name = "Tracer Color", color = Color3.fromRGB(255, 0, 0), flag = "TracerColor"})
secV:dropdown({name = "Style", flag = "TracerStyle", items = {"Laser", "Plat"}, default = "Laser"})
secV:toggle({name = "Glow", flag = "TracerGlow"})
secV:slider({name = "Width", flag = "TracerWidth", min = 1, max = 50, default = 10, callback = function() end})
secV:slider({name = "Duration (ms)", flag = "TracerDuration", min = 100, max = 2000, default = 500, callback = function() end})

do
    local _tracerParts = {}

    local function getLaserColor()
        local v = library.flags["TracerColor"]
        if type(v) == "table" and typeof(v.Color) == "Color3" then return v.Color end
        if typeof(v) == "Color3" then return v end
        return Color3.new(1, 0, 0)
    end

    local function makeCylinder(startPos, endPos, diameter, color, transparency, material)
        local dist = (endPos - startPos).Magnitude
        local mid = (startPos + endPos) / 2
        local cyl = Instance.new("Part")
        cyl.Anchored = true
        cyl.CanCollide = false
        cyl.CanTouch = false
        cyl.CanQuery = false
        cyl.Shape = Enum.PartType.Cylinder
        cyl.Size = Vector3.new(dist, diameter, diameter)
        cyl.CFrame = CFrame.lookAt(mid, endPos) * CFrame.Angles(0, math.rad(90), 0)
        cyl.Material = material or Enum.Material.Neon
        cyl.Color = color
        cyl.Transparency = transparency
        cyl.CastShadow = false
        cyl.Parent = workspace
        return cyl
    end

    local function spawnLaser(startPos, endPos)
        local style = library.flags["TracerStyle"] or "Laser"
        local glow = library.flags["TracerGlow"]
        local w = (library.flags["TracerWidth"] or 10) / 50
        local duration = (library.flags["TracerDuration"] or 500) / 1000
        local col = getLaserColor()

        local parts = {}

        if style == "Laser" then

            local diameter = math.max(0.05, w)
            parts[#parts + 1] = makeCylinder(startPos, endPos, diameter, col, 0, Enum.Material.Neon)
        else

            local diameter = math.max(0.02, w * 0.15)
            parts[#parts + 1] = makeCylinder(startPos, endPos, diameter, col, 0, Enum.Material.Neon)
        end

        if glow then
            local glowColor = Color3.new(
                col.R + (1 - col.R) * 0.5,
                col.G + (1 - col.G) * 0.5,
                col.B + (1 - col.B) * 0.5
            )
            local gDiam = (style == "Laser") and math.max(0.15, w * 3) or math.max(0.06, w * 0.8)
            parts[#parts + 1] = makeCylinder(startPos, endPos, gDiam, glowColor, 0.55, Enum.Material.ForceField)
        end

        local entry = {
            parts = parts,
            spawnTime = tick(),
            duration = duration,
            baseTransparencies = {},
        }
        for j, p in ipairs(parts) do
            entry.baseTransparencies[j] = p.Transparency
        end

        table.insert(_tracerParts, entry)
    end

    workspace.DescendantAdded:Connect(function(obj)
        if obj.Name ~= "TracerEffect" or not obj:IsA("BasePart") then return end
        obj.CanCollide = false
        obj.CanTouch = false
        obj.CanQuery = false
        if not library.flags["CustomTracer"] then return end
        task.defer(function()
            local a0 = obj:FindFirstChild("Attachment0")
            local a1 = obj:FindFirstChild("Attachment1")
            if a0 and a1 then
                spawnLaser(a0.WorldPosition, a1.WorldPosition)
            end
        end)
    end)

    game:GetService("RunService").Heartbeat:Connect(function()
        local now = tick()
        local i = 1
        while i <= #_tracerParts do
            local entry = _tracerParts[i]
            local elapsed = now - entry.spawnTime
            if elapsed >= entry.duration then
                for _, p in ipairs(entry.parts) do
                    pcall(function() p:Destroy() end)
                end
                table.remove(_tracerParts, i)
            else

                local alpha = elapsed / entry.duration
                for j, p in ipairs(entry.parts) do
                    local baseT = entry.baseTransparencies[j]
                    p.Transparency = baseT + (1 - baseT) * alpha
                end
                i = i + 1
            end
        end
    end)
end

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local espLP      = Players.LocalPlayer
local espObjs    = {}
local chamsObjs  = {}

local function _isInRound(player)
    return player:GetAttribute("EnvironmentID") ~= nil
end

local function _getEnvID(player)
    local chid = player:GetAttribute("EnvironmentID")
    return chid and string.byte(chid) or nil
end

local function _getTeamID(player)
    local chid = player:GetAttribute("TeamID")
    return chid and string.byte(chid) or nil
end

local function _isEnemy(player)
    if not _isInRound(espLP) or not _isInRound(player) then return true end
    local myEnv  = _getEnvID(espLP)
    local theirEnv = _getEnvID(player)
    if myEnv ~= theirEnv then return false end
    local myTeam   = _getTeamID(espLP)
    local theirTeam = _getTeamID(player)
    if myTeam == nil or theirTeam == nil then return true end
    return myTeam ~= theirTeam
end

local function getColor(flag)
    local v = library.flags[flag]
    if type(v) == "table" and typeof(v.Color) == "Color3" then return v.Color end
    return Color3.new(1, 1, 1)
end

local function newLine(color, thickness, zindex)
    local l = Drawing.new("Line")
    l.Visible = false; l.Color = color; l.Thickness = thickness; l.Transparency = 1
    if zindex then l.ZIndex = zindex end
    return l
end
local function newSquare()
    local s = Drawing.new("Square")
    s.Visible = false; s.Filled = true; s.Transparency = 1
    return s
end
local function newText(size)
    local t = Drawing.new("Text")
    t.Visible = false; t.Center = true; t.Outline = true
    t.Size = size; t.Color = Color3.new(1,1,1); t.OutlineColor = Color3.new(0,0,0)
    return t
end

local HAT_SEGS = 16
local function createESPDrawings()
    local d = { ol = {}, cl = {}, sklOl = {}, sklLines = {}, hatOl = {}, hatLines = {}, hatCircOl = {}, hatCirc = {} }
    for i = 1, 8  do d.ol[i]       = newLine(Color3.new(0,0,0), 2, 1) end
    for i = 1, 8  do d.cl[i]       = newLine(Color3.new(1,1,1), 1, 2) end
    for i = 1, 14 do d.sklOl[i]    = newLine(Color3.new(0,0,0), 2, 1) end
    for i = 1, 14 do d.sklLines[i] = newLine(Color3.new(1,1,1), 1, 2) end

    for i = 1, HAT_SEGS do d.hatOl[i]    = newLine(Color3.new(0,0,0), 3, 1) end
    for i = 1, HAT_SEGS do d.hatLines[i] = newLine(Color3.new(1,1,1), 1, 2) end
    for i = 1, HAT_SEGS do d.hatCircOl[i]  = newLine(Color3.new(0,0,0), 3, 1) end
    for i = 1, HAT_SEGS do d.hatCirc[i]    = newLine(Color3.new(1,1,1), 1, 2) end
    d.hpBack   = newSquare(); d.hpBack.Color = Color3.new(0,0,0); d.hpBack.Transparency = 0.5
    d.hpFill   = newSquare()
    d.nameText = newText(13)
    d.distText = newText(11)
    d.weapText = newText(11)
    d.snapOl   = newLine(Color3.new(0, 0, 0), 3, 1)
    d.snapLine = newLine(Color3.new(1, 0, 0), 1, 2)

    d.box3dOl = {}; d.box3dCl = {}
    for i = 1, 12 do d.box3dOl[i] = newLine(Color3.new(0,0,0), 3, 1) end
    for i = 1, 12 do d.box3dCl[i] = newLine(Color3.new(1,1,1), 1, 2) end

    d.boxFill = newSquare(); d.boxFill.Filled = true; d.boxFill.Transparency = 0.25; d.boxFill.ZIndex = 0

    d.headDotOl = Drawing.new("Circle"); d.headDotOl.Visible = false; d.headDotOl.Filled = false; d.headDotOl.Color = Color3.new(0,0,0); d.headDotOl.Thickness = 3; d.headDotOl.NumSides = 32; d.headDotOl.ZIndex = 3
    d.headDot   = Drawing.new("Circle"); d.headDot.Visible   = false; d.headDot.Filled   = false; d.headDot.Color   = Color3.new(1,0,0); d.headDot.Thickness   = 1; d.headDot.NumSides   = 32; d.headDot.ZIndex   = 4
    return d
end

local function removeESP(player)
    local d = espObjs[player]; if not d then return end
    for _, l in ipairs(d.ol)       do pcall(function() l:Remove() end) end
    for _, l in ipairs(d.cl)       do pcall(function() l:Remove() end) end
    for _, l in ipairs(d.sklOl      or {}) do pcall(function() l:Remove() end) end
    for _, l in ipairs(d.sklLines   or {}) do pcall(function() l:Remove() end) end
    for _, l in ipairs(d.hatOl      or {}) do pcall(function() l:Remove() end) end
    for _, l in ipairs(d.hatLines   or {}) do pcall(function() l:Remove() end) end
    for _, l in ipairs(d.hatCircOl  or {}) do pcall(function() l:Remove() end) end
    for _, l in ipairs(d.hatCirc    or {}) do pcall(function() l:Remove() end) end
    pcall(function() d.hpBack:Remove()   end)
    pcall(function() d.hpFill:Remove()   end)
    pcall(function() d.nameText:Remove() end)
    pcall(function() d.distText:Remove() end)
    pcall(function() d.weapText:Remove() end)
    pcall(function() d.snapOl:Remove()   end)
    pcall(function() d.snapLine:Remove() end)
    for _, l in ipairs(d.box3dOl or {}) do pcall(function() l:Remove() end) end
    for _, l in ipairs(d.box3dCl or {}) do pcall(function() l:Remove() end) end
    pcall(function() if d.boxFill then d.boxFill:Remove() end end)
    pcall(function() if d.headDotOl then d.headDotOl:Remove() end end)
    pcall(function() if d.headDot then d.headDot:Remove() end end)
    espObjs[player] = nil

    if chamsObjs[player] then
        pcall(function() chamsObjs[player]:Destroy() end)
        chamsObjs[player] = nil
    end
end

local function hideESP(d)
    for _, l in ipairs(d.ol) do l.Visible = false end
    for _, l in ipairs(d.cl) do l.Visible = false end
    for _, l in ipairs(d.sklOl     or {}) do l.Visible = false end
    for _, l in ipairs(d.sklLines  or {}) do l.Visible = false end
    for _, l in ipairs(d.hatOl     or {}) do l.Visible = false end
    for _, l in ipairs(d.hatLines  or {}) do l.Visible = false end
    for _, l in ipairs(d.hatCircOl or {}) do l.Visible = false end
    for _, l in ipairs(d.hatCirc   or {}) do l.Visible = false end
    d.hpBack.Visible = false; d.hpFill.Visible = false
    d.nameText.Visible = false; d.distText.Visible = false
    d.weapText.Visible = false
    d.snapOl.Visible = false; d.snapLine.Visible = false
    for _, l in ipairs(d.box3dOl or {}) do l.Visible = false end
    for _, l in ipairs(d.box3dCl or {}) do l.Visible = false end
    if d.boxFill then d.boxFill.Visible = false end
    if d.headDotOl then d.headDotOl.Visible = false end
    if d.headDot then d.headDot.Visible = false end
end

local function setL(lines, i, a, b, color, thickness)
    local l = lines[i]
    l.From = a; l.To = b; l.Color = color; l.Thickness = thickness; l.Visible = true
end

local function drawCorners(d, x, y, w, h, color)
    local cs = math.max(w, h) * 0.22
    local bk = Color3.new(0,0,0)

    setL(d.ol,1, Vector2.new(x,y),       Vector2.new(x+cs,y),       bk,3)
    setL(d.ol,2, Vector2.new(x,y),       Vector2.new(x,y+cs),       bk,3)
    setL(d.ol,3, Vector2.new(x+w-cs,y),  Vector2.new(x+w,y),        bk,3)
    setL(d.ol,4, Vector2.new(x+w,y),     Vector2.new(x+w,y+cs),     bk,3)
    setL(d.ol,5, Vector2.new(x,y+h-cs),  Vector2.new(x,y+h),        bk,3)
    setL(d.ol,6, Vector2.new(x,y+h),     Vector2.new(x+cs,y+h),     bk,3)
    setL(d.ol,7, Vector2.new(x+w,y+h-cs),Vector2.new(x+w,y+h),      bk,3)
    setL(d.ol,8, Vector2.new(x+w-cs,y+h),Vector2.new(x+w,y+h),      bk,3)

    setL(d.cl,1, Vector2.new(x,y),      Vector2.new(x+cs,y),      color,1)
    setL(d.cl,2, Vector2.new(x,y),      Vector2.new(x,y+cs),      color,1)
    setL(d.cl,3, Vector2.new(x+w-cs,y), Vector2.new(x+w,y),       color,1)
    setL(d.cl,4, Vector2.new(x+w,y),    Vector2.new(x+w,y+cs),    color,1)
    setL(d.cl,5, Vector2.new(x,y+h-cs), Vector2.new(x,y+h),       color,1)
    setL(d.cl,6, Vector2.new(x,y+h),    Vector2.new(x+cs,y+h),    color,1)
    setL(d.cl,7, Vector2.new(x+w,y+h-cs),Vector2.new(x+w,y+h),   color,1)
    setL(d.cl,8, Vector2.new(x+w-cs,y+h),Vector2.new(x+w,y+h),   color,1)
end

local function drawFullBox(d, x, y, w, h, color)
    local bk = Color3.new(0,0,0)
    setL(d.ol,1, Vector2.new(x,y),   Vector2.new(x+w,y),   bk,3)
    setL(d.ol,2, Vector2.new(x,y+h), Vector2.new(x+w,y+h), bk,3)
    setL(d.ol,3, Vector2.new(x,y),   Vector2.new(x,y+h),   bk,3)
    setL(d.ol,4, Vector2.new(x+w,y), Vector2.new(x+w,y+h), bk,3)
    for i=5,8 do d.ol[i].Visible=false end
    setL(d.cl,1, Vector2.new(x,y),   Vector2.new(x+w,y),   color,1)
    setL(d.cl,2, Vector2.new(x,y+h), Vector2.new(x+w,y+h), color,1)
    setL(d.cl,3, Vector2.new(x,y),   Vector2.new(x,y+h),   color,1)
    setL(d.cl,4, Vector2.new(x+w,y), Vector2.new(x+w,y+h), color,1)
    for i=5,8 do d.cl[i].Visible=false end
end

local SKELETON = {
    {"Head","UpperTorso"},       {"UpperTorso","LowerTorso"},
    {"UpperTorso","LeftUpperArm"},   {"LeftUpperArm","LeftLowerArm"},   {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},  {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},   {"LeftUpperLeg","LeftLowerLeg"},   {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},  {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
}

local fovCircleOutline = Drawing.new("Circle")
fovCircleOutline.Visible = false
fovCircleOutline.Thickness = 3
fovCircleOutline.NumSides = 64
fovCircleOutline.Filled = false
fovCircleOutline.Transparency = 1
fovCircleOutline.Color = Color3.new(0, 0, 0)
fovCircleOutline.ZIndex = 1

local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Thickness = 1
fovCircle.NumSides = 64
fovCircle.Filled = false
fovCircle.Transparency = 1
fovCircle.Color = Color3.new(1, 1, 1)
fovCircle.ZIndex = 2

local aimbotFovOutline = Drawing.new("Circle")
aimbotFovOutline.Visible = false
aimbotFovOutline.Thickness = 3
aimbotFovOutline.NumSides = 64
aimbotFovOutline.Filled = false
aimbotFovOutline.Transparency = 1
aimbotFovOutline.Color = Color3.new(0, 0, 0)
aimbotFovOutline.ZIndex = 1
local aimbotFovCircle = Drawing.new("Circle")
aimbotFovCircle.Visible = false
aimbotFovCircle.Thickness = 1
aimbotFovCircle.NumSides = 64
aimbotFovCircle.Filled = false
aimbotFovCircle.Transparency = 1
aimbotFovCircle.Color = Color3.new(1, 1, 1)
aimbotFovCircle.ZIndex = 2

local _silentAimTarget = nil

local function _silentLobbyVisible()
    local ok, vis = pcall(function()
        return Players.LocalPlayer.PlayerGui.MainGui.MainFrame.Lobby.Currency.Visible
    end)
    return ok and vis == true
end

local function _playerHasKatana(player)
    local vmFolder = workspace:FindFirstChild("ViewModels")
    if not vmFolder then return false end
    for _, child in ipairs(vmFolder:GetChildren()) do
        local parts = child.Name:split(" - ")
        if #parts >= 2 and parts[1] == player.Name then
            local wname = parts[#parts]
            if wname == "Katana" then return true end
        end
    end
    return false
end

local function _silentGetClosest()
    local cam = workspace.CurrentCamera
    local mousePos = game:GetService("UserInputService"):GetMouseLocation()
    local fovR = library.flags["AimFOV"] or 150
    local tgtName = library.flags["Aim_Part"] or "Head"
    local doVisCheck = library.flags["AimVisCheck"] == true
    local aimTeamCheck = library.flags["AimTeamCheck"] == true
    local closest = nil
    local bestDist = math.huge

    local myChar = espLP and espLP.Character

    local rayParams
    if doVisCheck then
        rayParams = RaycastParams.new()
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        local filterList = {}
        if myChar then table.insert(filterList, myChar) end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= espLP and p.Character then
                table.insert(filterList, p.Character)
            end
        end
        rayParams.FilterDescendantsInstances = filterList
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == espLP then continue end
        if aimTeamCheck and not _isEnemy(player) then continue end
        local char = player.Character
        if not char then continue end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if library.flags["AntiKatana"] and _playerHasKatana(player) then continue end
        local tgt = char:FindFirstChild(tgtName)
        if not tgt then continue end
        local headPos, onScreen = cam:WorldToViewportPoint(tgt.Position)
        if not onScreen or headPos.Z <= 0 then continue end

        if doVisCheck then
            local origin = cam.CFrame.Position
            local dir = tgt.Position - origin
            local result = workspace:Raycast(origin, dir, rayParams)
            if result then continue end
        end

        local screenPos = Vector2.new(headPos.X, headPos.Y)
        local dist = (screenPos - mousePos).Magnitude
        if dist <= fovR and dist < bestDist then
            closest = player
            bestDist = dist
        end
    end
    return closest
end

local function _silentLockCamera()
    if not _silentAimTarget then return end
    local char = _silentAimTarget.Character
    if not char then return end
    local tgtName = library.flags["Aim_Part"] or "Head"
    local part = char:FindFirstChild(tgtName)
    if not part then return end
    local cam = workspace.CurrentCamera
    local headPos = cam:WorldToViewportPoint(part.Position)
    if headPos.Z > 0 then
        cam.CFrame = CFrame.new(cam.CFrame.Position, part.Position)
    end
end

local _silentLMBHolding = false
local _silentLMBRestoreCF = nil

do
    local UIS = game:GetService("UserInputService")

    UIS.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            _silentLMBHolding = true
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            _silentLMBHolding = false
            if _silentLMBRestoreCF then
                workspace.CurrentCamera.CFrame = _silentLMBRestoreCF
                _silentLMBRestoreCF = nil
            end
        end
    end)
end

RunService.Heartbeat:Connect(function()
    if not library.flags["SilentAim"] then return end
    if _silentLobbyVisible() then return end

    if library.flags["SilentLMB"] then
        if _silentLMBHolding then
            _silentAimTarget = _silentGetClosest()
            if _silentAimTarget then
                if not _silentLMBRestoreCF then
                    _silentLMBRestoreCF = workspace.CurrentCamera.CFrame
                end
                _silentLockCamera()
            end
        end

        return
    end

    local aimFlag = library.flags["AimKey"]
    if type(aimFlag) ~= "table" or not aimFlag.active then return end

    _silentAimTarget = _silentGetClosest()
    if not _silentAimTarget then return end

    _silentLockCamera()

    if library.flags["AimAutoFire"] and HAS_MOUSE1CLICK then
        mouse1click()
    end
end)

local _espReading = false

local SW_SEGMENTS = 32
local SW_MAX_WAVES = 30
local _swWaves = {}
local _swWalkCD = {}
local _swShootCD = {}
local _swShootConn = nil

local function swCreateRing()
    local lines = {}
    local olLines = {}
    for i = 1, SW_SEGMENTS do
        local ol = Drawing.new("Line")
        ol.Color = Color3.new(0, 0, 0)
        ol.Thickness = 3
        ol.Visible = false
        ol.ZIndex = 1
        olLines[i] = ol

        local l = Drawing.new("Line")
        l.Color = Color3.new(0, 1, 1)
        l.Thickness = 1
        l.Visible = false
        l.ZIndex = 2
        lines[i] = l
    end
    return lines, olLines
end

local function swDestroyRing(wave)
    for _, l in ipairs(wave.lines) do pcall(function() l:Remove() end) end
    for _, l in ipairs(wave.olLines) do pcall(function() l:Remove() end) end
end

local function swSpawn(worldPos, isBig)

    if #_swWaves >= SW_MAX_WAVES then
        swDestroyRing(_swWaves[1])
        table.remove(_swWaves, 1)
    end
    local lines, olLines = swCreateRing()
    table.insert(_swWaves, {
        lines = lines,
        olLines = olLines,
        origin = worldPos,
        startTick = tick(),
        big = isBig or false,
    })
end

local function swSetupShootHook()
    if _swShootConn then return end
    local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
    if not remotes then return end
    local repl = remotes:FindFirstChild("Replication")
    if not repl then return end
    local fighter = repl:FindFirstChild("Fighter")
    if not fighter then return end
    local pms = fighter:FindFirstChild("PlayMechanicsSound")
    if not pms then return end

    _swShootConn = pms.OnClientEvent:Connect(function(player, ...)
        if not library.flags["SoundWaves"] then return end
        if not player or not player:IsA("Player") then return end
        if player == Players.LocalPlayer then return end

        if library.flags["ESPTeamCheck"] and not _isEnemy(player) then return end

        local now = tick()
        local last = _swShootCD[player] or 0
        if now - last < 0.15 then return end
        _swShootCD[player] = now

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        local pos = root.Position
        local groundPos = Vector3.new(pos.X, pos.Y - 3, pos.Z)
        swSpawn(groundPos, true)
    end)
end

local function swUpdate()
    if not library.flags["SoundWaves"] then
        for _, wave in ipairs(_swWaves) do
            for _, l in ipairs(wave.lines) do l.Visible = false end
            for _, l in ipairs(wave.olLines) do l.Visible = false end
        end
        return
    end

    if not _swShootConn then swSetupShootHook() end

    local cam = workspace.CurrentCamera
    local maxRadius = library.flags["SW_MaxRadius"] or 20
    local duration = (library.flags["SW_Duration"] or 15) / 10
    local thickness = library.flags["SW_Thickness"] or 2
    local waveColor = library.flags["SoundWaves_Color"]
    if type(waveColor) == "table" and waveColor.Color then waveColor = waveColor.Color end
    if not waveColor or typeof(waveColor) ~= "Color3" then waveColor = Color3.fromRGB(0, 200, 255) end

    local now = tick()
    local toRemove = {}

    for idx, wave in ipairs(_swWaves) do
        local elapsed = now - wave.startTick
        local dur = wave.big and (duration * 1.3) or duration
        local rad = wave.big and (maxRadius * 1.5) or maxRadius
        local progress = elapsed / dur

        if progress >= 1 then
            for _, l in ipairs(wave.lines) do l.Visible = false end
            for _, l in ipairs(wave.olLines) do l.Visible = false end
            table.insert(toRemove, idx)
        else
            local radius = rad * progress
            local alpha = 1 - progress
            local origin = wave.origin

            local anyBehind = false
            local pts = {}
            for i = 0, SW_SEGMENTS - 1 do
                local angle = (i / SW_SEGMENTS) * math.pi * 2
                local worldPt = origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
                local sp = cam:WorldToViewportPoint(worldPt)
                if sp.Z <= 0 then anyBehind = true; break end
                pts[i + 1] = Vector2.new(sp.X, sp.Y)
            end

            if anyBehind then
                for _, l in ipairs(wave.lines) do l.Visible = false end
                for _, l in ipairs(wave.olLines) do l.Visible = false end
            else
                local th = wave.big and (thickness + 1) or thickness
                for i = 1, SW_SEGMENTS do
                    local p1 = pts[i]
                    local p2 = pts[i % SW_SEGMENTS + 1]

                    wave.olLines[i].From = p1
                    wave.olLines[i].To = p2
                    wave.olLines[i].Thickness = th + 2
                    wave.olLines[i].Transparency = alpha * 0.5
                    wave.olLines[i].Color = Color3.new(0, 0, 0)
                    wave.olLines[i].Visible = true

                    wave.lines[i].From = p1
                    wave.lines[i].To = p2
                    wave.lines[i].Thickness = th
                    wave.lines[i].Transparency = alpha
                    wave.lines[i].Color = waveColor
                    wave.lines[i].Visible = true
                end
            end
        end
    end

    for i = #toRemove, 1, -1 do
        swDestroyRing(_swWaves[toRemove[i]])
        table.remove(_swWaves, toRemove[i])
    end
end

RunService.RenderStepped:Connect(function()
    _espReading = true
    local enabled = library.flags["Enabled"] == true
    local cam     = workspace.CurrentCamera
    local myChar  = espLP.Character
    local myRoot  = myChar and myChar:FindFirstChild("HumanoidRootPart")

    if not window.opened and not _espUnlocked then _espUnlocked = true end
    local _menuHide = (window.opened == true) or not _espUnlocked

    if library.flags["ShowFOV"] and library.flags["SilentAim"] and not _menuHide then
        local vp  = cam.ViewportSize
        local pos = Vector2.new(vp.X / 2, vp.Y / 2)
        local rad = library.flags["AimFOV"] or 150
        local col = getColor("FOV_Color")
        fovCircleOutline.Position = pos
        fovCircleOutline.Radius   = rad
        fovCircleOutline.Visible  = true
        fovCircle.Position = pos
        fovCircle.Radius   = rad
        fovCircle.Color    = col
        fovCircle.Visible  = true
    else
        fovCircleOutline.Visible = false
        fovCircle.Visible = false
    end

    do
        local abEnabled = library.flags["AimbotEnabled"]
        local abShowFov = library.flags["AimbotShowFOV"]
        local abFov     = library.flags["AimbotFOV"] or 150
        local mousePos  = game:GetService("UserInputService"):GetMouseLocation()

        if abEnabled and abShowFov and not _menuHide then
            local abCol = getColor("AimbotFOV_Color")
            aimbotFovOutline.Position = mousePos
            aimbotFovOutline.Radius   = abFov
            aimbotFovOutline.Visible  = true
            aimbotFovCircle.Position  = mousePos
            aimbotFovCircle.Radius    = abFov
            aimbotFovCircle.Color     = abCol
            aimbotFovCircle.Visible   = true
        else
            aimbotFovOutline.Visible = false
            aimbotFovCircle.Visible  = false
        end

        if abEnabled then
            local aimMode = library.flags["AimbotMode"] or "Hold Key"
            local uis = game:GetService("UserInputService")
            local shouldAim = false
            if aimMode == "Hold Key" then
                local abKey = library.flags["AimbotKey"]
                shouldAim = type(abKey) == "table" and abKey.active == true
            elseif aimMode == "Hold RMB" then
                shouldAim = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
            elseif aimMode == "Hold LMB" then
                shouldAim = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            else
                shouldAim = uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                    or uis:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
            end

            if shouldAim and myRoot then
                local abPart   = library.flags["Aimbot_Part"] or "Head"
                local rawSmooth = library.flags["AimbotSmooth"] or 12
                local abSmooth = (51 - rawSmooth) / 100
                local abMaxD   = library.flags["AimbotMaxDist"] or 800
                local abPred   = library.flags["AimbotPrediction"]
                local abPredA  = (library.flags["AimbotPredAmt"] or 100) / 100
                local abVisCheck = library.flags["AimVisCheck"] == true
                local bestScore = math.huge
                local bestPart  = nil
                local bestPlayer = nil

                local abRayParams
                if abVisCheck then
                    abRayParams = RaycastParams.new()
                    abRayParams.FilterType = Enum.RaycastFilterType.Exclude
                    local fl = {}
                    if myChar then table.insert(fl, myChar) end
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= espLP and p.Character then table.insert(fl, p.Character) end
                    end
                    abRayParams.FilterDescendantsInstances = fl
                end

                local abTeamCheck = library.flags["AimTeamCheck"] == true

                for _, player in ipairs(Players:GetPlayers()) do
                    if player == espLP then continue end
                    if abTeamCheck and not _isEnemy(player) then continue end
                    local char = player.Character
                    if not char then continue end
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if not hum or hum.Health <= 0 then continue end
                    if library.flags["AntiKatana"] and _playerHasKatana(player) then continue end
                    local tgt = char:FindFirstChild(abPart)
                    if not tgt then continue end
                    local sc, onScreen = cam:WorldToViewportPoint(tgt.Position)
                    if not onScreen or sc.Z <= 0 then continue end
                    local dist3D = (tgt.Position - myRoot.Position).Magnitude
                    if dist3D > abMaxD then continue end

                    if abVisCheck then
                        local origin = cam.CFrame.Position
                        local dir = tgt.Position - origin
                        local result = workspace:Raycast(origin, dir, abRayParams)
                        if result then continue end
                    end
                    local screenDist = (Vector2.new(sc.X, sc.Y) - mousePos).Magnitude
                    if screenDist > abFov then continue end
                    local score = screenDist + (dist3D * 0.01)
                    if score < bestScore then
                        bestScore = score
                        bestPart = tgt
                        bestPlayer = player
                    end
                end

                if bestPart then
                    local targetPos = bestPart.Position

                    if abPred then
                        local hrp = bestPlayer.Character and bestPlayer.Character:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local vel = Vector3.zero
                            pcall(function() vel = hrp.AssemblyLinearVelocity end)
                            local dist = (targetPos - cam.CFrame.Position).Magnitude
                            local flightTime = dist / 1500
                            for _ = 1, 4 do
                                local pPos = targetPos + vel * flightTime
                                flightTime = (pPos - cam.CFrame.Position).Magnitude / 1500
                            end
                            flightTime = flightTime * abPredA
                            targetPos = targetPos + vel * flightTime
                            targetPos = targetPos + Vector3.new(0, 0.5 * 196.2 * 0.1 * flightTime * flightTime, 0)
                        end
                    end

                    local screenPos = cam:WorldToViewportPoint(targetPos)
                    if screenPos.Z > 0 then
                        local screenCenter = cam.ViewportSize / 2
                        local deltaX = screenPos.X - screenCenter.X
                        local deltaY = screenPos.Y - screenCenter.Y
                        local deltaMag = math.sqrt(deltaX * deltaX + deltaY * deltaY)

                        if deltaMag > 0.5 and HAS_MOUSEMOVEREL then
                            local moveX = deltaX * abSmooth
                            local moveY = deltaY * abSmooth
                            if deltaMag > 50 then
                                moveX = deltaX * math.min(abSmooth * 2, 0.5)
                                moveY = deltaY * math.min(abSmooth * 2, 0.5)
                            end
                            mousemoverel(moveX, moveY)
                        end
                    end
                end
            end
        end
    end

    local armsT = (library.flags["ArmsTransp"] or 0) / 100
    local bulletsT = (library.flags["BulletsTransp"] or 0) / 100
    if armsT > 0 or bulletsT > 0 then
        local vmFolder = workspace:FindFirstChild("ViewModels")
        local fp = vmFolder and vmFolder:FindFirstChild("FirstPerson")
        if fp then
            for _, vm in ipairs(fp:GetChildren()) do
                if vm:IsA("Model") and vm.Name:find(espLP.Name) then
                    for _, part in ipairs(vm:GetChildren()) do
                        if armsT > 0 and (part.Name == "RightArm" or part.Name == "LeftArm") then
                            if part:IsA("BasePart") then part.LocalTransparencyModifier = armsT end
                            for _, child in ipairs(part:GetDescendants()) do
                                if child:IsA("BasePart") then child.LocalTransparencyModifier = armsT end
                            end
                        elseif part.Name == "ItemVisual" and bulletsT > 0 then
                            for _, bp in ipairs(part:GetDescendants()) do
                                if bp:IsA("BasePart") then
                                    bp.LocalTransparencyModifier = bulletsT
                                end
                            end
                        end
                    end
                    break
                end
            end
        end
    end

    if not enabled or _menuHide then
        for _, d in pairs(espObjs) do hideESP(d) end
        for _, hl in pairs(chamsObjs) do pcall(function() hl.Enabled = false end) end
        _espReading = false
        return
    end

    local showNames = library.flags["Names"]     == true
    local showBoxes = library.flags["Boxes"]     == true
    local showHP    = library.flags["Healthbar"] == true
    local showDist  = library.flags["Distance"]  == true
    local showSkel  = library.flags["Skeleton"]  == true
    local showWeap  = library.flags["Weapon"]    == true
    local showSnap  = library.flags["Snaplines"] == true
    local visCheck  = library.flags["VisCheck"]  == true
    local espTeamCheck = library.flags["ESPTeamCheck"] == true

    local HIDDEN_COLOR = Color3.fromRGB(40, 40, 120)

    local _visParams = RaycastParams.new()
    _visParams.FilterType = Enum.RaycastFilterType.Exclude
    if visCheck then
        local _visFilterList = { myChar }
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then table.insert(_visFilterList, p.Character) end
        end
        _visParams.FilterDescendantsInstances = _visFilterList
    end

    local _weaponNames = {}
    if showWeap then
        local vmFolder = workspace:FindFirstChild("ViewModels")
        if vmFolder then
            for _, child in ipairs(vmFolder:GetChildren()) do
                local n = child.Name
                local parts = n:split(" - ")
                if #parts >= 2 then
                    local pname = parts[1]
                    local wname = parts[#parts]
                    _weaponNames[pname] = wname
                end
            end
        end
    end
    local maxDist   = library.flags["Max_Distance"] or 500
    local boxColor  = getColor("Box_Color")
    local nameColor = getColor("Name_Color")
    local hpHigh    = getColor("Health_High")
    local hpLow     = getColor("Health_Low")
    local distColor = getColor("Distance_Color")
    local skelColor = getColor("Skeleton_Color")
    local snapColor = getColor("Snapline_Color")

    for _, player in ipairs(Players:GetPlayers()) do
        if player == espLP then continue end

        if espTeamCheck and not _isEnemy(player) then
            if espObjs[player] then hideESP(espObjs[player]) end
            if chamsObjs[player] then pcall(function() chamsObjs[player].Enabled = false end) end
            continue
        end

        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not root then
            if espObjs[player] then hideESP(espObjs[player]) end
            if chamsObjs[player] then pcall(function() chamsObjs[player].Enabled = false end) end
            continue
        end

        local charDist = myRoot and (root.Position - myRoot.Position).Magnitude or 0
        if myRoot and charDist > maxDist then
            if espObjs[player] then hideESP(espObjs[player]) end
            if chamsObjs[player] then pcall(function() chamsObjs[player].Enabled = false end) end
            continue
        end

        local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
        local behind = false
        for _, part in ipairs(char:GetChildren()) do
            if part:IsA("BasePart") and part.Transparency < 1 and not behind then
                local s   = part.Size
                local cf  = part.CFrame
                local hsx, hsy, hsz = s.X/2, s.Y/2, s.Z/2
                for _, off in ipairs({
                    Vector3.new( hsx,  hsy,  hsz), Vector3.new(-hsx,  hsy,  hsz),
                    Vector3.new( hsx, -hsy,  hsz), Vector3.new(-hsx, -hsy,  hsz),
                    Vector3.new( hsx,  hsy, -hsz), Vector3.new(-hsx,  hsy, -hsz),
                    Vector3.new( hsx, -hsy, -hsz), Vector3.new(-hsx, -hsy, -hsz),
                }) do
                    local sc = cam:WorldToViewportPoint(cf:PointToWorldSpace(off))
                    if sc.Z <= 0 then behind = true; break end
                    if sc.X < minX then minX = sc.X end
                    if sc.Y < minY then minY = sc.Y end
                    if sc.X > maxX then maxX = sc.X end
                    if sc.Y > maxY then maxY = sc.Y end
                end
            end
        end
        if behind or minX == math.huge then
            if espObjs[player] then hideESP(espObjs[player]) end

            if library.flags["ChamsEnabled"] == true then
                local hl = chamsObjs[player]
                if not hl or not hl.Parent then
                    hl = Instance.new("Highlight")
                    hl.Name = "_chams"
                    hl.Adornee = char
                    hl.Parent = game:GetService("CoreGui")
                    chamsObjs[player] = hl
                end
                if hl.Adornee ~= char then hl.Adornee = char end
                local fillCol = getColor("Chams_Color")
                hl.FillColor = fillCol
                hl.FillTransparency = (library.flags["ChamsFillAlpha"] or 30) / 100
                if library.flags["ChamsOutline"] == true then
                    hl.OutlineColor = getColor("ChamsOutline_Color")
                    hl.OutlineTransparency = (library.flags["ChamsOutAlpha"] or 0) / 100
                else
                    hl.OutlineTransparency = 1
                end
                local depth = library.flags["ChamsDepth"] or "AlwaysOnTop"
                hl.DepthMode = depth == "AlwaysOnTop"
                    and Enum.HighlightDepthMode.AlwaysOnTop
                    or Enum.HighlightDepthMode.Occluded
                hl.Enabled = true
            else
                if chamsObjs[player] then pcall(function() chamsObjs[player].Enabled = false end) end
            end
            continue
        end

        if not espObjs[player] then espObjs[player] = createESPDrawings() end
        local d  = espObjs[player]
        local bx = minX
        local by = minY
        local bw = maxX - minX
        local bh = maxY - minY

        local isHidden = false
        if visCheck and myRoot then
            local origin = cam.CFrame.Position
            local dir    = root.Position - origin
            local result = workspace:Raycast(origin, dir, _visParams)
            isHidden = result ~= nil
        end

        local curBoxColor  = isHidden and HIDDEN_COLOR or boxColor
        local curNameColor = isHidden and HIDDEN_COLOR or nameColor
        local curDistColor = isHidden and HIDDEN_COLOR or distColor
        local curSkelColor = isHidden and HIDDEN_COLOR or skelColor
        local curSnapColor = isHidden and HIDDEN_COLOR or snapColor
        local curWeapColor = isHidden and HIDDEN_COLOR or getColor("Weapon_Color")

        local boxType = library.flags["Box_Type"] or "Corner"
        local is3D = boxType == "3D Box"
        if showBoxes and not is3D then
            if boxType == "Corner" then drawCorners(d, bx, by, bw, bh, curBoxColor)
            else                        drawFullBox(d, bx, by, bw, bh, curBoxColor) end
            for _, l in ipairs(d.box3dOl) do l.Visible = false end
            for _, l in ipairs(d.box3dCl) do l.Visible = false end
        elseif showBoxes and is3D then

            for _, l in ipairs(d.ol) do l.Visible = false end
            for _, l in ipairs(d.cl) do l.Visible = false end

            local wMinX, wMinY, wMinZ =  math.huge,  math.huge,  math.huge
            local wMaxX, wMaxY, wMaxZ = -math.huge, -math.huge, -math.huge
            local hasAny = false
            for _, part in ipairs(char:GetChildren()) do
                if part:IsA("BasePart") and part.Transparency < 1 then
                    hasAny = true
                    local s   = part.Size
                    local cf  = part.CFrame
                    local hsx, hsy, hsz = s.X/2, s.Y/2, s.Z/2
                    for _, off in ipairs({
                        Vector3.new( hsx,  hsy,  hsz), Vector3.new(-hsx,  hsy,  hsz),
                        Vector3.new( hsx, -hsy,  hsz), Vector3.new(-hsx, -hsy,  hsz),
                        Vector3.new( hsx,  hsy, -hsz), Vector3.new(-hsx,  hsy, -hsz),
                        Vector3.new( hsx, -hsy, -hsz), Vector3.new(-hsx, -hsy, -hsz),
                    }) do
                        local wp = cf:PointToWorldSpace(off)
                        if wp.X < wMinX then wMinX = wp.X end
                        if wp.Y < wMinY then wMinY = wp.Y end
                        if wp.Z < wMinZ then wMinZ = wp.Z end
                        if wp.X > wMaxX then wMaxX = wp.X end
                        if wp.Y > wMaxY then wMaxY = wp.Y end
                        if wp.Z > wMaxZ then wMaxZ = wp.Z end
                    end
                end
            end
            if not hasAny then
                for i = 1, 12 do d.box3dOl[i].Visible = false; d.box3dCl[i].Visible = false end
            else

                local corners3D = {
                    Vector3.new(wMinX, wMinY, wMinZ), Vector3.new(wMaxX, wMinY, wMinZ),
                    Vector3.new(wMaxX, wMaxY, wMinZ), Vector3.new(wMinX, wMaxY, wMinZ),
                    Vector3.new(wMinX, wMinY, wMaxZ), Vector3.new(wMaxX, wMinY, wMaxZ),
                    Vector3.new(wMaxX, wMaxY, wMaxZ), Vector3.new(wMinX, wMaxY, wMaxZ),
                }
                local pts = {}
                local anyBehind = false
                for i, wp in ipairs(corners3D) do
                    local sp = cam:WorldToViewportPoint(wp)
                    if sp.Z <= 0 then anyBehind = true; break end
                    pts[i] = Vector2.new(sp.X, sp.Y)
                end

                local EDGES = {
                    {1,2},{2,6},{6,5},{5,1},
                    {4,3},{3,7},{7,8},{8,4},
                    {1,4},{2,3},{6,7},{5,8},
                }
                if not anyBehind then
                    for i, e in ipairs(EDGES) do
                        local p1, p2 = pts[e[1]], pts[e[2]]
                        d.box3dOl[i].From = p1; d.box3dOl[i].To = p2
                        d.box3dOl[i].Color = Color3.new(0,0,0); d.box3dOl[i].Thickness = 3; d.box3dOl[i].Visible = true
                        d.box3dCl[i].From = p1; d.box3dCl[i].To = p2
                        d.box3dCl[i].Color = curBoxColor; d.box3dCl[i].Thickness = 1; d.box3dCl[i].Visible = true
                    end
                else
                    for i = 1, 12 do d.box3dOl[i].Visible = false; d.box3dCl[i].Visible = false end
                end
            end
        else
            for _, l in ipairs(d.ol) do l.Visible = false end
            for _, l in ipairs(d.cl) do l.Visible = false end
            for _, l in ipairs(d.box3dOl) do l.Visible = false end
            for _, l in ipairs(d.box3dCl) do l.Visible = false end
        end

        if library.flags["BoxFill"] and showBoxes and not is3D then
            local fillCol = isHidden and HIDDEN_COLOR or getColor("BoxFill_Color")
            local fillAlpha = (library.flags["BoxFill_Alpha"] or 75) / 100
            d.boxFill.Position = Vector2.new(bx, by)
            d.boxFill.Size = Vector2.new(bw, bh)
            d.boxFill.Color = fillCol
            d.boxFill.Transparency = 1 - fillAlpha
            d.boxFill.Visible = true
        else
            if d.boxFill then d.boxFill.Visible = false end
        end

        local head = char:FindFirstChild("Head")
        if library.flags["HeadDot"] and head then
            local headSP = cam:WorldToViewportPoint(head.Position)
            if headSP.Z > 0 then
                local headPos = Vector2.new(headSP.X, headSP.Y)
                local dotCol = isHidden and HIDDEN_COLOR or getColor("HeadDot_Color")

                local edgeWorld = head.Position + cam.CFrame.RightVector * (head.Size.X * 0.5)
                local edgeSP = cam:WorldToViewportPoint(edgeWorld)
                local dotRadius = math.max(2, (Vector2.new(edgeSP.X, edgeSP.Y) - headPos).Magnitude)
                d.headDotOl.Position = headPos
                d.headDotOl.Radius = dotRadius + 1
                d.headDotOl.Color = Color3.new(0, 0, 0)
                d.headDotOl.Thickness = 3
                d.headDotOl.Visible = true
                d.headDot.Position = headPos
                d.headDot.Radius = dotRadius
                d.headDot.Color = dotCol
                d.headDot.Thickness = 1
                d.headDot.Visible = true
            else
                d.headDotOl.Visible = false; d.headDot.Visible = false
            end
        else
            if d.headDotOl then d.headDotOl.Visible = false end
            if d.headDot then d.headDot.Visible = false end
        end

        local hum = char:FindFirstChildOfClass("Humanoid")
        if showHP and hum then
            local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
            local barX = bx - 6; local barW = 3
            d.hpBack.Position = Vector2.new(barX - 1, by - 1)
            d.hpBack.Size     = Vector2.new(barW + 2, bh + 2)
            d.hpBack.Visible  = true
            d.hpFill.Color    = isHidden and HIDDEN_COLOR or hpHigh:Lerp(hpLow, 1 - pct)
            d.hpFill.Position = Vector2.new(barX, by + bh * (1 - pct))
            d.hpFill.Size     = Vector2.new(barW, bh * pct)
            d.hpFill.Visible  = pct > 0
        else
            d.hpBack.Visible = false; d.hpFill.Visible = false
        end

        if showNames then
            d.nameText.Text     = player.Name
            d.nameText.Color    = curNameColor
            d.nameText.Position = Vector2.new(bx + bw / 2, by - 15)
            d.nameText.Visible  = true
        else
            d.nameText.Visible = false
        end

        local distOffset = 3
        if showDist and myRoot then
            d.distText.Text     = string.format("%.0f studs", charDist)
            d.distText.Color    = curDistColor
            d.distText.Position = Vector2.new(bx + bw / 2, by + bh + distOffset)
            d.distText.Visible  = true
            distOffset = distOffset + 13
        else
            d.distText.Visible = false
        end

        if showWeap then
            local wname = _weaponNames[player.Name]
            if wname then
                d.weapText.Text     = wname
                d.weapText.Color    = curWeapColor
                d.weapText.Position = Vector2.new(bx + bw / 2, by + bh + distOffset)
                d.weapText.Visible  = true
            else
                d.weapText.Visible = false
            end
        else
            d.weapText.Visible = false
        end

        if showSkel then
            local skelThick = math.clamp(math.round(bh / 80), 1, 3)
            for i, pair in ipairs(SKELETON) do
                local p1 = char:FindFirstChild(pair[1])
                local p2 = char:FindFirstChild(pair[2])
                if p1 and p2 then
                    local s1 = cam:WorldToViewportPoint(p1.Position)
                    local s2 = cam:WorldToViewportPoint(p2.Position)
                    if s1.Z > 0 and s2.Z > 0 then
                        local from = Vector2.new(s1.X, s1.Y)
                        local to   = Vector2.new(s2.X, s2.Y)
                        local sko  = d.sklOl[i]
                        sko.From = from; sko.To = to; sko.Color = Color3.new(0,0,0); sko.Thickness = skelThick + 2; sko.Visible = true
                        local skl  = d.sklLines[i]
                        skl.From = from; skl.To = to; skl.Color = curSkelColor; skl.Thickness = skelThick; skl.Visible = true
                    else
                        d.sklOl[i].Visible    = false
                        d.sklLines[i].Visible = false
                    end
                else
                    d.sklOl[i].Visible    = false
                    d.sklLines[i].Visible = false
                end
            end
        else
            for _, l in ipairs(d.sklOl)    do l.Visible = false end
            for _, l in ipairs(d.sklLines) do l.Visible = false end
        end

        if showSnap then
            local vp = cam.ViewportSize
            local origin
            local snapOrigin = library.flags["SnaplineOrigin"] or "Bottom"
            if snapOrigin == "Bottom" then
                origin = Vector2.new(vp.X / 2, vp.Y)
            elseif snapOrigin == "Center" then
                origin = Vector2.new(vp.X / 2, vp.Y / 2)
            elseif snapOrigin == "Top" then
                origin = Vector2.new(vp.X / 2, 0)
            elseif snapOrigin == "Mouse" then
                origin = game:GetService("UserInputService"):GetMouseLocation()
            end
            local target = Vector2.new(bx + bw / 2, by + bh)
            d.snapOl.From = origin; d.snapOl.To = target
            d.snapOl.Color = Color3.new(0, 0, 0); d.snapOl.Thickness = 3; d.snapOl.Visible = true
            d.snapLine.From = origin; d.snapLine.To = target
            d.snapLine.Color = curSnapColor; d.snapLine.Thickness = 1; d.snapLine.Visible = true
        else
            d.snapOl.Visible = false; d.snapLine.Visible = false
        end

        if library.flags["ChinaHat"] == true then
            local head = char:FindFirstChild("Head")
            if head then
                local hatRadius = (library.flags["ChinaHat_Radius"] or 13) / 10
                local hatHeight = (library.flags["ChinaHat_Height"] or 7) / 10
                local hatCol    = isHidden and HIDDEN_COLOR or getColor("ChinaHat_Color")
                local headPos   = head.Position
                local topPos    = headPos + Vector3.new(0, head.Size.Y / 2 + hatHeight, 0)
                local top2D, onTop = cam:WorldToViewportPoint(topPos)

                if onTop then
                    local pts = {}
                    for i = 1, HAT_SEGS do
                        local ang = (i / HAT_SEGS) * math.pi * 2
                        local wp  = headPos + Vector3.new(0, head.Size.Y / 2, 0)
                            + Vector3.new(math.cos(ang) * hatRadius, 0, math.sin(ang) * hatRadius)
                        local sp  = cam:WorldToViewportPoint(wp)
                        pts[i] = Vector2.new(sp.X, sp.Y)
                    end
                    local tip = Vector2.new(top2D.X, top2D.Y)
                    for i = 1, HAT_SEGS do
                        local p1 = pts[i]
                        local p2 = pts[i % HAT_SEGS + 1]

                        d.hatOl[i].From = tip; d.hatOl[i].To = p1
                        d.hatOl[i].Color = Color3.new(0,0,0); d.hatOl[i].Thickness = 3; d.hatOl[i].Visible = true

                        d.hatLines[i].From = tip; d.hatLines[i].To = p1
                        d.hatLines[i].Color = hatCol; d.hatLines[i].Thickness = 1; d.hatLines[i].Visible = true

                        d.hatCircOl[i].From = p1; d.hatCircOl[i].To = p2
                        d.hatCircOl[i].Color = Color3.new(0,0,0); d.hatCircOl[i].Thickness = 3; d.hatCircOl[i].Visible = true

                        d.hatCirc[i].From = p1; d.hatCirc[i].To = p2
                        d.hatCirc[i].Color = hatCol; d.hatCirc[i].Thickness = 1; d.hatCirc[i].Visible = true
                    end
                else
                    for i = 1, HAT_SEGS do
                        d.hatOl[i].Visible = false; d.hatLines[i].Visible = false
                        d.hatCircOl[i].Visible = false; d.hatCirc[i].Visible = false
                    end
                end
            else
                for i = 1, HAT_SEGS do
                    d.hatOl[i].Visible = false; d.hatLines[i].Visible = false
                    d.hatCircOl[i].Visible = false; d.hatCirc[i].Visible = false
                end
            end
        else
            for i = 1, HAT_SEGS do
                d.hatOl[i].Visible = false; d.hatLines[i].Visible = false
                d.hatCircOl[i].Visible = false; d.hatCirc[i].Visible = false
            end
        end

        if library.flags["ChamsEnabled"] == true and char then
            local hl = chamsObjs[player]
            if not hl or not hl.Parent then
                hl = Instance.new("Highlight")
                hl.Name = "_chams"
                hl.Adornee = char
                hl.Parent = game:GetService("CoreGui")
                chamsObjs[player] = hl
            end
            if hl.Adornee ~= char then hl.Adornee = char end
            local fillCol = getColor("Chams_Color")
            local fillAlpha = (library.flags["ChamsFillAlpha"] or 30) / 100
            hl.FillColor = isHidden and HIDDEN_COLOR or fillCol
            hl.FillTransparency = fillAlpha
            if library.flags["ChamsOutline"] == true then
                local outCol = getColor("ChamsOutline_Color")
                hl.OutlineColor = isHidden and HIDDEN_COLOR or outCol
                hl.OutlineTransparency = (library.flags["ChamsOutAlpha"] or 0) / 100
            else
                hl.OutlineTransparency = 1
            end
            local depth = library.flags["ChamsDepth"] or "AlwaysOnTop"
            hl.DepthMode = depth == "AlwaysOnTop"
                and Enum.HighlightDepthMode.AlwaysOnTop
                or Enum.HighlightDepthMode.Occluded
            hl.Enabled = true
        else
            if chamsObjs[player] then
                pcall(function() chamsObjs[player].Enabled = false end)
            end
        end

    end

    if library.flags["SoundWaves"] then
        local swTeamCheck = library.flags["ESPTeamCheck"] == true
        local swNow = tick()
        for _, player in ipairs(Players:GetPlayers()) do
            if player == espLP then continue end
            if swTeamCheck and not _isEnemy(player) then continue end

            local char = player.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if not root then continue end

            local vel = root.AssemblyLinearVelocity
            local horizSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude

            if horizSpeed > 3 then
                local cd = horizSpeed > 14 and 0.4 or 0.8
                local lastWalk = _swWalkCD[player] or 0
                if swNow - lastWalk >= cd then
                    _swWalkCD[player] = swNow
                    local pos = root.Position
                    local groundPos = Vector3.new(pos.X, pos.Y - 3, pos.Z)
                    swSpawn(groundPos, false)
                end
            end
        end

        for p in pairs(_swWalkCD) do
            if not (p and p.Parent) then _swWalkCD[p] = nil; _swShootCD[p] = nil end
        end
    end

    swUpdate()

    for p in pairs(espObjs) do
        if not (p and p.Parent) then removeESP(p) end
    end
    _espReading = false
end)

Players.PlayerRemoving:Connect(removeESP)

do
    local MT_MAX_POINTS = 40
    local _mtTrails = {}

    local function mtCleanPlayer(p)
        local t = _mtTrails[p]
        if not t then return end
        for _, l in ipairs(t.lines)   do pcall(function() l:Remove() end) end
        for _, l in ipairs(t.olLines) do pcall(function() l:Remove() end) end
        _mtTrails[p] = nil
    end

    local function mtGetOrCreate(player)
        if not _mtTrails[player] then
            _mtTrails[player] = { points = {}, lines = {}, olLines = {} }
        end
        return _mtTrails[player]
    end

    Players.PlayerRemoving:Connect(mtCleanPlayer)

    RunService.RenderStepped:Connect(function()
        if not library.flags["MotionTrails"] then
            for _, t in pairs(_mtTrails) do
                for _, l in ipairs(t.lines)   do l.Visible = false end
                for _, l in ipairs(t.olLines) do l.Visible = false end
            end
            return
        end

        local cam = workspace.CurrentCamera
        local teamCheck = library.flags["ESPTeamCheck"] == true
        local duration  = (library.flags["MT_Duration"] or 12) / 10
        local thickness = library.flags["MT_Thickness"] or 1
        local trailColor = library.flags["MT_Color"]
        if type(trailColor) == "table" and trailColor.Color then trailColor = trailColor.Color end
        if not trailColor or typeof(trailColor) ~= "Color3" then trailColor = Color3.fromRGB(190, 100, 255) end

        for _, player in ipairs(Players:GetPlayers()) do
            if player == espLP then continue end
            if teamCheck and not _isEnemy(player) then
                local t = _mtTrails[player]
                if t then
                    for _, l in ipairs(t.lines)   do l.Visible = false end
                    for _, l in ipairs(t.olLines) do l.Visible = false end
                end
                continue
            end

            local char = player.Character
            local hrp  = char and char:FindFirstChild("HumanoidRootPart")

            if not hrp then
                local t = _mtTrails[player]
                if t then
                    for _, l in ipairs(t.lines)   do l.Visible = false end
                    for _, l in ipairs(t.olLines) do l.Visible = false end
                    t.points = {}
                end
                continue
            end

            local t = mtGetOrCreate(player)

            local trailPos = hrp.Position + Vector3.new(0, 0.5, 0)
            local now = tick()

            if #t.points == 0 or (t.points[1].pos - trailPos).Magnitude > 0.3 then
                table.insert(t.points, 1, { pos = trailPos, t = now })
            end

            for i = #t.points, 1, -1 do
                if now - t.points[i].t > duration or i > MT_MAX_POINTS then
                    table.remove(t.points, i)
                end
            end

            local nSeg = #t.points - 1

            for i = 1, nSeg do
                local p1 = t.points[i]
                local p2 = t.points[i + 1]
                if not (p1 and p2) then continue end

                if not t.olLines[i] then
                    local ol = Drawing.new("Line")
                    ol.Color = Color3.new(0, 0, 0)
                    ol.ZIndex = 1
                    ol.Visible = false
                    t.olLines[i] = ol
                end
                if not t.lines[i] then
                    local l = Drawing.new("Line")
                    l.ZIndex = 2
                    l.Visible = false
                    t.lines[i] = l
                end

                local sp1 = cam:WorldToViewportPoint(p1.pos)
                local sp2 = cam:WorldToViewportPoint(p2.pos)

                if sp1.Z > 0 and sp2.Z > 0 then
                    local alpha = math.clamp(1 - ((now - p1.t) / duration), 0, 1)
                    local from = Vector2.new(sp1.X, sp1.Y)
                    local to   = Vector2.new(sp2.X, sp2.Y)

                    t.olLines[i].From = from; t.olLines[i].To = to
                    t.olLines[i].Thickness = thickness + 2
                    t.olLines[i].Transparency = alpha * 0.5
                    t.olLines[i].Visible = true

                    t.lines[i].From = from; t.lines[i].To = to
                    t.lines[i].Color = trailColor
                    t.lines[i].Thickness = thickness
                    t.lines[i].Transparency = alpha
                    t.lines[i].Visible = true
                else
                    t.olLines[i].Visible = false
                    t.lines[i].Visible = false
                end
            end

            for i = nSeg + 1, #t.lines do
                if t.lines[i]   then t.lines[i].Visible   = false end
                if t.olLines[i] then t.olLines[i].Visible = false end
            end
        end
    end)
end

_C.openTab()
task.wait()

do
    local _flySpeed   = 50
    local _orbitSpeed = 80
    local _orbitRadius = 12
    local _orbitHeight = 6
    local _flying      = false
    local _orbitEnabled = false
    local _orbitTarget  = nil
    local _orbitAngle   = 0
    local _bv, _bg, _flyConn
    local _keysDown = {}

    local UIS = game:GetService("UserInputService")

    local function stopFly()
        _flying = false
        if _flyConn then _flyConn:Disconnect() _flyConn = nil end
        if _bv then _bv:Destroy() _bv = nil end
        if _bg then _bg:Destroy() _bg = nil end
        pcall(function()
            local char = Players.LocalPlayer.Character
            if char then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then hum.PlatformStand = false end
            end
        end)
    end

    local function ensureFlyBodies()
        local char = Players.LocalPlayer.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        if not root then return nil end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = true end

        if not _bv or not _bv.Parent then
            if _bv then pcall(function() _bv:Destroy() end) end
            _bv = Instance.new("BodyVelocity")
            _bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
            _bv.Velocity = Vector3.zero
            _bv.Parent = root
        end
        if not _bg or not _bg.Parent then
            if _bg then pcall(function() _bg:Destroy() end) end
            _bg = Instance.new("BodyGyro")
            _bg.MaxTorque = Vector3.new(1e9, 1e9, 1e9)
            _bg.Parent = root
        end
        return root
    end

    local function startFly()

        if _flyConn then _flyConn:Disconnect() _flyConn = nil end
        if _bv then pcall(function() _bv:Destroy() end); _bv = nil end
        if _bg then pcall(function() _bg:Destroy() end); _bg = nil end
        _flying = true
        local cam = workspace.CurrentCamera
        _flyConn = game:GetService("RunService").Heartbeat:Connect(function(dt)
            local root = ensureFlyBodies()
            if not root then return end

            if _orbitEnabled and _orbitTarget and _orbitTarget.Character and _orbitTarget.Character:FindFirstChild("HumanoidRootPart") then
                local tr = _orbitTarget.Character.HumanoidRootPart
                _orbitAngle = _orbitAngle + (_orbitSpeed / 100) * dt * 5
                local targetPos = tr.Position + Vector3.new(
                    math.cos(_orbitAngle) * _orbitRadius,
                    _orbitHeight,
                    math.sin(_orbitAngle) * _orbitRadius
                )
                _bv.Velocity = (targetPos - root.Position) * 10

                _bg.CFrame = CFrame.new(root.Position, tr.Position)

                local cam = workspace.CurrentCamera
                cam.CFrame = CFrame.new(cam.CFrame.Position, tr.Position)

                local char = Players.LocalPlayer.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then
                            part.CanCollide = false
                        end
                    end
                end
            else
                local dir = Vector3.zero
                local cf  = cam.CFrame
                if _keysDown[Enum.KeyCode.W] or _keysDown[Enum.KeyCode.Z] then dir = dir + cf.LookVector  end
                if _keysDown[Enum.KeyCode.S]                               then dir = dir - cf.LookVector  end
                if _keysDown[Enum.KeyCode.D]                               then dir = dir + cf.RightVector end
                if _keysDown[Enum.KeyCode.A] or _keysDown[Enum.KeyCode.Q]  then dir = dir - cf.RightVector end
                if _keysDown[Enum.KeyCode.Space]                           then dir = dir + Vector3.new(0,1,0) end
                if _keysDown[Enum.KeyCode.LeftControl]                     then dir = dir - Vector3.new(0,1,0) end
                _bv.Velocity = dir.Magnitude > 0 and dir.Unit * _flySpeed or Vector3.zero
                _bg.CFrame = CFrame.new(root.Position, root.Position + Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z))
            end
        end)
    end

    UIS.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        _keysDown[input.KeyCode] = true
    end)
    UIS.InputEnded:Connect(function(input)
        _keysDown[input.KeyCode] = nil
    end)

    local secExtras = _C.extrasCol:section({name = "Extras", toggle = false})

    do
    local _hitsoundConn = nil
    local _hitsoundForcedVol = nil

    local function startHitSound()
        if _hitsoundConn then _hitsoundConn:Disconnect() end
        local vm = Players.LocalPlayer.PlayerScripts.Modules.ClientReplicatedClasses.ClientFighter.ClientItem.ClientViewModel
        _hitsoundConn = vm.ChildAdded:Connect(function(v)
            if v:IsA("Sound") and v.SoundId ~= "rbxassetid://16537449730" then
                local soundId = library.flags["HitSoundID"] or "rbxassetid://4764109000"
                local vol = _hitsoundForcedVol or ((library.flags["HitSoundVol"] or 80) / 100)
                v.SoundId = soundId
                v.Volume = vol
                v.PlaybackSpeed = 1
            end
        end)
    end
    local function stopHitSound()
        if _hitsoundConn then _hitsoundConn:Disconnect(); _hitsoundConn = nil end
    end

    local _presetForcedVol = {
        ["TF2"] = 1.4,
        ["COD"] = 1.4,
    }

    local _hitsoundPresets = {
        ["Hitsound"]                  = "rbxassetid://131402237954472",
        ["Sonic.EXE"]                 = "rbxassetid://137584754609456",
        ["Skeet (louder)"]            = "rbxassetid://140247876667835",
        ["Fortnite"]                  = "rbxassetid://132390332380260",
        ["Metallic"]                  = "rbxassetid://96599967895283",
        ["TF2"]                       = "rbxassetid://95940995811019",
        ["Gamesense"]                 = "rbxassetid://94204395881101",
        ["Pop"]                       = "rbxassetid://93792465602361",
        ["CSGO Assembly"]             = "rbxassetid://80803263857916",
        ["COD"]                       = "rbxassetid://77082587278347",
        ["Ding"]                      = "rbxassetid://133404230021566",
        ["Rust (default)"]             = "rbxassetid://4764109000",
    }
    local _presetNames = {}
    for k in pairs(_hitsoundPresets) do table.insert(_presetNames, k) end
    table.sort(_presetNames)

    secExtras:label({name = "— Hitsound —"})
    secExtras:toggle({name = "Hitsound", flag = "HitSound", callback = function(v)
        if v then startHitSound() else stopHitSound() end
    end})
    secExtras:dropdown({name = "Preset", flag = "HitSoundPreset", items = _presetNames, callback = function(name)
        if name and _hitsoundPresets[name] then
            library.flags["HitSoundID"] = _hitsoundPresets[name]
            _hitsoundForcedVol = _presetForcedVol[name] or nil
        end
    end})
    secExtras:textbox({name = "Sound ID custom", flag = "HitSoundID", default = "rbxassetid://4764109000", callback = function() end})
    secExtras:slider({name = "Volume", flag = "HitSoundVol", min = 0, max = 100, default = 80, callback = function() end})
    end

    local function _restoreCollisions()
        local char = Players.LocalPlayer.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = true
                end
            end
        end
    end

    secExtras:toggle({name = "Orbit", flag = "OrbitEnabled", callback = function(v)
        if v then
            if not _orbitTarget then
                return
            end
            _orbitEnabled = true
            startFly()
        else
            _orbitEnabled = false
            _restoreCollisions()
            if not library.flags["FlyEnabled"] and not library.flags["FlyKey"] then stopFly() end
        end
    end})
        :keybind({name = "Orbit Key", flag = "OrbitKey", key = Enum.KeyCode.G, mode = "toggle", callback = function(v)
            if not library.flags["OrbitEnabled"] then return end
            if v then
                if not _orbitTarget then return end
                _orbitEnabled = true
                startFly()
            else
                _orbitEnabled = false
                _restoreCollisions()
                if not library.flags["FlyEnabled"] then stopFly() end
            end
        end})

    secExtras:slider({name = "Orbit Speed", flag = "OrbitSpeed", min = 10, max = 300, default = 80, callback = function(v)
        _orbitSpeed = v
    end})

    secExtras:slider({name = "Orbit Radius", flag = "OrbitRadius", min = 3, max = 100, default = 12, callback = function(v)
        _orbitRadius = v
    end})

    secExtras:button({name = "Select Orbit Target", callback = function()
        local playerNames = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Players.LocalPlayer then
                table.insert(playerNames, p.Name)
            end
        end
        if #playerNames == 0 then
            return
        end
        for i, name in ipairs(playerNames) do
        end
    end})
    secExtras:dropdown({name = "Orbit Target", flag = "OrbitTarget", items = (function()
        local names = {"-- None --"}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Players.LocalPlayer then table.insert(names, p.Name) end
        end
        return names
    end)(), callback = function(name)
        if not name or name == "-- None --" then _orbitTarget = nil; return end
        _orbitTarget = Players:FindFirstChild(name)
    end})

    secExtras:button({name = "Refresh Player List", callback = function()
        local names = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= Players.LocalPlayer then table.insert(names, p.Name) end
        end

    end})

    do
    local _rushConn = nil
    local _rushTarget = nil
    local _rushSavedFov, _rushSavedSilent, _rushSavedAutoFire = nil, nil, nil
    local _rushCharConn = nil

    local function _rushMaxDist()
        return library.flags["RushMaxDist"] or 400
    end

    local function _rushHeight()
        return library.flags["RushHeight"] or 2
    end

    local function _getClosestEnemyInRange()
        local lp = Players.LocalPlayer
        local myChar = lp.Character
        local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
        if not myRoot then return nil end
        local maxD = _rushMaxDist()
        local best, bestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p == lp then continue end
            if not _isEnemy(p) then continue end
            local char = p.Character
            local hr = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hr or not hum or hum.Health <= 0 then continue end
            local d = (hr.Position - myRoot.Position).Magnitude
            if d > maxD then continue end
            if d < bestDist then bestDist = d; best = p end
        end
        return best
    end

    local function _rushDisconnectLoop()
        if _rushConn then
            _rushConn:Disconnect()
            _rushConn = nil
        end
    end

    local function _rushRestoreAim()
        if _rushSavedFov ~= nil then library.flags["AimFOV"] = _rushSavedFov end
        if _rushSavedSilent ~= nil then library.flags["SilentAim"] = _rushSavedSilent end
        if _rushSavedAutoFire ~= nil then library.flags["AimAutoFire"] = _rushSavedAutoFire end
        _rushSavedFov, _rushSavedSilent, _rushSavedAutoFire = nil, nil, nil
    end

    local function pauseRush()
        _rushDisconnectLoop()
        _rushTarget = nil
        _rushRestoreAim()
    end

    local function stopRush()
        pauseRush()
        library.flags["RushEnabled"] = false
    end

    local function _rushTargetOk(mRoot, t, maxD)
        if not t then return false end
        local c = t.Character
        local hr = c and c:FindFirstChild("HumanoidRootPart")
        local hum = c and c:FindFirstChildOfClass("Humanoid")
        if not hr or not hum or hum.Health <= 0 then return false end
        if not _isEnemy(t) then return false end
        if (hr.Position - mRoot.Position).Magnitude > maxD then return false end
        return true
    end

    local function startRush()
        if not library.flags["RushEnabled"] then return end

        _rushDisconnectLoop()
        _rushTarget = nil

        if _rushSavedFov == nil then
            _rushSavedFov = library.flags["AimFOV"]
            _rushSavedSilent = library.flags["SilentAim"]
            _rushSavedAutoFire = library.flags["AimAutoFire"]
        end
        library.flags["SilentAim"] = true
        library.flags["AimAutoFire"] = true
        library.flags["AimFOV"] = 800

        local maxD = _rushMaxDist()

        _rushConn = RunService.Heartbeat:Connect(function()
            if not library.flags["RushEnabled"] then return end

            local lp = Players.LocalPlayer
            local mRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
            if not mRoot then

                return
            end

            local md = _rushMaxDist()
            if not _rushTargetOk(mRoot, _rushTarget, md) then
                _rushTarget = _getClosestEnemyInRange()
                if not _rushTarget then

                    return
                end
            end

            local tRoot = _rushTarget.Character and _rushTarget.Character:FindFirstChild("HumanoidRootPart")
            if not tRoot then return end
            local yOff = _rushHeight()
            mRoot.CFrame = CFrame.new(tRoot.Position + Vector3.new(0, yOff, 0))
        end)

        _rushTarget = _getClosestEnemyInRange()
        if _rushTarget then
        else
        end
    end

    _rushCharConn = Players.LocalPlayer.CharacterAdded:Connect(function()
        _rushTarget = nil
        task.defer(function()
            task.wait(0.35)
            if library.flags["RushEnabled"] and _rushConn == nil then
                startRush()
            end
        end)
    end)

    secExtras:label({name = "— Rush Kill —"})
    secExtras:slider({name = "Rush Max Distance", flag = "RushMaxDist", min = 50, max = 1500, default = 400, callback = function() end})
    secExtras:slider({name = "Rush Height (studs)", flag = "RushHeight", min = 0, max = 25, default = 2, callback = function() end})
    secExtras:toggle({name = "Rush Kill", flag = "RushEnabled", callback = function(v)
        if v then startRush() else stopRush() end
    end})
        :keybind({name = "Rush Key", flag = "RushKey", key = Enum.KeyCode.R, mode = "toggle", callback = function(v)
            if not library.flags["RushEnabled"] then return end
            if v then
                startRush()
            else
                pauseRush()
            end
        end})
    end

    do
        local _rbConn = nil
        local _rbTarget = nil
        local _rbCharConn = nil

        local function _rbGetClosest()
            local lp = Players.LocalPlayer
            local myChar = lp.Character
            local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
            if not myRoot then return nil end
            local maxD = library.flags["RBMaxDist"] or 400
            local best, bestDist = nil, math.huge
            for _, p in ipairs(Players:GetPlayers()) do
                if p == lp then continue end
                if not _isEnemy(p) then continue end
                local char = p.Character
                local hr = char and char:FindFirstChild("HumanoidRootPart")
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if not hr or not hum or hum.Health <= 0 then continue end
                local d = (hr.Position - myRoot.Position).Magnitude
                if d > maxD then continue end
                if d < bestDist then bestDist = d; best = p end
            end
            return best
        end

        local function _rbTargetOk(mRoot, t)
            if not t then return false end
            local c = t.Character
            local hr = c and c:FindFirstChild("HumanoidRootPart")
            local hum = c and c:FindFirstChildOfClass("Humanoid")
            if not hr or not hum or hum.Health <= 0 then return false end
            if not _isEnemy(t) then return false end
            local maxD = library.flags["RBMaxDist"] or 400
            if (hr.Position - mRoot.Position).Magnitude > maxD then return false end
            return true
        end

        local function _rbDisconnect()
            if _rbConn then _rbConn:Disconnect(); _rbConn = nil end
        end

        local function stopRB()
            _rbDisconnect()
            _rbTarget = nil
            library.flags["RBEnabled"] = false
        end

        local function pauseRB()
            _rbDisconnect()
            _rbTarget = nil
        end

        local function startRB()
            if not library.flags["RBEnabled"] then return end
            _rbDisconnect()
            _rbTarget = nil

            _rbConn = RunService.Heartbeat:Connect(function()
                if not library.flags["RBEnabled"] then return end

                local lp = Players.LocalPlayer
                local mRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
                if not mRoot then return end

                if not _rbTargetOk(mRoot, _rbTarget) then
                    _rbTarget = _rbGetClosest()
                    if not _rbTarget then return end
                end

                local tRoot = _rbTarget.Character and _rbTarget.Character:FindFirstChild("HumanoidRootPart")
                if not tRoot then return end

                local backDist = library.flags["RBBackDist"] or 3
                local lookFlat = Vector3.new(tRoot.CFrame.LookVector.X, 0, tRoot.CFrame.LookVector.Z)
                if lookFlat.Magnitude < 0.01 then return end
                lookFlat = lookFlat.Unit
                local behindPos = tRoot.Position - lookFlat * backDist
                mRoot.CFrame = CFrame.new(behindPos, tRoot.Position)
            end)

            _rbTarget = _rbGetClosest()
            if _rbTarget then
            else
            end
        end

        _rbCharConn = Players.LocalPlayer.CharacterAdded:Connect(function()
            _rbTarget = nil
            task.defer(function()
                task.wait(0.35)
                if library.flags["RBEnabled"] and _rbConn == nil then
                    startRB()
                end
            end)
        end)

        secExtras:label({name = "— Rush Back —"})
        secExtras:slider({name = "Back Max Distance", flag = "RBMaxDist", min = 50, max = 1500, default = 400, callback = function() end})
        secExtras:slider({name = "Back Distance (studs)", flag = "RBBackDist", min = 1, max = 15, default = 3, callback = function() end})
        secExtras:toggle({name = "Rush Back", flag = "RBEnabled", callback = function(v)
            if v then startRB() else stopRB() end
        end})
            :keybind({name = "Rush Back Key", flag = "RBKey", key = Enum.KeyCode.T, mode = "toggle", callback = function(v)
                if not library.flags["RBEnabled"] then return end
                if v then
                    startRB()
                else
                    pauseRB()
                end
            end})
    end

    do
    local function _getRoot()
        local char = Players.LocalPlayer.Character
        return char and char:FindFirstChild("HumanoidRootPart")
    end

    local function _getClosestEnemy()
        local root = _getRoot()
        if not root then return nil end
        local best, bestDist = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p == Players.LocalPlayer then continue end
            local char = p.Character
            local hr = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if not hr or not hum or hum.Health <= 0 then continue end
            local d = (hr.Position - root.Position).Magnitude
            if d < bestDist then bestDist = d; best = hr end
        end
        return best
    end

    Players.LocalPlayer.CharacterAdded:Connect(function()
        library.flags["XlagEnabled"] = false
    end)

    local _xlagRealCF = nil
    RunService.PreSimulation:Connect(function()
        if not library.flags["XlagEnabled"] then return end
        local root = _getRoot()
        if not root then return end
        local enemy = _getClosestEnemy()
        if not enemy then return end
        _xlagRealCF = root.CFrame
        root.CFrame = CFrame.new(enemy.Position)
    end)

    RunService.PostSimulation:Connect(function()
        if not library.flags["XlagEnabled"] then return end
        if not _xlagRealCF then return end
        local root = _getRoot()
        if not root then return end
        root.CFrame = _xlagRealCF
        _xlagRealCF = nil
    end)

    secExtras:toggle({name = "Xlag (Desync)", flag = "XlagEnabled", callback = function(v)
    end})
        :keybind({name = "Xlag Key", flag = "XlagKey", key = Enum.KeyCode.F1, mode = "toggle", callback = function(v)
            if not library.flags["XlagEnabled"] then return end
        end})
    end

    local secMouv = _C.extrasCol2:section({name = "Movement", toggle = false})

    secMouv:toggle({name = "Fly", flag = "FlyEnabled", callback = function(v)
        if v then startFly() else stopFly() end
    end})
        :keybind({name = "Fly Key", flag = "FlyKey", key = Enum.KeyCode.F, mode = "toggle", callback = function(v)
            if not library.flags["FlyEnabled"] then return end
            if v then startFly() else stopFly() end
        end})
    secMouv:slider({name = "Fly Speed", flag = "FlySpeed", min = 1, max = 300, default = 50, callback = function(v)
        _flySpeed = v
    end})

    do
    local _djCanDouble = false
    local _djConn1, _djConn2, _djConn3 = nil, nil, nil

    local function setupDoubleJump(char)
        local hum = char:WaitForChild("Humanoid", 10)
        if not hum then return end
        if _djConn1 then _djConn1:Disconnect() end
        _djConn1 = hum.StateChanged:Connect(function(_, new)
            if new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Freefall then
                task.wait(0.15)
                _djCanDouble = true
            end
        end)
    end

    local function startDoubleJump()
        local lp = game:GetService("Players").LocalPlayer
        local UIS = game:GetService("UserInputService")
        if _djConn2 then _djConn2:Disconnect() end
        _djConn2 = UIS.JumpRequest:Connect(function()
            local char = lp.Character
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if not hum then return end
            local state = hum:GetState()
            if _djCanDouble
                and state ~= Enum.HumanoidStateType.Landed
                and state ~= Enum.HumanoidStateType.Dead
            then
                _djCanDouble = false
                hum:ChangeState(Enum.HumanoidStateType.Jumping)
                task.delay(0.15, function() _djCanDouble = true end)
            end
        end)
        if lp.Character then setupDoubleJump(lp.Character) end
        if _djConn3 then _djConn3:Disconnect() end
        _djConn3 = lp.CharacterAdded:Connect(setupDoubleJump)
    end

    local function stopDoubleJump()
        _djCanDouble = false
        if _djConn1 then _djConn1:Disconnect(); _djConn1 = nil end
        if _djConn2 then _djConn2:Disconnect(); _djConn2 = nil end
        if _djConn3 then _djConn3:Disconnect(); _djConn3 = nil end
    end

    secMouv:toggle({name = "Double Jump", flag = "DoubleJumpEnabled", callback = function(v)
        if v then startDoubleJump() else stopDoubleJump() end
    end})
    end

    do
    local _origWalkSpeed = nil
    local _wsConn = nil
    local _wsCharConn = nil

    local function _wsApply(char)
        if not library.flags["WalkSpeedEnabled"] then return end
        local hum = char:WaitForChild("Humanoid", 5)
        if not hum then return end
        _origWalkSpeed = _origWalkSpeed or hum.WalkSpeed
        local target = library.flags["WalkSpeedVal"] or 16
        hum.WalkSpeed = target
        if _wsConn then _wsConn:Disconnect() end
        _wsConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
            if library.flags["WalkSpeedEnabled"] then
                local t = library.flags["WalkSpeedVal"] or 16
                if hum.WalkSpeed ~= t then
                    hum.WalkSpeed = t
                end
            end
        end)
    end

    secMouv:toggle({name = "WalkSpeed", flag = "WalkSpeedEnabled", callback = function(v)
        local lp = game:GetService("Players").LocalPlayer
        if v then
            if _wsCharConn then _wsCharConn:Disconnect() end
            _wsCharConn = lp.CharacterAdded:Connect(function(c)
                task.defer(_wsApply, c)
            end)
            local char = lp.Character
            if char then task.defer(_wsApply, char) end
        else
            if _wsCharConn then _wsCharConn:Disconnect(); _wsCharConn = nil end
            if _wsConn then _wsConn:Disconnect(); _wsConn = nil end
            local char = lp.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and _origWalkSpeed then hum.WalkSpeed = _origWalkSpeed end
            _origWalkSpeed = nil
        end
    end})
    secMouv:slider({name = "Speed", flag = "WalkSpeedVal", min = 16, max = 200, default = 16, callback = function(v)
        if not library.flags["WalkSpeedEnabled"] then return end
        local char = game:GetService("Players").LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = v end
    end})
    end
end

task.wait()

do
    local _wpnPatched   = setmetatable({}, { __mode = "k" })
    local _wpnLoopConn  = nil
    local _wpnCharConn  = nil
    local _wpnChildConn = nil

    local function patchGunInfos()
        if type(getgc) ~= "function" then return end
        local count = 0
        pcall(function()
            for _, v in pairs(getgc(true)) do
                if type(v) == "table" and not _wpnPatched[v] then
                    local ok1, recoil   = pcall(rawget, v, "ShootRecoil")
                    local ok2, spread   = pcall(rawget, v, "ShootSpread")
                    local ok3, cooldown = pcall(rawget, v, "ShootCooldown")
                    if ok1 and ok2 and ok3
                        and type(recoil) == "number"
                        and type(spread) == "number"
                        and type(cooldown) == "number"
                    then
                        _wpnPatched[v] = true
                        pcall(function()
                            if library.flags["WpnNoRecoil"]  then v.ShootRecoil   = 0 end
                            if library.flags["WpnNoSpread"]  then v.ShootSpread   = 0 end
                            if library.flags["WpnNoCooldown"] then
                                v.ShootCooldown = 0
                                if type(rawget(v, "QuickShootCooldown")) == "number" then v.QuickShootCooldown = 0 end
                                if type(rawget(v, "BladeCooldown"))      == "number" then v.BladeCooldown      = 0 end
                                if type(rawget(v, "TransformDelay"))     == "number" then v.TransformDelay     = 0 end
                                if type(rawget(v, "TransitionCooldown")) == "number" then v.TransitionCooldown = 0 end
                            end
                            if library.flags["WpnNoReload"] then
                                if type(rawget(v, "ReloadLength"))      == "number" then v.ReloadLength      = 0 end
                                if type(rawget(v, "EmptyReloadLength")) == "number" then v.EmptyReloadLength = 0 end
                                if type(rawget(v, "ReloadCooldown"))    == "number" then v.ReloadCooldown    = 0 end
                            end
                            if library.flags["WpnNoDash"] then
                                if type(rawget(v, "DashCooldown")) == "number" then v.DashCooldown = 0 end
                            end
                            if library.flags["WpnFastBullets"] then
                                if type(rawget(v, "ProjectileSpeed")) == "number" then v.ProjectileSpeed = 99999999 end
                            end
                        end)
                        count = count + 1
                    end
                end
            end
        end)
        if count > 0 then
        end
    end

    local function watchCharWeapons(char)
        if _wpnChildConn then _wpnChildConn:Disconnect() end
        _wpnChildConn = char.ChildAdded:Connect(function(child)
            if child:IsA("Tool") then
                task.wait(0.3)

                _wpnPatched = setmetatable({}, { __mode = "k" })
                patchGunInfos()
            end
        end)
    end

    local _wpnStarted = false

    local function startWeaponPatch()

        _wpnPatched = setmetatable({}, { __mode = "k" })
        patchGunInfos()

        if _wpnStarted then return end
        _wpnStarted = true

        local lp = Players.LocalPlayer
        if lp.Character then watchCharWeapons(lp.Character) end
        _wpnCharConn = lp.CharacterAdded:Connect(function(char)
            task.wait(0.5)
            watchCharWeapons(char)
            _wpnPatched = setmetatable({}, { __mode = "k" })
            patchGunInfos()
        end)

        task.spawn(function()
            while _wpnStarted do
                task.wait(3)
                local anyActive = library.flags["WpnNoRecoil"]
                    or library.flags["WpnNoSpread"]
                    or library.flags["WpnNoCooldown"]
                    or library.flags["WpnNoReload"]
                    or library.flags["WpnNoDash"]
                    or library.flags["WpnFastBullets"]
                if anyActive then
                    _wpnPatched = setmetatable({}, { __mode = "k" })
                    patchGunInfos()
                end
            end
        end)
    end

    local secGunMods = _C.weaponsCol:section({name = "Gun Modifiers", toggle = false})

    local secWpnColor = _C.weaponsCol:section({name = "Weapon Color", toggle = false})
    secWpnColor:toggle({name = "Weapon Color", flag = "weapon_color_toggle"})
        :colorpicker({name = "Color", color = Color3.new(1, 1, 1), flag = "weapon_color", callback = function(color, alpha)
            if not TARGET_WEAPON then return end
            local weapon = ViewModels.Weapons[TARGET_WEAPON]
            local parts = getAllParts(weapon)
            if not next(originalColors) then
                for _, part in ipairs(parts) do
                    originalColors[part] = part.Color
                end
            end
            for _, part in ipairs(parts) do
                part.Color = color
            end
        end})
    secWpnColor:button({name = "Reset Color", callback = function()
        if not next(originalColors) then return end
        for part, color in pairs(originalColors) do
            if part and part.Parent then
                part.Color = color
            end
        end
        originalColors = {}
    end})

    if HAS_GETGC then
        secGunMods:toggle({name = "No Recoil", flag = "WpnNoRecoil", callback = function(v)
            if v then startWeaponPatch() end
        end})

        secGunMods:toggle({name = "No Spread", flag = "WpnNoSpread", callback = function(v)
            if v then startWeaponPatch() end
        end})

        secGunMods:toggle({name = "No Shoot Cooldown", flag = "WpnNoCooldown", callback = function(v)
            if v then startWeaponPatch() end
        end})

        secGunMods:toggle({name = "Instant Reload", flag = "WpnNoReload", callback = function(v)
            if v then startWeaponPatch() end
        end})

        secGunMods:toggle({name = "No Dash Cooldown", flag = "WpnNoDash", callback = function(v)
            if v then startWeaponPatch() end
        end})

        secGunMods:toggle({name = "Fast Bullets", flag = "WpnFastBullets", callback = function(v)
            if v then startWeaponPatch() end
        end})

        secGunMods:button({name = "Force Re-Patch All", callback = function()
            _wpnPatched = setmetatable({}, { __mode = "k" })
            patchGunInfos()
        end})
    else
        secGunMods:label({name = "Gun Modifiers require getgc"})
        secGunMods:label({name = "Not supported on " .. _executorName})
    end

    local secAutoFire = _C.weaponsCol2:section({name = "Auto Fire", toggle = false})

    if HAS_MOUSE1PRESS then
        local _autoFireConn = nil
        local _autoFireDelay = 0.01

        local function startAutoFire()
            if _autoFireConn then _autoFireConn:Disconnect(); _autoFireConn = nil end
            local UIS = game:GetService("UserInputService")
            local holding = false

            UIS.InputBegan:Connect(function(input, gpe)
                if gpe then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    holding = true
                end
            end)
            UIS.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    holding = false
                end
            end)

            _autoFireConn = game:GetService("RunService").Heartbeat:Connect(function()
                if not library.flags["WpnAutoFire"] then return end
                if not holding then return end
                mouse1release()
                task.wait(_autoFireDelay)
                mouse1press()
            end)
        end

        secAutoFire:toggle({name = "Auto Fire (Hold LMB)", flag = "WpnAutoFire", callback = function(v)
            if v then startAutoFire() end
        end})

        secAutoFire:slider({name = "Fire Delay (ms)", flag = "WpnAutoFireDelay", min = 0, max = 100, default = 10, callback = function(v)
            _autoFireDelay = v / 1000
        end})

        secAutoFire:label({name = "Hold Left Click to spam fire"})
        secAutoFire:label({name = "Lower delay = faster fire rate"})
    else
        secAutoFire:label({name = "Auto Fire requires mouse1press"})
        secAutoFire:label({name = "Not supported on " .. _executorName})
    end

    local secSwitch = _C.weaponsCol2:section({name = "Instant Weapon Switch", toggle = false})
    do
        local EQUIP_SPEED = 10
        local _instantSwitch = false
        local _hookedTracks = {}
        local _switchCharConn = nil

        local function hookAnimator(char)
            if not char then return end
            local hum = char:FindFirstChildOfClass("Humanoid")
                or char:WaitForChild("Humanoid", 5)
            if not hum then return end
            local animator = hum:FindFirstChildOfClass("Animator")
            if not animator then return end

            animator.AnimationPlayed:Connect(function(track)
                if not _instantSwitch then return end
                if _hookedTracks[track] then return end
                _hookedTracks[track] = true

                local name = track.Animation and track.Animation.Name or ""
                local low = name:lower()
                if low:find("equip") or low:find("draw") or low:find("pullout")
                    or low:find("unholster") or low:find("swap") or low:find("switch") then
                    track:AdjustSpeed(EQUIP_SPEED)
                end
            end)
        end

        secSwitch:toggle({name = "Instant Switch", flag = "WpnInstantSwitch", callback = function(v)
            _instantSwitch = v
            _hookedTracks = {}
            if v then
                local lp = Players.LocalPlayer
                if lp.Character then hookAnimator(lp.Character) end
                if not _switchCharConn then
                    _switchCharConn = lp.CharacterAdded:Connect(function(char)
                        task.wait(0.3)
                        if _instantSwitch then hookAnimator(char) end
                    end)
                end
            end
        end})

        secSwitch:slider({name = "Switch Speed", flag = "WpnSwitchSpeed", min = 2, max = 50, default = 10, callback = function(v)
            EQUIP_SPEED = v
        end})
    end

    local secGunInfo = _C.weaponsCol2:section({name = "Info", toggle = false})
    secGunInfo:label({name = "Executor: " .. _executorName})
    secGunInfo:label({name = "getgc: " .. (HAS_GETGC and "Yes" or "No")})
    secGunInfo:label({name = "mouse1press: " .. (HAS_MOUSE1PRESS and "Yes" or "No")})
    secGunInfo:label({name = "mousemoverel: " .. (HAS_MOUSEMOVEREL and "Yes" or "No")})
    secGunInfo:label({name = "mouse1click: " .. (HAS_MOUSE1CLICK and "Yes" or "No")})
    secGunInfo:label({name = "Made by: unauth0rised"})
end

pcall(function() library:config_list_update() end)

for index, value in themes.preset do
    pcall(function()
        library:update_theme(index, value)
    end)
end

task.wait()

library.old_config = library:get_config()

local _configDirty = false
local function markConfigDirty() _configDirty = true end

local function saveConfig(force)
    if not force and not _configDirty then return end
    pcall(function() makefolder("unlock-rivals") end)
    local ok, err = pcall(function()
        local data = library:get_config()
        if data and #data > 2 then
            if not force and data == library.old_config then
                _configDirty = false
                return
            end
            writefile(CONFIG_FILE, data)
            library.old_config = data
            _configDirty = false
        end
    end)
end

local function loadConfig()
    local raw = nil
    pcall(function()
        if isfile(CONFIG_FILE) then
            raw = readfile(CONFIG_FILE)
        end
    end)

    if not raw then

        pcall(function()
            if isfile("rivals_config.json") then
                raw = readfile("rivals_config.json")
            end
        end)
    end

    if not raw or #raw < 3 then
        return false
    end
    local ok, err = pcall(function()
        raw = raw:gsub('"keybind_list"%s*:%s*true', '"keybind_list":false')
        raw = raw:gsub('"watermark"%s*:%s*true',    '"watermark":false')
        -- Progressive config load: apply flags in small batches with yields
        local config = game:GetService("HttpService"):JSONDecode(raw)
        local batch = 0
        local BATCH_SIZE = 3
        for flagName, v in next, config do
            local fn = library.config_flags[flagName]
            if fn then
                pcall(function()
                    if type(v) == "table" and v["Transparency"] and v["Color"] then
                        fn(Color3.fromHex(v["Color"]), v["Transparency"])
                    else
                        fn(v)
                    end
                end)
                batch = batch + 1
                if batch >= BATCH_SIZE then
                    batch = 0
                    task.wait()
                end
            end
        end
    end)

    if ok then
    else

    end

    pcall(function()
        if library.keybind_list_frame then
            library.keybind_list_frame.Visible = false
        end
        library.flags["keybind_list"] = false
        library.flags["watermark"]    = false
    end)
    return ok
end

task.wait(0.5)
loadConfig()
_worldReady = true

-- Progressive loading complete: reveal the UI
_loadingUI = false
pcall(function()
    for _, gui in library.guis do
        if gui and gui:IsA("ScreenGui") then
            gui.Enabled = true
        end
    end
end)
menuVisible = true

task.spawn(function()
    while task.wait(60) do
        pcall(function()
            local data = library:get_config()
            if data and #data > 2 and data ~= library.old_config then
                pcall(function() makefolder("unlock-rivals") end)
                writefile(CONFIG_FILE, data)
                library.old_config = data
            end
        end)
    end
end)

local _allConnections = {}

game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.Delete and not gameProcessed then
        saveConfig(true)
        pcall(resetAllWeapons)

        pcall(function()
            if library.flags["Fullbright"] then
                Lighting.Ambient = _origLighting.Ambient
                Lighting.OutdoorAmbient = _origLighting.OutdoorAmbient
                Lighting.Brightness = _origLighting.Brightness
                Lighting.FogEnd = _origLighting.FogEnd
                Lighting.GlobalShadows = _origLighting.GlobalShadows
            end
            if library.flags["NoFog"] then
                Lighting.FogStart = _origLighting.FogStart
                Lighting.FogEnd = _origLighting.FogEnd
            end
            if library.flags["NoShadows"] then
                Lighting.GlobalShadows = _origLighting.GlobalShadows
            end
            if library.flags["AmbientOverride"] then
                Lighting.Ambient = _origLighting.Ambient
                Lighting.OutdoorAmbient = _origLighting.OutdoorAmbient
            end
            if library.flags["FogColorOverride"] then
                Lighting.FogColor = _origLighting.FogColor
            end
            if library.flags["ColorShiftTopOn"] then
                Lighting.ColorShift_Top = _origLighting.ColorShift_Top
            end
            if library.flags["ColorShiftBotOn"] then
                Lighting.ColorShift_Bottom = _origLighting.ColorShift_Bottom
            end
            if library.flags["NoPostFX"] then
                for fx, orig in pairs(_origPostFX) do
                    if fx and fx.Parent then fx.Enabled = orig end
                end
            end
            if library.flags["RemoveSky"] and _origSky then
                _origSky.Parent = Lighting
            end
        end)
        _worldReady = false

        for _, conn in ipairs(_allConnections) do
            pcall(function() conn:Disconnect() end)
        end

        for _, d in pairs(espObjs) do
            pcall(function() removeESP(d) end)
        end
        for _, hl in pairs(chamsObjs) do
            pcall(function() hl:Destroy() end)
        end
        chamsObjs = {}
        pcall(function() fovCircle:Remove() end)
        pcall(function() fovCircleOutline:Remove() end)
        pcall(function() aimbotFovCircle:Remove() end)
        pcall(function() aimbotFovOutline:Remove() end)

        pcall(function()
            if library.keybind_list_frame then
                library.keybind_list_frame.Visible = false
            end
            library.flags["keybind_list"] = false
            library.flags["watermark"]    = false
        end)
        pcall(function() window.set_menu_visibility(false) end)
        pcall(function()
            local gui = game:GetService("Players").LocalPlayer.PlayerGui
            for _, v in ipairs(gui:GetChildren()) do
                if v.Name:find("Atlanta") or v.Name:find("Library") or v.Name:find("Rivals") then
                    v:Destroy()
                end
            end
        end)

        pcall(function()
            if type(getconnections) == "function" then
                for _, svc in ipairs({
                    game:GetService("RunService"),
                    game:GetService("UserInputService"),
                    workspace,
                }) do
                    local ok, conns = pcall(getconnections, svc)
                    if ok and conns then
                        for _, c in ipairs(conns) do
                            pcall(function() c:Disable() end)
                        end
                    end
                end
            end
        end)
    end
end)

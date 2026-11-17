# BubblyAI.ps1 -- the companion of Bubbly: the zoi answers your private messages in her own words, by a LOCAL AI (Ollama), no internet.
# 2026-11-07: the zoi lives in its world: the prompts no longer say "in the life-sim game inZOI" (the answers spoke of "the game").
# Run: double click BubblyAI.cmd (keep the window open while you play). Needs Ollama (ollama.com) and the model below (ollama pull <model>).
# It can lie anywhere: it finds the folder of the Bubbly mod itself (Documents\inZOI\Mods\...\BubblySocialMedia_7AD5176A, the installed mod or the
# ModKit preview), reads the chat from ai\req.cfg there and writes the answer to ai\res.cfg. Without it Bubbly answers with the game's own lines.

$Model  = 'llama3.2:3b-instruct-q5_K_M'      # another model: change this line (llama3.2:3b, qwen2.5:7b ...)
$Ctx    = 3072                               # 2026-11-12: the context of every request (the longest one, a private chat, is about 2000 tokens); one value for all, or Ollama reloads the model
$NumGpu = 0                                  # 2026-11-12 (the user: the game froze and fell while the model was on the same video card): 0 = the model runs on the CPU, the video card is left to the game (slower answers); 99 = all on the video card
$Ollama = 'http://localhost:11434/api/chat'
$ModId  = 'BubblySocialMedia_7AD5176A'
$Utf8 = New-Object System.Text.UTF8Encoding $false
# 2026-11-12 (the user: Bubbly said "Bubbly AI is off" again and again): a click inside this window starts the text selection of Windows (QuickEdit), and
# the script stands still until Esc. QuickEdit is turned off for this window (0x40 off, 0x80 = the extended flags on); no change if Windows refuses
try {
    Add-Type -Namespace BubblyAI -Name Con -MemberDefinition '[DllImport("kernel32.dll")] public static extern System.IntPtr GetStdHandle(int h); [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(System.IntPtr h, out uint m); [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(System.IntPtr h, uint m);'
    $ch = [BubblyAI.Con]::GetStdHandle(-10); $cm = [uint32]0
    if ([BubblyAI.Con]::GetConsoleMode($ch, [ref]$cm)) { [void][BubblyAI.Con]::SetConsoleMode($ch, [uint32](([int64]$cm -band 4294967231) -bor 128)) }
} catch { }
# 2026-11-09 (the user): what the game says of the zoi's life (Bubbly field "life": low needs, job, life goal, ambition, values, Hopes, hobbies, skills,
# memories, the city calendar), added to the instructions; the AI uses it only where it fits
function Life-Text($q) { if ($q.life) { return " What you know about your own life (use it only where it fits, never list it): $([string]$q.life). Your wishes are only wishes: say them as 'I want to' / 'I wanna', never as if you already did, got or bought them. If YOUR STRONG FEELING is given, it overrides everything else: speak from inside that feeling." } return '' }

# every folder of the mod under the game's Mods folder (depth <= 3: Mods\<id>, Mods\InGame\<id>, Mods\ModKitPreview\<id>, Mods\<author>\<id>)
function Find-ModDirs {
    $roots = @()
    try { $roots += (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'inZOI\Mods') } catch {}
    if ($env:USERPROFILE) { $roots += (Join-Path $env:USERPROFILE 'Documents\inZOI\Mods') }
    $here = if ($PSScriptRoot) { $PSScriptRoot } else { $env:BUBBLY_DIR }
    if ($here -and (Split-Path $here -Leaf) -eq $ModId) { $roots += (Split-Path $here -Parent) }
    $found = @()
    foreach ($r in ($roots | Select-Object -Unique)) {
        if (-not (Test-Path $r)) { continue }
        $found += @(Get-ChildItem -Path $r -Directory -Filter $ModId -Recurse -Depth 2 -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
    }
    return @($found | Select-Object -Unique)
}
# the folder the game uses now: the one where Bubbly saved last (its ui\Bubbly\saved or ai\req.cfg is the newest)
function Pick-ModDir($dirs) {
    $best = $null; $bt = [datetime]::MinValue
    foreach ($d in $dirs) {
        $t = [datetime]::MinValue
        foreach ($p in @((Join-Path $d 'ai\req.cfg'), (Join-Path $d 'out\dm.cfg'))) { if (Test-Path $p) { $x = (Get-Item $p).LastWriteTime; if ($x -gt $t) { $t = $x } } }
        $sv = Join-Path $d 'ui\Bubbly\saved'
        if (Test-Path $sv) { $x = (Get-ChildItem $sv -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1); if ($x -and $x.LastWriteTime -gt $t) { $t = $x.LastWriteTime } }
        if ($t -gt $bt -or -not $best) { $best = $d; $bt = $t }
    }
    return $best
}
$Dirs = Find-ModDirs
if ($Dirs.Count -eq 0) { Write-Host "Bubbly is not found in Documents\inZOI\Mods. Install the mod, start the game once, then run this again." -ForegroundColor Yellow; Read-Host 'Press Enter to close'; exit }
function Use-Dir($d) {
    $script:Dir = Join-Path $d 'ai'; $script:Req = Join-Path $script:Dir 'req.cfg'; $script:Res = Join-Path $script:Dir 'res.cfg'; $script:Alive = Join-Path $script:Dir 'alive.cfg'
    $script:ToneReq = Join-Path $script:Dir 'tone.cfg'; $script:ToneRes = Join-Path $script:Dir 'toneres.cfg'   # 2026-11-12: the tone of a text, its own slot
    if (-not (Test-Path $script:Dir)) { New-Item -ItemType Directory -Path $script:Dir | Out-Null }
}
$ModDir = Pick-ModDir $Dirs; Use-Dir $ModDir
Write-Host "Bubbly folder: $ModDir" -ForegroundColor Gray

function Read-Req {
    if (-not (Test-Path $Req)) { return $null }
    try { return ([System.IO.File]::ReadAllText($Req, $Utf8) | ConvertFrom-Json) } catch { return $null }
}
function Read-Tone {
    if (-not (Test-Path $ToneReq)) { return $null }
    try { return ([System.IO.File]::ReadAllText($ToneReq, $Utf8) | ConvertFrom-Json) } catch { return $null }
}
# 2026-11-12 (the user: "I cheated, babe" is not a warm text; "and what if a text is unclear and a bad one goes by accident?"): HOW THE ZOI TAKES THE
# PLAYER'S TEXT, for the points of the game: good / neutral / bad. Bad ONLY when it clearly hurts; anything unclear, a joke, teasing or sarcasm is neutral.
# Its own slot (ai\tone.cfg -> ai\toneres.cfg), so it never takes the place of an answer or a thought waiting in ai\req.cfg.
function Do-Tone($t) {
    $sys = "You judge how $($t.me) feels reading a text message from $($t.them). Their relationship: $(Rel-Text $t.rel). " +
           "Answer with ONE word only: good, neutral or bad. " +
           "bad ONLY when the message clearly hurts $($t.me): confessing cheating or lying, an insult, breaking up, saying they do not love them, cruelty or a threat. " +
           "good when it is affectionate, kind, caring, a compliment, a sweet apology or a nice plan together. " +
           "Anything unclear or mixed, a joke, teasing, sarcasm, small talk or a plain question is neutral."
    $usr = ''
    foreach ($h in @($t.history)) { if ($h -and $h.text) { $usr += "$(if ($h.from -eq 'me') { $t.me } else { $t.them }): $([string]$h.text)`n" } }
    $usr += "The new message from $($t.them): $([string]$t.text)`nYour one word:"
    $body = @{ model = $Model; messages = @(@{ role = 'system'; content = $sys }, @{ role = 'user'; content = $usr }); stream = $false; keep_alive = '60m'; options = @{ num_ctx = $Ctx; num_gpu = $NumGpu; temperature = 0; num_predict = 4 } } | ConvertTo-Json -Depth 6
    $tone = 'mid'
    try {
        $a = Invoke-RestMethod -Uri $Ollama -Method Post -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 60
        $w = ([string]$a.message.content).ToLower()
        if ($w -match '\bbad\b') { $tone = 'neg' } elseif ($w -match '\bgood\b') { $tone = 'pos' }
    } catch { Write-Host "Ollama did not answer (tone): $($_.Exception.Message)" -ForegroundColor Yellow }
    [System.IO.File]::WriteAllText($ToneRes, (@{ id = $t.id; tone = $tone } | ConvertTo-Json -Compress), $Utf8)
    Write-Host "tone of '$([string]$t.text)': $tone" -ForegroundColor DarkGray
}

function Rel-Text($rel) {
    if (-not $rel) { return 'acquaintances' }
    $p = @()
    if ($rel.ro -ne $null -and [double]$rel.ro -gt 0)  { $p += "romance $([int]$rel.ro)/100" }
    if ($rel.fr -ne $null -and [double]$rel.fr -ne 0) { $p += "friendship $([int]$rel.fr)/100" }
    if ($rel.fam -ne $null -and [double]$rel.fam -gt 0) { $p += "family $([int]$rel.fam)/100" }
    if ($p.Count -eq 0) { return 'acquaintances' }
    return ($p -join ', ')
}
# 2026-11-11 (the user: "the chat got dry, it is fine for thoughts but not for lovers"): HOW WARM THE TEXT IS, by the relationship the game gives
function Rel-Tone($rel, $who) {
    $ro = if ($rel -and $rel.ro -ne $null) { [double]$rel.ro } else { 0 }
    $fr = if ($rel -and $rel.fr -ne $null) { [double]$rel.fr } else { 0 }
    $fa = if ($rel -and $rel.fam -ne $null) { [double]$rel.fam } else { 0 }
    # 2026-11-12 (the user: a True Love couple, and Suggest wrote "let's not jump to conclusions" / "we can't rush into anything"): the bond is a FACT that
    # outweighs the traits and the earlier lines of the chat; the traits change only the manner (a careful zoi loves carefully, never backs off)
    $stage = if ($rel -and ([string]$rel.roId) -match '(\d+)') { [int]$Matches[1] } else { 0 }
    if ($ro -ge 60 -or $stage -ge 6) { return "FACT that outweighs everything else: you and $($who) are a couple deeply in love (True Love). Text like a lover. Be tender, affectionate and a bit playful or flirty; show your feelings openly, miss them, tease them, use a sweet pet name now and then (babe, love, sweetheart). Never slow things down, never say not to rush or not to jump to conclusions, never doubt or question the relationship, never be cold, even if an earlier message of the chat did. Your traits only change HOW you show your love (a careful person says it softly), never whether you do." }
    if ($ro -gt 20) { return "You have a crush on $($who) and it shows: flirty, warm, a little shy or teasing, curious about them." }
    if ($ro -lt -20 -or $fr -lt -20 -or $fa -lt -20) { return "You do not get along with $($who) right now: short, cool, a bit annoyed, but not insulting." }   # 2026-11-12: + a bad family value
    if ($fa -gt 20) { return "$($who) is family to you: warm, caring, familiar, a bit teasing like family is." }
    if ($fr -ge 50) { return "$($who) is a close friend: warm, relaxed, joking, caring, like best friends text." }
    if ($fr -gt 10) { return "$($who) is a friend: friendly and easygoing." }
    return "You do not know $($who) well yet: friendly but a little reserved."
}
# 2026-11-11 (the user: "phrases go on after quotes, as if cut off"): the model writes a scene sometimes ("I missed you." she smiled / *hugs*) and stops at its
# length limit in the middle of a sentence: only the spoken words stay, and a text cut by the limit ends at its last whole sentence
function Text-Tidy([string]$t, [bool]$cut) {
    $s = ($t -replace '[\u201c\u201d\u201e]', '"' -replace '\*[^*]*\*', ' ' -replace '\s+', ' ').Trim()
    if ($s.StartsWith('"')) { $qs = @([regex]::Matches($s, '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value.Trim() }); if ($qs.Count -gt 0) { $s = $qs -join ' ' } }
    if ((([regex]::Matches($s, '"')).Count % 2) -eq 1) { $s = $s -replace '"', '' }
    $s = ($s -replace '\s+([,.!?])', '$1' -replace '\s+', ' ').Trim()
    if ($cut -and $s -notmatch '[.!?\u2026]["'')]?$') {
        $m = [regex]::Matches($s, '[.!?\u2026]["'')]?(?=\s|$)')
        if ($m.Count -gt 0) { $l = $m[$m.Count - 1]; $s = $s.Substring(0, $l.Index + $l.Length) } else { $s = ($s -replace '\s+\S*$', '' -replace '[\s,;:\-]+$', '') + [char]0x2026 }
    } elseif ($s -and $s -notmatch '[.!?\u2026]["'')]?$') { $s = ($s -replace '[\s,;:\-]+$', '') + '.' }   # 2026-11-12 (the user: "...so worth the" in the window): a WHOLE text without its last mark gets a dot, so Bubbly does not take it for a cut one
    return $s
}

# the model asked for not downloaded (Ollama answers 404): the first model Ollama has is taken, and the list is shown
try {
    $tags = Invoke-RestMethod -Uri 'http://localhost:11434/api/tags' -TimeoutSec 10
    $names = @($tags.models | ForEach-Object { $_.name })
    if ($names.Count -eq 0) { Write-Host "Ollama has no model yet. Run in a command window: ollama pull $Model" -ForegroundColor Yellow }
    elseif (-not ($names | Where-Object { $_ -eq $Model -or $_ -eq ($Model + ':latest') })) {
        Write-Host "Model $Model is not downloaded. Ollama has: $($names -join ', ')" -ForegroundColor Yellow
        $Model = $names[0]
        Write-Host "Using $Model" -ForegroundColor Yellow
    }
} catch { Write-Host "Ollama is not running (start the Ollama app): $($_.Exception.Message)" -ForegroundColor Yellow }

# the model is loaded into the video card in the BACKGROUND (keep_alive): the window does not hang on "Loading", the heartbeat starts at once
Write-Host "Loading $Model in the background (can take a minute while the game is running) ..." -ForegroundColor Gray
$Warm = Start-Job -ArgumentList $Model, $Ctx, $NumGpu -ScriptBlock { param($m, $Ctx, $NumGpu)   # 2026-11-12: the same context as every request (a job does not see the variables of the script)
    Invoke-RestMethod -Uri 'http://localhost:11434/api/generate' -Method Post -ContentType 'application/json' -Body (@{ model = $m; prompt = 'hi'; stream = $false; keep_alive = '60m'; options = @{ num_ctx = $Ctx; num_gpu = $NumGpu; num_predict = 1 } } | ConvertTo-Json) -TimeoutSec 600 | Out-Null }

$last = $null
$r0 = Read-Req; if ($r0) { $last = $r0.id }      # an old request is never answered again
$lastTone = $null; $t0 = Read-Tone; if ($t0) { $lastTone = $t0.id }
Write-Host "Bubbly AI is on (model $Model). Keep this window open while you play." -ForegroundColor Cyan

# 2026-11-12 (the user: "Bubbly AI is off" while it was writing a long answer): THE HEARTBEAT IN ITS OWN THREAD. The loop below waits for Ollama
# (up to 150 s) and wrote nothing meanwhile, so Bubbly (20 s without a beat = off) took the companion for gone. Now a second thread writes ai\alive.cfg
# every 3 s into every folder of the mod, whatever the loop is doing; the loop only gives it the list of folders. Without the thread: the old beat below.
$HeartDirs = [hashtable]::Synchronized(@{ Dirs = @($Dirs) })
$BeatPs = $null
try {
    $BeatPs = [powershell]::Create()
    [void]$BeatPs.AddScript({ param($s)
        $u = New-Object System.Text.UTF8Encoding $false
        while ($true) {
            $ms = [string][DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            foreach ($d in @($s.Dirs)) { try { $ad = Join-Path $d 'ai'; if (-not (Test-Path $ad)) { New-Item -ItemType Directory -Path $ad | Out-Null }; [System.IO.File]::WriteAllText((Join-Path $ad 'alive.cfg'), $ms, $u) } catch { } }
            Start-Sleep -Seconds 3
        }
    }).AddArgument($HeartDirs)
    $BeatRun = $BeatPs.BeginInvoke()
} catch { $BeatPs = $null }

$beat = 0
while ($true) {
    Start-Sleep -Milliseconds 500
    if (($beat % 20) -eq 0) {                       # every 10 s: the game may have switched between the installed mod and the preview
        $Dirs = Find-ModDirs; $nd = Pick-ModDir $Dirs
        $HeartDirs.Dirs = @($Dirs)                         # the heartbeat thread writes into the folders found now
        # 2026-11-12 (the user: Suggest "Thinking..." for ever): a request written just before the switch was taken for an old one and never answered;
        # now only a request older than 30 s is left alone when the folder changes
        if ($nd -and $nd -ne $ModDir) {
            $ModDir = $nd; Use-Dir $ModDir
            $fresh = { param($f) (Test-Path $f) -and (((Get-Date) - (Get-Item $f).LastWriteTime).TotalSeconds -lt 30) }
            $r1 = Read-Req; if ($r1 -and -not (& $fresh $Req)) { $last = $r1.id }
            $t1 = Read-Tone; if ($t1 -and -not (& $fresh $ToneReq)) { $lastTone = $t1.id }
            Write-Host "Bubbly folder: $ModDir" -ForegroundColor Gray
        }
    }
    if ($Warm -and $Warm.State -ne 'Running') {
        if ($Warm.State -eq 'Completed') { Write-Host "$Model is loaded." -ForegroundColor Cyan } else { Write-Host "Loading failed: $(($Warm.ChildJobs[0].JobStateInfo.Reason).Message)" -ForegroundColor Yellow }
        Remove-Job $Warm -Force; $Warm = $null
    }
    if ((++$beat % 6) -eq 1 -and -not $BeatPs) {   # Bubbly sees the companion is on (in every folder of the mod); only when the heartbeat thread could not start
        $ms = [string][DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
        foreach ($d in $Dirs) { try { $ad = Join-Path $d 'ai'; if (-not (Test-Path $ad)) { New-Item -ItemType Directory -Path $ad | Out-Null }; [System.IO.File]::WriteAllText((Join-Path $ad 'alive.cfg'), $ms, $Utf8) } catch {} }
    }
    $tq = Read-Tone
    if ($tq -and $tq.id -and $tq.id -ne $lastTone) { $lastTone = $tq.id; Do-Tone $tq }
    $q = Read-Req
    if (-not $q -or -not $q.id -or $q.id -eq $last) { continue }
    $last = $q.id

    # 2026-11-05: THE TEXT OF A NEW POST (Bubbly's "Suggest" in New post). A rumor heard: only the zoi's reaction (Bubbly puts the game's words of the rumor
    # after it in quotes). Else: the post in the zoi's words, the facts are only those Bubbly sends.
    if ($q.kind -eq 'post') {
        $traits = if ($q.traits) { ($q.traits -join ', ') } else { 'unknown' }
        $emo    = if ($q.emotion) { $q.emotion } else { 'Normal' }
        $doing  = if ($q.action) { [string]$q.action } else { 'nothing in particular' }
        $when   = if ([int]$q.hour -ge 0) { "$($q.day), $([int]$q.hour):00" } else { [string]$q.day }
        $base = "You are $($q.me), a real person living your everyday life in your city, writing on the social app Bubbly. Your personality traits: $traits. Your mood right now: $emo." + (Life-Text $q) + " " +
                "Casual English, true to your traits and mood. Do not invent people, places or events. Never say you are an AI, no hashtags, no emoji, no quotes, no name prefix. This is your real life: never mention games, players or inZOI. The people of your city are called Zois: you may say Zois (never randoms)."
        if ($q.rumor) {
            $sys = $base + " Write ONLY your short reaction (at most 15 words) to a rumor you heard; the rumor itself will be added after your words, so do not repeat it."
            $who = if ($q.about) { " It is about $($q.about)." } else { '' }
            $usr = "The rumor: $($q.rumor).$who Its tone: $($q.tone)."
        } elseif ($q.ad) {
            # 2026-11-09 (the user): AN AD of the zoi's business (Business Ad / Market Stall / Pocket Market): the tone of an ad, not a story about the day
            # 2026-11-08: Pocket Market = the look of the zoi's outfit trend (10 fans), not a store
            $what = switch ([string]$q.ad) { 'stall' { 'your own market stall, where you are selling your things right now' } 'pocket' { 'your own trending outfit, now listed on Pocket Market' } default { "your business $($q.bizName)" } }
            $sys = "You are $($q.me), the owner, writing an ad on the social app Bubbly. Write ONE short ad (at most 25 words) for $what. " +
                   "Tone of a friendly, catchy ad: invite people to come or buy, end with a call to action. Do not tell about your day or what you are doing. " +
                   "Do not invent prices, discounts, products, opening hours or places. Never say you are an AI, no hashtags, no emoji, no quotes, no name prefix. Never mention games, players or inZOI."
            $usr = "The ad is for: $what."
            if ($q.bizType) { $usr += " Kind of business: $($q.bizType)." }
            if ($q.sell) { $usr += " On sale: $($q.sell)." }
            if ($q.situation) { $usr += " Keep this fact: $($q.situation)" }
        } elseif ($q.place) {
            # 2026-11-07 (the user): A SCOUT POST is about the place the zoi just visited and photographed, nothing else (not what the zoi does now)
            $sys = $base + " Write ONE short post (at most 25 words), first person, about a place you just visited and photographed. Write only about this place: what it is like and how it felt to be there, the way your traits would see it. Do not write about anything else you are doing."
            $usr = "The place: $($q.place) ($($q.placeKind))."
            if ($q.placeDesc) { $usr += " What the place is: $($q.placeDesc)" }
            $usr += " Time: $when."
        } else {
            $sys = $base + " Write ONE short post (at most 25 words), first person."
            $usr = "Kind of post: $($q.postKind)."
            if ($q.tag) { $usr += " Life update: $($q.tag)." }
            if ($q.situation) { $usr += " What happened (keep this fact): $($q.situation)" }
            if ($q.about) { $usr += " The post is about $($q.about)." }
            $usr += " What you are doing now: $doing. Time: $when."
        }
        $body = @{ model = $Model; messages = @(@{ role = 'system'; content = $sys }, @{ role = 'user'; content = $usr }); stream = $false; keep_alive = '60m'; options = @{ num_ctx = $Ctx; num_gpu = $NumGpu; temperature = 0.7; num_predict = 70 } } | ConvertTo-Json -Depth 6
        try {
            $a = Invoke-RestMethod -Uri $Ollama -Method Post -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 150
            $reply = ([string]$a.message.content).Trim() -replace '^\s*"+|"+\s*$', ''
            [System.IO.File]::WriteAllText($Res, (@{ id = $q.id; reply = $reply } | ConvertTo-Json -Compress), $Utf8)
            Write-Host "$($q.me) posts: $reply" -ForegroundColor Magenta
        } catch { Write-Host "Ollama did not answer: $($_.Exception.Message)" -ForegroundColor Yellow }
        continue
    }

    # 2026-11-05: A THOUGHT of the zoi (Bubbly's "Suggest" in "What's on your mind?"): only what the game says of the zoi now
    # 2026-11-07: A COMMENT of the played zoi under a post (Bubbly's "Suggest" in the comments): its traits, mood, its relationship with the author, the kind chosen
    # (like = kind, dislike = mean but never hateful, own = thanks under its own post) and the post itself (a Scout post: the place)
    if ($q.kind -eq 'comment') {
        $traits = if ($q.traits) { ($q.traits -join ', ') } else { 'unknown' }
        $emo    = if ($q.emotion) { $q.emotion } else { 'Normal' }
        $tone   = switch ([string]$q.tone) { 'dislike' { 'You do not like this post: write a mean, sarcastic comment, but no insults, no swearing and nothing hateful.' } 'own' { 'It is your own post: thank the people who commented.' } default { 'You like this post: write a kind, warm comment.' } }
        $sys = "You are $($q.me), a real person living your everyday life in your city, commenting on the social app Bubbly. Your personality traits: $traits. Your mood right now: $emo. " +
               "Write ONE short comment (at most 15 words), casual English, true to your traits. $tone Do not invent people, places or events. " +
               "Never say you are an AI, no hashtags, no emoji, no quotes, no name prefix. This is your real life: never mention games, players or inZOI. The people of your city are called Zois: you may say Zois (never randoms)."
        $sys += (Life-Text $q)
        $usr = "The post of $($q.author) (your relationship: $(Rel-Text $q.rel)): $($q.post)"
        if ($q.place) { $usr += " It is about a place: $($q.place) ($($q.placeKind))." ; if ($q.placeDesc) { $usr += " What the place is: $($q.placeDesc)" } }
        $body = @{ model = $Model; messages = @(@{ role = 'system'; content = $sys }, @{ role = 'user'; content = $usr }); stream = $false; keep_alive = '60m'; options = @{ num_ctx = $Ctx; num_gpu = $NumGpu; temperature = 0.7; num_predict = 45 } } | ConvertTo-Json -Depth 6
        try {
            $a = Invoke-RestMethod -Uri $Ollama -Method Post -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 150
            $reply = ([string]$a.message.content).Trim() -replace '^\s*"+|"+\s*$', ''
            [System.IO.File]::WriteAllText($Res, (@{ id = $q.id; reply = $reply } | ConvertTo-Json -Compress), $Utf8)
            Write-Host "$($q.me) comments: $reply" -ForegroundColor Magenta
        } catch { Write-Host "Ollama did not answer: $($_.Exception.Message)" -ForegroundColor Yellow }
        continue
    }

    # 2026-11-14 (the user: the game's phone calls with your own words): A BUBBLY CALL. The played zoi answers a caller in its own words (typed by the player);
    # the model speaks as the CALLER: one short spoken line, then on its own last line "MOOD: good" (the words were warm, kind, interested) or "MOOD: bad"
    # (cold, rude, dismissive). Bubbly runs the game's scripts of that side of the call (relationship up / down).
    if ($q.kind -eq 'call') {
        $sys = "You are $($q.caller), a real person in your city, on the phone with $($q.me) (your relationship: $(Rel-Text $q.rel)). " +
               "You called them and opened with: ""$($q.opening)"". Answer what they just said with ONE short spoken line (at most 25 words), casual English, " +
               "the way you would really talk on the phone to this person. Do not invent other people, places or events. Never say you are an AI, no hashtags, no emoji, no quotes, no name prefix. " +
               "Never mention games, players or inZOI. Then, on its own last line, write MOOD: good if their words were warm, kind or interested, or MOOD: bad if they were cold, rude or dismissive."
        $usr = ''
        if ($q.history) { $usr += "The call so far: " + (($q.history) -join ' / ') + ". " }
        $usr += "$($q.me) says: $($q.said)"
        $body = @{ model = $Model; messages = @(@{ role = 'system'; content = $sys }, @{ role = 'user'; content = $usr }); stream = $false; keep_alive = '60m'; options = @{ num_ctx = $Ctx; num_gpu = $NumGpu; temperature = 0.7; num_predict = 80 } } | ConvertTo-Json -Depth 6
        try {
            $a = Invoke-RestMethod -Uri $Ollama -Method Post -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 150
            $txt = [string]$a.message.content
            $mood = 'good'
            if ($txt -match '(?i)\bMOOD\s*:\s*(good|bad)') { $mood = $Matches[1].ToLower() }
            $reply = ($txt -replace '(?i)\bMOOD\s*:\s*\w+', '').Trim() -replace '^\s*"+|"+\s*$', ''
            [System.IO.File]::WriteAllText($Res, (@{ id = $q.id; reply = $reply; mood = $mood } | ConvertTo-Json -Compress), $Utf8)
            Write-Host "$($q.caller) on the phone ($mood): $reply" -ForegroundColor Magenta
        } catch { Write-Host "Ollama did not answer: $($_.Exception.Message)" -ForegroundColor Yellow }
        continue
    }

    if ($q.kind -eq 'thought') {
        $traits = if ($q.traits) { ($q.traits -join ', ') } else { 'unknown' }
        $emo    = if ($q.emotion) { $q.emotion } else { 'Normal' }
        $when   = if ([int]$q.hour -ge 0) { "$($q.day), $([int]$q.hour):00" } else { [string]$q.day }
        $doing  = if ($q.action) { [string]$q.action } else { 'nothing in particular' }
        $sys = "You are $($q.me), a real person living your everyday life in your city. Write ONE short inner thought of yours, as a status on a social app: " +
               "first person, ONE or TWO short sentences, at most 25 words, casual English, true to your traits and mood; no long chains of commas. Do not invent people, places or events. " +
               "Never say you are an AI, no hashtags, no quotes, no name prefix. This is your real life: never mention games, players or inZOI. The people of your city are called Zois: you may say Zois (never randoms)."
        # 2026-11-09 (the user: "the zoi feels much more, here only the heat and the ocean breeze"): every thought is about ONE thing, picked at random from
        # the zoi's life (a low need, the job, the life goal, the ambition, a value, a Hope, a hobby, a skill, a memory, the city calendar) or from what it does
        # and feels now; the weather and the time are only the background
        # 2026-11-12 (the user: thoughts were dry and technical, "level up Charm", "comfort zone"): THE MOMENT FIRST. Most thoughts are about what the zoi does,
        # feels and who it is with right now; about one in three is about its life (a wish, a dream, a memory, a value, a person), never about what it is good at
        $life = @(); if ($q.life) { $life = @(([string]$q.life) -split '\.\s+' | Where-Object { $_ -and $_.Trim() -and $_ -notmatch '^\s*(WHO YOU ARE|YOUR STRONG FEELING|you are (very )?good at|hobbies you dislike|you have no job|you are an? (wo)?man|you go by|you are romantically|you are not interested in romance)' }) }
        $now = @('what you are doing right now', 'YOUR STRONGEST FEELING right now and where it comes from (the weaker feeling at most as a short side note)')   # 2026-11-12: one feeling, not all of them
        if ($doing -match 'next to you: ([^;]+)') { $now += "being with $($Matches[1].Trim()) right now" }
        $focus = if ($life.Count -gt 0 -and (Get-Random -Maximum 10) -lt 3) { $life | Get-Random } else { $now | Get-Random }
        if ($doing -match 'ASLEEP') { $focus = 'you are asleep: a sleepy, dreamy thought (a dream, or half-awake)' }   # 2026-11-09: a sleeping zoi dreams
        # 2026-11-09 (the user): a strong emotion (5+, above all 10+) covers everything: the thought is that feeling and what caused it
        if ([string]$q.life -match 'YOUR STRONG FEELING') { $focus = if ($doing -match 'ASLEEP') { 'you are asleep: a dream about your strong feeling' } else { 'YOUR STRONG FEELING right now and what caused it (see how you feel and why)' } }
        $sys += " Think about ONE thing only, the focus given to you. The weather, the temperature and the time are only the background: do not mention them unless the focus is about them."
        # 2026-11-12 (the user: "Lucia's nagging me about lunch" of a True Love; "sitting" when standing; "in my apartment" elsewhere): only what is given
        $sys += " Never invent what other people said or did: the people next to you are only there. Think of each person next to you the way your relationship with them is given in brackets: with love when you love them, coolly or with tension when you do not get along, never warmer or colder than that. " +
                "Do not say where you are unless it is given, and never call it your home or apartment unless it says so. Do not say you are sitting, standing or lying unless what you are doing says it. " +
                "Your wishes and what you are good at are not plans: never plan schemes or crimes, and never use game words (need, stat, skill, level, percent, comfort zone). Sound like a real person with feelings, not like a report."
        $usr = "Your personality traits: $traits. Your mood right now: $emo. What you are doing and feeling: $doing. Time: $when."
        $sys += (Life-Text $q)
        $usr += " FOCUS of this thought: $focus."
        # 2026-11-14 (the user: suggestions through Bubbly's own AI): Bubbly sends what the zoi could really do now (numbered); the model picks the ONE that
        # fits the thought, on its own last line "DO: <number>" (0 = none); Bubbly shows it as a button under the thought. Never an action that is not listed.
        $np = 60
        if ($q.acts -and @($q.acts).Count -gt 0) {
            $sys += " After the thought, on a NEW last line, write DO: and the number of the ONE thing from the list that you feel like doing next, the one that fits your thought and how you feel (DO: 0 if none fits). Only a number from the list."
            $usr += " Things you could do right now: $((@($q.acts)) -join '; ')."
            $np = 75
        }
        $body = @{ model = $Model; messages = @(@{ role = 'system'; content = $sys }, @{ role = 'user'; content = $usr }); stream = $false; keep_alive = '60m'; options = @{ num_ctx = $Ctx; num_gpu = $NumGpu; temperature = 0.7; num_predict = $np } } | ConvertTo-Json -Depth 6
        try {
            $a = Invoke-RestMethod -Uri $Ollama -Method Post -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 150
            $reply = ([string]$a.message.content).Trim()
            $act = 0
            # 2026-11-14 (the user's screenshot: "...isn't so bad DO: 1."): the model may put the choice at the end of the sentence, not on its own line
            if ($reply -match '(?i)\bDO\s*:\s*(\d+)') { $act = [int]$Matches[1]; $reply = ($reply -replace '(?i)[\s\*\(\[]*\bDO\s*:\s*\d+[^\r\n]*', '').Trim(); if ($reply -and $reply -notmatch '[.!?"'')]$') { $reply += '.' } }
            if ($q.acts -and ($act -lt 0 -or $act -gt @($q.acts).Count)) { $act = 0 }
            $reply = $reply -replace '^\s*"+|"+\s*$', ''
            $reply = Text-Tidy $reply ([string]$a.done_reason -eq 'length')   # 2026-11-12 (the user: thoughts ended "under the weight of all"): a thought cut by the limit ends at its last whole sentence, as a message
            [System.IO.File]::WriteAllText($Res, (@{ id = $q.id; reply = $reply; act = $act } | ConvertTo-Json -Compress), $Utf8)
            Write-Host "$($q.me) thinks: $reply" -ForegroundColor Magenta
            if ($act -gt 0) { Write-Host "  wants to: $(@($q.acts)[$act - 1])" -ForegroundColor DarkMagenta }
        } catch { Write-Host "Ollama did not answer: $($_.Exception.Message)" -ForegroundColor Yellow }
        continue
    }

    $traits = if ($q.traits) { ($q.traits -join ', ') } else { 'unknown' }
    $emo    = if ($q.emotion) { $q.emotion } else { 'Normal' }
    $who = if ($q.mePron) { "$($q.me) ($($q.mePron))" } else { [string]$q.me }   # 2026-11-12: the pronouns the game gives (no guess by the name)
    $sys = "You are $($q.them), a real person living your everyday life in your city. You are texting with $who on your phone. " +
           "Your relationship with $($q.me): $(Rel-Text $q.rel). Your personality traits: $traits. Your mood right now: $emo. " +
           "Reply as $($q.them) in a casual text message: one to three short sentences, natural, in English, true to your mood and to how close you are. " +
           "$(Rel-Tone $q.rel $q.me) " +
           "Answer what was actually said, react to it with feeling and keep the conversation going (a question back, a wish, a memory, a plan). " +
           "Write only the words of your text message: never describe actions or gestures, no asterisks, no quotes, no name prefix. Never say you are an AI. This is your real life: never mention games, players or inZOI. The people of your city are called Zois: you may say Zois (never randoms)."

    $sys += (Life-Text $q)
    $msgs = @(@{ role = 'system'; content = $sys })
    foreach ($h in $q.history) {
        if (-not $h.text) { continue }
        $msgs += @{ role = $(if ($h.from -eq 'me') { 'user' } else { 'assistant' }); content = [string]$h.text }
    }
    if (-not $q.history -or ($q.history[-1].text -ne $q.text)) { $msgs += @{ role = 'user'; content = [string]$q.text } }

    $body = @{ model = $Model; messages = $msgs; stream = $false; keep_alive = '60m'; options = @{ num_ctx = $Ctx; num_gpu = $NumGpu; temperature = 0.7; num_predict = 90 } } | ConvertTo-Json -Depth 6
    try {
        $a = Invoke-RestMethod -Uri $Ollama -Method Post -ContentType 'application/json; charset=utf-8' -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 150
        $reply = ([string]$a.message.content).Trim()
        $reply = $reply -replace ('^\s*' + [regex]::Escape([string]$q.them) + '\s*:\s*'), ''
        $reply = Text-Tidy $reply ([string]$a.done_reason -eq 'length')   # 2026-11-11: only the spoken words, never cut in the middle
        $out = @{ id = $q.id; reply = $reply } | ConvertTo-Json -Compress
        [System.IO.File]::WriteAllText($Res, $out, $Utf8)
        Write-Host "$($q.me): $($q.text)" -ForegroundColor Gray
        Write-Host "$($q.them): $reply" -ForegroundColor Green
    } catch {
        Write-Host "Ollama did not answer: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

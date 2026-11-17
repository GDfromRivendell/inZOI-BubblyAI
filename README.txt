BUBBLY AI 1.0 - a free add-on for the Bubbly mod
================================================

With Bubbly AI, zois answer your private messages in Bubbly in their own words.
The Suggest button writes posts, comments, thoughts and DM replies for your zoi.
The AI runs on your own PC (Ollama). It needs no account, and once the model
is downloaded it works offline.

Without Bubbly AI, Bubbly works as usual: zois answer DMs with the game's own
lines, and Suggest tells you that Bubbly AI is off.

NEEDS
- The Bubbly mod, installed and enabled.
- Windows 10 or 11.
- Ollama (free): https://ollama.com
- About 2.3 GB of disk space for the model. A graphics card makes answers faster.

SETUP (once)
1. Install Bubbly from the Mods menu of inZOI and start the game once with it.
2. Unzip this archive into any folder you like (for example your Desktop).
   Bubbly AI finds Bubbly by itself: there is no path to set.
   If Windows warns about the downloaded file, choose "Run" (or, before
   unzipping: right-click the zip > Properties > tick "Unblock" > OK).
3. Install Ollama from https://ollama.com and start it.
4. Download the model Bubbly AI uses by default, llama3.2:3b-instruct-q5_K_M (it is set
   in BubblyAI.ps1 by the line  $Model  = 'llama3.2:3b-instruct-q5_K_M'). Open Command Prompt
   (Win+R, type cmd, press Enter) and run:
       ollama pull llama3.2:3b-instruct-q5_K_M
   Wait until the download finishes.

EVERY TIME YOU PLAY
1. Make sure Ollama is running (its icon is in the system tray).
2. Double-click BubblyAI.cmd in the folder where you unzipped Bubbly AI.
3. Keep the "Bubbly AI" window open while you play. It finds Bubbly by itself.
   When it is on, a light blue ring glows around the zoi's picture next to
   the name, and the Suggest buttons turn blue.

To turn it off, close the Bubbly AI window.

LESS VIDEO MEMORY (optional)
Ollama can keep the model's memory smaller with no change to the answers.
Open Command Prompt and run these two lines once:
    setx OLLAMA_FLASH_ATTENTION 1
    setx OLLAMA_KV_CACHE_TYPE q8_0
Then quit Ollama from the system tray and start it again.
(Bubbly AI already asks Ollama for a small context, 3072 tokens.)

VIDEO CARD OR PROCESSOR
By default the model runs on the processor (CPU), so the game keeps the video
card for itself: answers take a few seconds longer, the game does not stutter.
With a strong video card you can put the model on it: in BubblyAI.ps1 change
    $NumGpu = 0
to
    $NumGpu = 99

ANOTHER MODEL
Open BubblyAI.ps1 in Notepad and change the line
    $Model  = 'llama3.2:3b-instruct-q5_K_M'
for example to 'qwen2.5:7b' (better, slower) or 'qwen2.5:1.5b' (faster).
Download it first with:  ollama pull <model name>
If the model in that line is not downloaded, Bubbly AI uses the first model
that Ollama has.

IF SOMETHING IS WRONG
- "Bubbly is not found": install and enable Bubbly, start the game once, then
  run BubblyAI.cmd again.
- "Ollama is not running": start the Ollama app, then run BubblyAI.cmd again.
- "Ollama has no model yet": run  ollama pull llama3.2:3b-instruct-q5_K_M
- Answers are slow at first: the model is loading into memory (up to a minute).

PRIVACY
Everything stays on your PC. Bubbly AI only reads and writes three small files
in Bubbly's own folder (ai\req.cfg, ai\res.cfg, ai\alive.cfg) and talks to
Ollama on this computer (localhost). Nothing is sent to the internet.

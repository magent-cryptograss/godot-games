class_name Story
extends RefCounted
## Every written line in the game.
##
## The premise: songs are the only memory that lasts. Instruments hold them, so
## an abandoned instrument keeps the song and forgets the hands, and turns mean.
## Past a certain point one cannot be mended, only broken.
##
## Nobody is behind it. People die, move away, or set a thing down one evening
## meaning to pick it up on Sunday. The Quiet is all of that, accumulated.

const TITLE := "SONGBOUND"
const SUBTITLE := "what the instruments remember"

const OPENING := [
	"Halloway is three days buried. The shop is yours now, such as it is.",
	"She taught you the rule before she taught you the trade. Paper rots. Stone wears smooth. A song passed hand to hand outlasts them both, and that is the only reason anybody remembers anything at all.",
	"She taught you the second rule too. An instrument that is loved and then set down for good does not die. It keeps the song and forgets the hands, and a thing like that turns mean.",
	"And then the hard one. Past a certain point there is no mending a left thing. The song inside has gone bad and there is no getting it back out. All you can do is break it, and be quick, and not stand about afterwards.",
	"Nobody is doing this to us. People die. People move down the valley. People set a fiddle in the corner one evening meaning to pick it up on Sunday, and then it is nine years later.",
	"It is ordinary. It has been going on for as long as there have been songs. But it all goes somewhere, and lately the somewhere is close enough to hear.",
	"You pack her kit -- rosin, spare strings, the little hammer -- and you go north, toward the humming.",
	"Out the bottom of town, then. The road north runs six hundred paces to the cave and there are five towns on it, so do not try to do it in one go.",
	"(Press C for the menu. WHERE says what you are doing. MAP shows the road.)",
]

const SIGN_TOWN := [
	"INN, west.  SUPPLIES, east.",
	"MENDING, the shop with the green door.",
	"(Somebody has scratched out that last line. Recently.)",
]

const SIGN_SHRINE := [
	"A weathered post.",
	"NORTH: the high crags, and the cave.\nSOUTH: town.\nEAST: nothing good.",
]

const OLDMAN := [
	"Halloway mended my father's fiddle when I was a boy. Mended it twice.",
	"Second time it had gone feral in a barn six years and taken a finger off the man who found it. She had it sweet again by Sunday.",
	"That was the trade, when there was a trade. Mending, where mending was possible.",
	"It is not, any more. What comes out of those hills now is years past helping, and every one of us knows it.",
	"And they will not look like instruments. A left thing takes the shape of the last thing that heard it -- a fiddle rotting in a briar patch comes back briar, a horn left in a field comes back with horns on it.",
	"Break it clean. Do not make it last.",
]

const KID := [
	"I know six songs!",
	"...I knew seven.",
	"I have been looking for the other one all morning. It is not anywhere. It is not even in the place where it was.",
]

const WOMAN := [
	"My grandmother could name an element by the sound it made when it went wrong.",
	"Fire crackles. Water answers back. Plant does not hurry. Ice takes its time on purpose.",
	"Electric, earth, wind, dark. Pick whichever suits your hands. They all hold a song just as well as any other.",
]

const DRIFTER := [
	"Every level you put into an element, that element comes up one. It is the element that counts, mind, not you.",
	"The first time you take one up, a song settles in. Then again at its fifth, its tenth, its fifteenth, on up.",
	"So a body who stays with the one element learns all eight of its songs and plays them like they were born holding it.",
	"And a body who takes a little of everything gets the first song out of all eight and never the rest.",
	"The levels in between only make you harder to knock down. That is not nothing.",
	"Both work. They do not work the same.",
]

const PREACHER := [
	"I keep a list of what we have lost. It is four pages, and you are about to make it longer.",
	"I do not blame you for that. Somebody has to go down there. But every one you put down is a song that stops existing, and I would rather one of us was counting.",
	"Not the songs themselves -- I cannot write down a song, and if I could the paper would rot and take it with it. I write down the holes.",
	"\"A tune about a river.\" \"The counting rhyme with the crow in it.\" \"Whatever my mother sang.\"",
]

const MINER := [
	"Worked that cave nine years. It never hummed before this spring.",
	"Now it hums all night and not one of us can name the key.",
	"There is something down there that used to be an instrument. Several somethings. They are stacked up in order, is the part I cannot stop thinking about.",
]

const SHOPKEEP := [
	"Rosin, strings, and something for your throat.",
	"Halloway bought the same four things off me for forty years and never once said what they were for.",
]

const INNKEEP := [
	"Rest here? Thirty coin and you wake up whole.",
	"Halloway never paid it once. Slept on the bench by the fire like an old dog and left before I was up.",
]

## Dialogue sets addressable by name, so an NPC placed in the map editor can
## point at a speech without the map file carrying a copy of the words.
static func lines_for(key: String) -> Array:
	match key:
		"OLDMAN": return OLDMAN
		"KID": return KID
		"WOMAN": return WOMAN
		"DRIFTER": return DRIFTER
		"PREACHER": return PREACHER
		"MINER": return MINER
		"SHOPKEEP": return SHOPKEEP
		"INNKEEP": return INNKEEP
		"SIGN_TOWN": return SIGN_TOWN
		"SIGN_SHRINE": return SIGN_SHRINE
	return ["..."]

const LINE_KEYS := ["OLDMAN", "KID", "WOMAN", "DRIFTER", "PREACHER", "MINER",
	"SHOPKEEP", "INNKEEP", "SIGN_TOWN", "SIGN_SHRINE"]

## The generated towns each carry their lines inline, so they need no entry here;
## this table is only for NPCs placed by hand in the map editor.

const WELL := ["The water is very still. It does not echo."]
const GRAVE := [
	"HALLOWAY, it says. She cut the letters herself years back and complained about stone the entire time.",
	"Three days, and they are already going faint.",
]
const BED := ["A bed. Not yours."]

const GATE_BELL := "The bell still hangs in the way."
const GATE_CONDUCTOR := "The conductor has not finished."

const BOSS_GRAVEBELL := [
	"A bell hangs in the dark ahead of you, and it has no clapper.",
	"It is ringing anyway. It has been ringing for somebody since before your grandmother was born, and it cannot remember who.",
	"A bell is an instrument. This one was left, and it is far too late for it.",
	"You get the hammer out.",
]

const BOSS_CONDUCTOR := [
	"A tall shape stands with its back to you, keeping time.",
	"There is no band. There has not been a band down here in a hundred years -- they got old, or they moved down the valley, or they simply stopped coming on Thursdays.",
	"It is still counting them in. It has counted them in every bar of every one of those years.",
	"You are the first thing to walk in since. This is going to be the worst one.",
]

const BOSS_QUIET := [
	"There is nothing here.",
	"Not an empty room. A nothing, sitting in a room, with mouths.",
	"Nobody built it. Nobody wanted it. There is no one to blame for this and nothing to take back.",
	"It is only every song anybody ever stopped singing, all of it, in one place at last.",
	"You take a breath. It is the loudest thing in the world.",
]

const VICTORY_LINE := "One more gone for good."
const DEFEAT_LINE := "The song goes out of you."
const REVIVE_LINES := [
	"You come to in town, emptier of pocket.",
	"Somebody hummed you back. They will not say who.",
]

## Kept to about fifty characters a line: the crawl is centre-aligned, so
## anything wider runs off both edges of a 320px screen at once.
const ENDING := [
	"The Quiet comes apart the way a held note does,",
	"thinning out until you cannot say where it stopped.",
	"",
	"What is left on the floor is a reed pipe.",
	"River cane, cut badly. Four holes, and a fifth",
	"started and given up on. Nothing special about it,",
	"except that it is the first one anybody ever made.",
	"",
	"",
	"You broke a great many things to stand here.",
	"Not one of them could have been saved.",
	"You know that, because you checked. Every time.",
	"",
	"",
	"This one is whole.",
	"",
	"Not because it was cared for. Because it was never",
	"once set down. Hand to hand, the whole way,",
	"for as long as there have been hands --",
	"until somebody, finally, set it down.",
	"",
	"",
	"It takes most of an hour. It is not hard work.",
	"Halloway taught you harder in your first winter.",
	"",
	"You put it to your mouth. It plays unasked,",
	"and what it plays is older than any of this.",
	"No words. Nobody alive knows this one.",
	"",
	"So you learn it. Standing there, in the dark,",
	"you learn it, which is the whole of the job.",
	"",
	"",
	"Then you carry it home the long way, over the crag.",
	"You give the pipe to the child who lost a song.",
	"She has it by Sunday, and teaches it onward,",
	"",
	"and it goes on from there, hand to hand,",
	"which is the only way anything has ever lasted,",
	"and the only part of any of this that ever worked.",
	"",
	"",
	"",
	"SONGBOUND",
]


# ---------------------------------------------------------- the other towns --
## Five more towns down the road. Each one has lost the songs in its own way,
## because that is the only thing the premise is about.

const MILLBROOK_SIGN := [
	"MILLBROOK. Grain ground while you wait.",
	"KEEP TO THE RHYTHM OR KEEP OFF THE FLOOR.",
]
const MILLBROOK_A := [
	"You set a wheel turning and you sing to it, or you lose a hand. That is the whole of the theory.",
	"Every job in this town has a song under it and every one of them is a counting song. Nobody wrote them. They just turned up, the way a path turns up where people walk.",
	"We have lost two this spring. The little one for the sluice gate, and whatever it was my father sang at the hopper.",
	"Now we count out loud like children. It works. It is not the same.",
]
const MILLBROOK_B := [
	"The mill wheel has a note. Always had. G, near enough, if the water is up.",
	"Last month it went quiet for a whole afternoon and every one of us came running out of doors without knowing why.",
	"Water was fine. Wheel was fine. It just stopped having the note in it for a while.",
]
const MILLBROOK_C := [
	"You are Halloway's, then. She came through most autumns with that kit.",
	"Mended our grandmother's dulcimer twice, and the second time she sat where you are standing and said, plain as bread, that there would not be a third.",
	"There was not a third. We buried it under the barrow hill with the rest.",
	"That was thirty years ago and something has been getting up there since.",
]
const MILLBROOK_INN := [
	"Bed and a bowl. Sixty coin, and the wheel stops at ten so you will sleep.",
]
const MILLBROOK_SHOP := [
	"Rosin and rope. The rope is not for you.",
	"Mind the barrow road at dusk. Or do not -- you have got the hammer.",
]

const LONGFERRY_SIGN := [
	"LONGFERRY. Crossings at dawn and at dusk.",
	"THE CHAPEL ROAD IS CLOSED. It has been closed nine years.",
]
const LONGFERRY_A := [
	"Six generations of us have poled that flat across, and there is a song for it -- one verse per length of rope, so you know when to lean.",
	"My boy will not learn it. Says he will remember the leaning without the words.",
	"He will not. That is not how any of it works. The words are the only part that keeps.",
]
const LONGFERRY_B := [
	"You can hear the chapel from the water on a still evening. Full choir, four parts, no congregation for nine years.",
	"They sang beautifully. That is what nobody believes. It is not a horrible noise down there, it is a lovely one, and it does not stop.",
	"Go on and break it if you can stand to. I could not, and I have had nine years to try.",
]
const LONGFERRY_C := [
	"I ferry, I do not go ashore on the far side. There is a difference and I intend to keep it.",
]
const LONGFERRY_INN := [
	"Sixty coin. The room over the water is colder but you will hear less of the singing.",
]
const LONGFERRY_SHOP := [
	"Strings, tonic, and a charm if you have the sense to buy one.",
	"Everything here has been across the river at least once. Nothing here is new.",
]

const HIGHWATER_SIGN := [
	"HIGHWATER. Population -- (the number has been rubbed out and rewritten four times.)",
	"DOGS ARE NOT KEPT HERE ANY MORE. DO NOT ASK.",
]
const HIGHWATER_A := [
	"Half this town went down the valley in one summer. Not a flood, not a sickness -- just work, elsewhere, and easier.",
	"They took their songs with them, which is fine, that is what songs are for.",
	"They left everything that made a noise. Every fiddle in every attic, every whistle in every drawer. Nobody carries an instrument on a three-day walk.",
	"So we are the town that is mostly attics now, and you can hear it at night.",
]
const HIGHWATER_B := [
	"We kept dogs. Every house, a dog, and every dog knew its own whistle.",
	"When the houses emptied the whistles stayed. Do you understand what I am telling you? The whistle stayed and there was no one left to blow it and no dog left to come.",
	"They are up in the old kennels now. They are not dogs any more. They are the whistle, wearing what heard it.",
	"Break them. They were good dogs and this is not them.",
]
const HIGHWATER_C := [
	"I am the last one on this street. I sing every evening, out the window, all of it, everything I have got.",
	"Not for company. To keep it used. A song that is being sung is not a left thing, and a left thing is the only kind that turns.",
	"It takes about two hours. I have got another forty years in me, I should think.",
]
const HIGHWATER_INN := [
	"A hundred coin. I know. There is only me to run it now.",
]
const HIGHWATER_SHOP := [
	"Take what you need. Half of it belonged to somebody who is not coming back for it.",
]

const ASHFALL_SIGN := [
	"ASHFALL. Ore, and nothing else, and no apologies.",
	"THE SPIRE ROAD IS NOT A ROAD.",
]
const ASHFALL_A := [
	"Underground you sing to know the others are still breathing. Stop singing and somebody comes looking with a lamp.",
	"So there is no such thing as a forgotten song in a mine. Cannot be. The forgetting kills you.",
	"That is why we are still here and Highwater is attics.",
]
const ASHFALL_B := [
	"There is a spire of rock north of here that was struck by lightning so often the miners made a joke of it.",
	"Somebody left a harp up there. Eighty years back, as a dare, in a storm.",
	"It has been played every storm since and no hand has been near it. Work that one out.",
]
const ASHFALL_C := [
	"You are the mender's, are you. Halloway said there was an apprentice.",
	"She also said the apprentice would be along about now and would need telling one thing, so here it is.",
	"You cannot save any of them. Not one. She did not send you out to try. She sent you out because somebody who loved instruments ought to be the one doing it.",
]
const ASHFALL_INN := [
	"Hundred and sixty. Coal is dear and so am I.",
]
const ASHFALL_SHOP := [
	"Everything, and the good rosin, and no credit.",
]

const LASTCHORD_SIGN := [
	"LAST CHORD. Nine of us. The cave is north. You know that or you would not be here.",
]
const LASTCHORD_A := [
	"Nine of us stayed. Not out of bravery. This is where we are from, and the humming is only a noise.",
	"You get used to a noise. That is the thing nobody down the valley believes.",
]
const LASTCHORD_B := [
	"There is a thicket east of here that used to be an orchard, and in the orchard there used to be a woman who sang to the trees.",
	"She has been dead sixty years. The trees have not stopped.",
	"They learned it wrong, is the trouble. Sixty years of singing it to each other and no one to correct them.",
]
const LASTCHORD_C := [
	"Whatever is in that cave, it is stacked in order. The miner told you. He tells everyone.",
	"He is right and he does not know why it matters. It is in order because it is a list. Oldest at the bottom.",
	"Something down there has been keeping the list, and I do not think it can help it.",
]
const LASTCHORD_INN := [
	"Two hundred and forty, and you will sleep badly, and you will still want the bed.",
]
const LASTCHORD_SHOP := [
	"Last shop there is. Buy heavy.",
]

# ------------------------------------------------------------ the dungeons --

const SIGN_BARROW := [
	"A stone, laid flat, with letters cut deep and filled with moss.",
	"WHAT IS PUT DOWN HERE IS PUT DOWN FOR GOOD.\nMILLBROOK ASKS THAT YOU LEAVE IT SO.",
]
const SIGN_CHAPEL := [
	"A board nailed across the path, and a board is not a wall.",
	"CLOSED. Underneath, in a different hand: they are still in there.",
]
const SIGN_KENNEL := [
	"A row of hooks, and on each hook a name, and no leads on any of them.",
	"BESS. TOLLIVER. NINEPENCE. SHEP. THE LITTLE ONE.",
]
const SIGN_SPIRE := [
	"A pole driven into the rock, scorched black from the top down.",
	"DO NOT CLIMB IN WEATHER. DO NOT CLIMB IN FAIR EITHER.",
]
const SIGN_THICKET := [
	"An orchard gate with no orchard behind it.",
	"The latch still works. Somebody has been keeping the latch working.",
]

const BOSS_HOLLOWBELL := [
	"Millbrook buried its instruments here when mending stopped being possible, which was a kindness, and which did not work.",
	"A cracked handbell sits on top of the heap. It rang for meals in a house that has not stood for forty years.",
	"It still rings for meals. There is nobody to come in and eat.",
]
const BOSS_CHOIRMASTER := [
	"The chapel is half under the river and the water has not troubled the singing at all.",
	"There are no singers. There are eleven hymnals, open, on eleven empty benches, and something at the front with its arms up.",
	"It is doing a lovely job. It has been doing a lovely job to an empty room for nine years and it will not be told.",
]
const BOSS_KENNELKING := [
	"The kennels smell of nothing at all, which is the wrong thing for kennels to smell of.",
	"A brass whistle hangs on the last hook. It is the only one left on its hook.",
	"It is blowing. Nobody is blowing it. And out of the dark at the back, something is coming when it is called, because that is what it was taught and it was taught well.",
]
const BOSS_STORMFATHER := [
	"There is a harp on the top of the spire, strung with wire, eighty years in the weather.",
	"Nobody has tuned it and nobody has played it and it is in tune and it is being played.",
	"The storm does it. The storm has been doing it long enough to have learned the piece.",
]
const BOSS_MOTHERTREE := [
	"The orchard has closed over the path and the path was the last part of it that was orchard.",
	"In the middle is the oldest tree, and it is singing what she sang to it, sixty years on, worn down to three notes and a shape where the words were.",
	"It has taught it to every tree in the thicket. They have all got it slightly wrong, in slightly different ways, and they are all still going.",
	"This is the one you will think about afterwards.",
]

const GATE_LOCKED := "The way down is blocked. Something above has not finished."

## What is left when a side dungeon is done. Not loot -- the piece of the thing
## that was worth keeping, which is the only kind of reward this game can honestly
## hand out.
const RELIC_FOUND := [
	"You pick a piece out of the wreck.",
	"Halloway kept a drawer of these. Never sold one, never explained.",
]

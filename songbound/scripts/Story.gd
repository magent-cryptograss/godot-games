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
	"Every fifth level a song settles into you for good. The first one, then five, ten, on up to a hundred if you live that long.",
	"The levels between only make you harder to knock down. That is not nothing.",
	"Stay with one element and you will learn all eight of its songs and play them like you were born holding it. Spread yourself across all eight and you will know a little of everything.",
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

# Visual Novel Portrait Expressions — 15-Cast Art Direction Guide

Art and pose direction for the 5-expression Visual Novel portrait set (`neutral`, `warm`, `harsh`, `concerned`, `sorrowful`), anchored directly to the **15 existing character portraits** and the **Constance proof-of-concept**.

## 1. Core Framing, Gaze & Continuity Principles

1. **Silhouette & Canvas Anchor Consistency:** Keep torso placement, shoulder height, and head scale within a tight 3–5% envelope across all five poses so expression swaps read as live conversational shifts rather than jump cuts. Watch top-of-frame clearance on tall hairstyles (**Constance's** high bun and **Odette's** high curly puff).
2. **Keep Hands Tucked / Below Frame:** All 15 existing portraits keep hands in coat pockets, behind backs, or beneath shawls. Preserving hands-below-frame across the 4 variant poses matches the Constance set, avoids hand-generation artifacts, and prevents jarring silhouette pops.
3. **Use Eye Contact as a Dramatic Lever:** Almost all existing `neutral` portraits angle the character's gaze slightly off-camera (left or right). Locking their **pupils directly onto the viewer** for `harsh` (delivering an accusation or standing firm) and `warm` (genuine gratitude or confidence) creates immediate intimacy or pressure without needing huge torso movement.
4. **Expressive Amplitude Follows Composure:** Scale head tilts and shoulder shifts to each character's personality and `composure` trait—from **Bartholomew, Hollis, Nisha, and Lian's** grounded restraint up to **Merrin, Jory, Fenwick, and Dorian's** theatrical or high-strung movement.

## 2. Baseline Audit: Portraits That Read Strongly Out of `neutral`

If you want to avoid throwing away any existing art, three portraits are prime candidates to **promote into a non-neutral slot** while generating a slightly calmer `neutral` from them (plus four borderline cases worth noting):

### Strong Candidates to Re-Slot (Zero Wasted Art)
* **Merrin (Rust coat, waistcoat & cream cravat) — Currently reads `warm` / mid-laugh:**
  * *Issue:* With head tilted back and mouth open in a carefree laugh, delivering a post-murder report or catastrophic warning will create heavy tonal whiplash, and leaves little room for `warm` to feel distinct.
  * *Recommendation:* **Move existing sprite to `warm`**, and generate a new `neutral` with lips closed (or lightly parted in restless, alert theatrical poise) and one brow perked inquisitively. *(Directions below cover both options.)*
* **Greta (Wild grey-streaked curls, red leaf-hooded robe) — Currently reads `concerned` / frightened:**
  * *Issue:* Her inner brows are pitched sharply upward with deep forehead creases and wide, anxious eyes. She reads more frightened than Isolde, which undercuts her gruff, suspicious gatekeeper voice (`composure: 0.60`, `confidence: 0.70`).
  * *Recommendation:* **Move existing sprite directly to `concerned`**, and generate a new `neutral` with lowered, sharp-eyed appraising brows, a level chin, and a firmer, skeptical mouth.
* **Jory (Curly dark hair, green laced vest) — Currently reads `warm`:**
  * *Issue:* A full ear-to-ear toothy grin reads great for greetings, but feels overly celebratory during grim town meetings or neutral alibis, and caps how much brighter `warm` can go.
  * *Recommendation:* **Move existing sprite to `warm`**, and generate a new `neutral` with an alert, closed-mouth upbeat half-smile and bright curious eyes.

### Borderline Baselines (Workable as `neutral` with Care)
* **Edda (Yellow coat & overalls), Fenwick (White beard, teal vest), and Agnes (Terracotta shawl):** All three have clear closed-mouth smiles in `neutral`. They still work as warm-natured baselines *if* their dedicated `warm` poses turn their gaze directly onto the viewer, crinkle their eyes deeper, and open/broaden the smile.
* **Dorian (Gaunt sloucher, olive coat) and Isolde (Brown braid, orange shawl):** Both already have upturned worried brows in `neutral`. That fits their skittish `composure` (`0.15` and `0.25`), provided `concerned` pushes noticeably further (hiked shoulders, wider darting eyes, tighter mouth) so `neutral` and `concerned` don't blur together at game size.

## 3. Reference Benchmark: Constance (`composure: 0.50`)

* **Visual Anchor:** Tall grey-streaked updo, purple Victorian gown with high ruffled collar and amethyst brooch, 3/4 right torso, gaze toward viewer.
* **Key Separation:** `neutral` is appraising, `harsh` is certain, and `concerned` is holding herself together while being judged.
* **`neutral` (Existing):** Upright and composed, arched brow, cool appraising gaze, slight natural downturn to the mouth.
* **`warm` (Done):** Slight head tilt toward the listener, softened eyes, small genuine lift at the corners of the mouth, less tension in the shoulders.
* **`harsh` (Done):** Chin raised, shoulders squared with a slight forward lean, sharp arched brow, steady gaze, restrained knowing set to the mouth.
* **`concerned` (Done):** Upright by effort, shoulders drawn slightly inward, inner brows pulled together and lifted, tighter mouth showing strain beneath offended dignity.
* **`sorrowful` (Done):** Modest downward tilt of the head, tiny slump in the shoulders, eyes cast slightly downward/aside, stiff-upper-lip restraint at the corners of the mouth.

## 4. Character-by-Character Expression & Pose Directions

### Agnes (`composure: 0.30` | Warm village widow who knows everyone's business)
* **Visual Anchor:** Warm-skinned older woman, thick grey-streaked braided bun, gold drop earrings, terracotta leaf-patterned shawl with gold leaf brooch; 3/4 right turn, currently looking right with a kindly closed-mouth smile.
* **`neutral` (Existing):** Kindly, attentive three-quarter turn to the right, warm brows, gentle closed-mouth smile.
* **`warm`:** Turns her head and gaze directly toward the viewer with a fond tilt; smile deepens with crinkles around her eyes and cheeks, shoulders soft and welcoming.
* **`harsh`:** **Maternal steel, not cruelty:** Head turns toward the viewer, smile vanishes into a firm, flat line, chin levels out, brows lower in serious, protective disappointment.
* **`concerned`:** Shoulders draw inward beneath the terracotta shawl, head pulls slightly back, brows knit upward with deep worry lines, lips slightly parted in dismay.
* **`sorrowful`:** Chin dips toward her brooch, shoulders droop noticeably, eyes glisten and cast downward, soft trembling set to her mouth—mourning a neighbor like family.

### Bartholomew (`composure: 0.70` | Broad-shouldered man of few words)
* **Visual Anchor:** Broad-shouldered Black man with short dark curls, grey-flecked full beard, navy double-breasted coat over buttoned grey vest, hands behind back; 3/4 left torso, heavy brow looking left.
* **`neutral` (Existing):** Square, immovable shoulders, head turned 3/4 left, calm heavy brow, flat mouth under his mustache—watchful stillness.
* **`warm`:** Turns eyes toward the viewer with a slight respectful dip of the chin; brow relaxes upward, crow's-feet crinkle at the corners of his eyes, and his beard lifts slightly on one side in a rare, gruff half-smile.
* **`harsh`:** Squares his broad shoulders slightly more toward the camera, chin lowers, eyes lock directly onto the viewer from under a heavy furrowed brow, jaw set like iron.
* **`concerned`:** Subtle tension on a stoic man: head pulls back a fraction, inner brows pinch together creating a vertical crease, eyes narrow warily toward the viewer.
* **`sorrowful`:** Heavy, dignified bow of the head, broad navy coat shoulders slumping slightly downward, eyes shadowed and cast toward the ground.

### Dorian (`composure: 0.15` | Twitchy young man who sleeps badly)
* **Visual Anchor:** Gaunt, long-necked young man with messy brown curls, heavy dark circles under his eyes, prominent nose, olive-green coat over brown waistcoat; slouching 3/4 right, looking sideways/down.
* **`neutral` (Existing):** Habitual tired slouch, long neck angled forward, upturned worried brows, hesitant sideways gaze, small flat mouth.
* **`warm`:** **Visible exhale of relief:** Shoulders drop looser rather than hunched, head lifts slightly toward the viewer, knotted brows smooth out, and a shy, grateful closed-mouth smile softens his tired face.
* **`harsh`:** **Cornered, urgent conviction:** Leans forward from the collar, eyes wide and locked directly onto the viewer, brows drawn sharply down instead of up, jaw tight—pushing past his nerves because he knows what he saw.
* **`concerned`:** Acute panic vs. his tired baseline: pulls his chin back toward his olive coat collar, shoulders hiked high toward his ears, eyes wide and darting, mouth pulled into a taut grimace.
* **`sorrowful`:** Deep, hollowed-out exhaustion: shoulders collapse further forward, head hangs low, eyelids heavy and staring down at the floor in quiet misery.

### Edda (`composure: 0.85` | Cheerful, practical, hard to rattle)
* **Visual Anchor:** Rosy-cheeked, freckled young woman with wavy copper-red bob, bright yellow hooded work jacket over brown bib overalls and collared shirt; 3/4 left gaze with an upbeat closed-mouth smile.
* **`neutral` (Existing):** Sturdy, relaxed stance, head angled slightly back with a bright, capable closed-mouth smile looking left.
* **`warm`:** Turns her gaze directly onto the viewer and leans slightly in; cheeks lift into a full, crinkle-eyed grin (a hint of teeth works nicely here to top her sunny baseline), shoulders open and easy.
* **`harsh`:** No panic or theatrics—smile disappears completely, chin levels out, freckles bunch slightly across the bridge of her nose as her brows lower into a steady, no-nonsense stare straight at the viewer.
* **`concerned`:** Smile flattens into a tight line, one brow arches while the other furrows in practical trouble, head tilts slightly as if sizing up a storm coming in off the water.
* **`sorrowful`:** Brightness drains from her posture: shoulders soften downward in the yellow jacket, chin dips, brows lift gently at the inner corners over quiet, sympathetic downcast eyes.

### Fenwick (`composure: 0.40` | Jovial storyteller / tavern raconteur)
* **Visual Anchor:** Rotund, rosy-cheeked older man, bald crown with fluffy white side-hair, thick white beard and upturned handlebar mustache, teal waistcoat and knotted kerchief over rolled cream sleeves; 3/4 right, beaming upward.
* **`neutral` (Existing):** Chest puffed slightly with hands behind back, rosy nose, twinkling upward-right gaze, cheerful smile lifting the tips of his white mustache.
* **`warm`:** Leans conspiratorially forward and turns his twinkling eyes straight at the viewer; broad, booming grin under the mustache, brows raised high in delight.
* **`harsh`:** **Stage gravitas:** Squares his chest, lowers his chin, lets the handlebar mustache drop level as his smile vanishes, and fixes the viewer with a fierce, lowered-brow scowl.
* **`concerned`:** Caught off-script: leans slightly back, twinkle gone, brows pinched high across his forehead, mustache tense over a tight, uneasy grimace.
* **`sorrowful`:** **"Serious mode" curtain drop:** All tavern performance vanishes; shoulders sag in the teal waistcoat, chin sinks into his white beard, eyes heavy, tired, and cast down.

### Greta (`composure: 0.60` | Sharp-eyed gatekeeper, suspicious of outsiders)
* **Visual Anchor:** Gaunt, pale older woman with wild, messy grey-streaked curls, high-buttoned cream collar under a deep red leaf-patterned hooded robe; 3/4 right turn.
* **`neutral`:**
  * *If re-slotting existing art to `concerned` (Recommended):* Generate a firmer baseline—same red robe and wild grey hair, chin level, brows lowered into a sharp, squinting sideways appraisal, mouth set in a skeptical flat line.
  * *If keeping existing art as `neutral`:* Treat her high-browed, tense gaze as prickly, hyper-vigilant wariness, and push `harsh` / `concerned` strongly away from it via posture.
* **`warm`:** A rare, grudging thaw: forehead smooths out, shoulders uncoil slightly, eyes turn toward the viewer with relaxed lids, and one corner of her mouth lifts in a dry, approving half-smile.
* **`harsh`:** Chin juts forward, shoulders square under the red robe, eyes lock dead-on with the viewer in a fierce, narrowed glare under sharply lowered brows, mouth pulled into a hard scowl.
* **`concerned`:** *(Existing sprite fits right here, or push slightly inward):* Shoulders hunched tight inside the red cloak, inner brows pitched sharply upward with forehead creases, wide wary eyes, tense downturned mouth.
* **`sorrowful`:** Head bows so wild grey curls frame her face, shoulders rounded inward, fierce eyes suddenly sunken, damp, and turned down away from the viewer.

### Hollis (`composure: 0.80` | Old scholar who weighs every word)
* **Visual Anchor:** Elderly thin man with swept-back silver hair, prominent aquiline nose, round wire spectacles, grey mustache and pointed goatee, lavender/purple cravat, dark coat and brown vest with gold watch chain; 3/4 left profile.
* **`neutral` (Existing):** Upright scholarly 3/4 left profile, calm eyes behind round spectacles, relaxed brow, neutral mouth under his grey mustache.
* **`warm`:** Turns his head a touch closer to the viewer with a gentle nod-like tilt; brows relax upward, eyes crinkle warmly behind the spectacles, and his mustache lifts in a mild, pleased smile.
* **`harsh`:** Tucks his chin slightly so he peers **over the top rim of his round spectacles** directly at the viewer; spine rigid, brows drawn down into an exacting, unyielding line.
* **`concerned`:** Pulls his head back a fraction, deep vertical furrow between his silver brows, eyes narrowed intently behind the lenses as an inconsistency troubles him.
* **`sorrowful`:** Noticeable weight in his narrow shoulders, head bowed downward, eyes lowered beneath heavy lids behind his glasses, mouth grave and weary.

### Isolde (`composure: 0.25` | Soft-spoken peacemaker, easily frightened)
* **Visual Anchor:** Young woman with straight brown bangs and a thick side-braid over her left shoulder, ruffled cream collar under an apricot-orange leaf-patterned shawl; 3/4 left turn, shy downcast gaze.
* **`neutral` (Existing):** Modest, gentle stance wrapped in her orange shawl, head dipped slightly left, soft upturned brows, wide earnest eyes looking shyly aside.
* **`warm`:** Lifts her chin and turns her big dark eyes directly toward the viewer; brow tension melts away, shoulders relax, and a soft, radiant, relieved smile warms her face.
* **`harsh`:** **Trembling moral resolve (never cruel):** Straightens her neck and posture as tall as she can, locks earnest eyes directly on the viewer, brows knitted firmly downward, small mouth set tight with courage.
* **`concerned`:** Pulls her shoulders high and narrow inside the shawl, chin tucked defensively, eyes wide showing more white, inner brows pitched steeply upward, lips parted in a quiet gasp.
* **`sorrowful`:** Head bowed deeper toward her chest, thick braid falling forward slightly, shoulders slumped, glistening eyes nearly closed or cast to the floor in quiet heartbreak.

### Jory (`composure: 0.45` | Cheerful lad who never stops moving)
* **Visual Anchor:** Youthful, tan-skinned lad with tousled dark-brown curls, open-necked cream shirt with rolled-up sleeves, olive-green front-laced vest; 3/4 right turn.
* **`neutral`:**
  * *If re-slotting existing art to `warm` (Recommended):* Same lively stance and green vest, mouth closed in an alert, upbeat half-smile, bright curious eyes ready to spring into the next question.
  * *If keeping existing art as `neutral`:* Wide, energetic toothy grin looking right—meaning `warm` needs direct eye contact and a bigger forward lean to read distinctly.
* **`warm`:** *(Existing sprite works well here, or turn eyes directly onto viewer):* Energetic lean-in, shoulders open, bright beaming grin, eyebrows perked up in total enthusiasm.
* **`harsh`:** Youthful indignation: grin vanishes completely, leans sharply forward in his green vest, brows pulled down tight, jaw set firm, eyes locked straight onto the viewer.
* **`concerned`:** Spring-loaded recoil: shoulders hike up, head pulls back slightly, eyes go wide, brows shoot up in "whoa, hold on!" alarm, mouth tense and slightly open.
* **`sorrowful`:** All kinetic energy drains out: shoulders visibly slumped, chin dropped toward his open collar, brows knitted upward over hurt, downcast eyes.

### Kiran (`composure: 0.70` | Affable wit who deflects with humor)
* **Visual Anchor:** Olive-skinned / South Asian man with dark wavy hair, neat mustache, soul patch and heavy stubble, ochre/mustard overcoat, dark blue knitted scarf, grey waistcoat, hands in pockets; 3/4 right head turn with a sly grin.
* **`neutral` (Existing):** Relaxed hands-in-pockets lean, head turned right, one dark brow subtly cocked, sly closed-mouth parlor grin under his mustache.
* **`warm`:** Turns his face more openly toward the viewer and drops the guarded angle; both brows relax evenly, eyes warm up with genuine crinkles, and the sly smirk becomes an easy, sincere smile.
* **`harsh`:** **The gambler's cold read:** The smile under the mustache disappears completely; head turns to face the viewer more squarely, chin levels, eyelids narrow into a cool, razor-sharp stare.
* **`concerned`:** Mask slipping under pressure: slight stiffening of his shoulders in the ochre coat, a taut, forced remnant of a line at his mouth that doesn't reach his narrowed, calculating eyes.
* **`sorrowful`:** Bravado gone; chin dips toward his blue scarf, shoulders slacken, brow draws inward in quiet bitterness, eyes shadowed and looking down to the side.

### Lian (`composure: 0.70` | Blunt, practical, crisis triage)
* **Visual Anchor:** Seasoned older East Asian woman with a short wavy silver-grey bob and bangs, olive-green coat with dark brown collar and cuffs over a cream buttoned shirt, hands in pockets; 3/4 left turn with a wry, level-headed smile.
* **`neutral` (Existing):** Grounded, compact stance in her olive coat, head turned left with a calm, observant sideways glance and a dry, unbothered closed-mouth smile.
* **`warm`:** Turns her eyes directly toward the viewer with a brisk, approving nod-like tilt; brows lift slightly, cheeks round into a fuller, warmer smile of earned respect ("good work").
* **`harsh`:** **No-nonsense triage:** All trace of the wry smile vanishes; squares her shoulders, levels her chin, and locks a blunt, unflinching stare onto the viewer under drawn-down brows.
* **`concerned`:** Mouth presses thin and flat, brows pinch sharply at the bridge of her nose, slight tense shift in her shoulders as she weighs a bad development on the board.
* **`sorrowful`:** Stoic, heavy responsibility: chin lowers slightly, gaze drops away from the viewer, face quiet and weathered with tired, unshowy gravity.

### Merrin (`composure: 0.15` | Comedic-theatrical catastrophist)
* **Visual Anchor:** Slender, expressive young dandy with tousled chin-length dark hair, rust-red coat, brown waistcoat, loose cream cravat, hands in pockets; front-facing torso with a jaunty head tilt.
* **`neutral`:**
  * *If re-slotting existing art to `warm` (Recommended):* Keep the jaunty dandy posture and loose cravat, close the mouth into an alert, slightly dramatic expression with expressive brows—poised to gasp or gossip at a moment's notice.
  * *If keeping existing art as `neutral`:* Breezy, open-mouthed mid-chatter charm—meaning `concerned`, `harsh`, and `sorrowful` carry the comedic-theatrical swings into doom!
* **`warm`:** *(Existing sprite fits naturally here, or turn eyes directly onto viewer):* Head tilted jauntily, bright relieved eyes, open-hearted theatrical smile ("thank heaven, a friendly face!").
* **`harsh`:** **Theatrical courtroom point (minus the hand):** Straightens dramatically out of the slouch, chin lifted, hair framing wide blazing eyes locked on the viewer, brows lowered in scandalized, prophetic accusation.
* **`concerned`:** **Comedic-dramatic "the sky is falling!" panic:** Recoils slightly back into the rust coat, shoulders hiked, eyes wide and round, brows pitched sky-high, mouth open in a breathless gasp.
* **`sorrowful`:** Operatic woe: head tilted dramatically downward and askew, shoulders deflated, inner brows arched high in tragic anguish, downcast eyes mourning their certain doom.

### Nisha (`composure: 0.75` | Patient, observant, slow to let go of a theory)
* **Visual Anchor:** Sharp-featured South Asian woman with an aquiline nose, thick dark wavy braid with a striking silver-white streak at the temple, deep teal shawl over a ruffled high collar; 3/4 left turn, cool observant side-glance.
* **`neutral` (Existing):** Textbook analytical baseline—still, poised shoulders under the teal shawl, sharp dark eyes glancing left, composed unsmiling mouth, slight thoughtful tension in the brow.
* **`warm`:** Turns her gaze directly toward the viewer with a subtle tilt of the head; brow tension smooths out, eyes soften, and a small, genuine closed-mouth smile warms her expression—quiet investigator camaraderie.
* **`harsh`:** **Surgical lock-in:** Slight forward lean, head turns sharper toward the viewer, dark eyes narrow into a piercing, unblinking stare, jaw set—she has isolated the contradiction on the board.
* **`concerned`:** Head pulls back half an inch, inner brows knit more tightly together, eyes widen slightly in rapid mental recalculation as a premise breaks.
* **`sorrowful`:** Eyelids lower over downcast eyes turned away from the camera, shoulders lose a fraction of their crisp poise under the teal shawl, mouth pressed thin in quiet regret.

### Odette (`composure: 0.60` | Quiet, dry, fiercely her own woman)
* **Visual Anchor:** Young Black woman with a shaved side-undercut and tall cascading curly puff (watch top canvas margin!), mauve-plum jacket, rust-red knotted neckscarf, belted brown trousers/skirt; 3/4 right turn with a dry sideways half-smile.
* **`neutral` (Existing):** Effortlessly cool stance, hands in pockets, head angled slightly down-right with half-lidded eyes and a dry, velvet-edged closed-mouth smile.
* **`warm`:** Lifts her gaze to meet the viewer directly with a slight fond tilt; eyelids open warmer, and the dry smirk relaxes into a genuine, unguarded smile—pleased despite her better instincts.
* **`harsh`:** **Icy, withering precision:** Amusement vanishes completely; spine straightens, chin lifts slightly to look coolly down her nose at the viewer, brows sharpen, mouth sets crisp and flat.
* **`concerned`:** **The aloof mask slips:** Shoulders stiffen in the mauve blazer, half-lidded coolness gives way to wider, sharper eyes, inner brows crease, smile gone into a taut line.
* **`sorrowful`:** Turns slightly further away into quiet privacy; chin dips toward her rust neckscarf, shoulders soften downward, eyes lowered beneath heavy lids—grieving without asking for an audience.
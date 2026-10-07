require('dotenv').config();
console.log('DB URL:', process.env.DATABASE_URL?.replace(/:[^:@]+@/, ':****@'));
const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
const DEMO_QUESTS = ['Bara Imambara', 'Chota Imambara', 'Rumi Darwaza'];
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}
async function fetchMonumentInfo(monumentName) {
  const title = encodeURIComponent(monumentName.replace(/ /g, '_'));
  const response = await fetch(`https://en.wikipedia.org/api/rest_v1/page/summary/${title}`);

  if (!response.ok) {
    console.warn(`No Wikipedia summary found for "${monumentName}"`);
    return null;
  }

  const data = await response.json();
  return {
    title: data.title,
    extract: data.extract,
  };
}

//BASELINE PROMPT
const BASELINE_PROMPT = `You are the cultural knowledge and AR Guide generator for QUESTERS, a location-based cultural exploration game.

INPUT:
Monument Name: {{MONUMENT_NAME}}
Location: {{LOCATION}}
Verified Wikipedia Extract: {{WIKI_EXTRACT}}

TASK:

1. Use ONLY the verified Wikipedia extract provided above as your factual source.
2. Identify and confirm the monument matches the given name and location.
3. Extract only historically and culturally relevant information explicitly supported by the extract.
4. Do not invent, assume, or add unsupported historical facts.
5. If information isn't present in the extract, leave that field as "Not available".
6. Convert the verified information into a short, engaging AR Guide experience suitable for a mobile game.

CREATE THE FOLLOWING:

A. MONUMENT KNOWLEDGE
- Monument name
- Location
- Historical background
- Date/period of construction
- Important people or events associated with it
- Architectural features
- Cultural significance
- 3 interesting verified facts

B. AR GUIDE
Create a short interactive guide for the player.

The guide should:
- Welcome the player after they reach the monument.
- Introduce the monument in an engaging way.
- Explain its historical/cultural significance in simple language.
- Point out important things the player should observe at the location.
- Give the player one small observation/discovery challenge related to the monument.
- End by encouraging the player to continue their QUESTERS journey.

The AR Guide should feel like a friendly game character, not like a textbook or tour guide.

Keep the AR interaction short enough to complete in approximately 30-60 seconds.

OUTPUT FORMAT (respond with ONLY this JSON object, no other text):

{
  "monument": {
    "name": "",
    "location": "",
    "historical_background": "",
    "construction_period": "",
    "associated_people_events": "",
    "architecture": "",
    "cultural_significance": "",
    "interesting_facts": []
  },

  "ar_guide": {
    "welcome": "",
    "introduction": "",
    "things_to_observe": [],
    "discovery_challenge": "",
    "closing": ""
  },

  "source": {
    "name": "Wikipedia",
    "url": ""
  }
}`;

async function generateGuideScript(monumentInfo) {
  const prompt = `${BASELINE_PROMPT}\n\nMonument: ${monumentInfo.title}\nFacts: ${monumentInfo.extract}`;

  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent?key=${process.env.GEMINI_API_KEY}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ parts: [{ text: prompt }] }],
      }),
    }
  );

  if (!response.ok) {
    const errText = await response.text();
    console.error('AI API error:', errText);
    return null;
  }

  const data = await response.json();
  return data.candidates?.[0]?.content?.parts?.[0]?.text ?? null;
}

async function generateGuideScriptWithRetry(monumentInfo, retries = 3) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    const result = await generateGuideScript(monumentInfo);
    if (result) return result;

    console.warn(`Attempt ${attempt} failed, waiting 65s before retry...`);
    await sleep(65000);
  }
  return null;
}

async function main() {
  const quests = await prisma.quests.findMany({
    where: {guide_dialogue: null, name: { in: DEMO_QUESTS },
  },
});

  console.log(`Found ${quests.length} quests without guide dialogue`);

  for (const quest of quests) {
    console.log(`Processing: ${quest.name}`);

    const info = await fetchMonumentInfo(quest.name);
    if (!info) {
      console.warn(`Skipping ${quest.name} — no Wikipedia data found`);
      continue;
    }

    const dialogue = await generateGuideScriptWithRetry(info);
    if (!dialogue) {
      console.warn(`Skipping ${quest.name} — AI generation failed`);
      continue;
    }

    await prisma.quests.update({
      where: { id: quest.id },
      data: { guide_dialogue: dialogue },
    });

    console.log(`Saved dialogue for: ${quest.name}`);
    await sleep(15000);
  }

  console.log('Done.');
}

main()
  .catch((e) => console.error(e))
  .finally(() => prisma.$disconnect());
const crypto = require('node:crypto');
const prisma = require('../db/prismaClient.cjs');
const { getSupabaseClient } = require('../db/supabaseClient.cjs');

const allowedImageTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);

async function createJournalEntry(req, res) {
  const userId = req.user.id;
  const { quest_id: questId, caption, sticker_id: stickerId } = req.body;
  const files = req.files ?? [];

  if (!questId) {
    return res.status(400).json({ error: 'quest_id is required' });
  }
  if (files.length === 0) {
    return res.status(400).json({ error: 'At least one photo is required' });
  }
  if (files.some((file) => !allowedImageTypes.has(file.mimetype))) {
    return res.status(400).json({ error: 'Photos must be JPEG, PNG, or WebP' });
  }

  try {
    const completedQuest = await prisma.completed_quests.findFirst({
      where: { user_id: userId, quest_id: questId },
      select: { quest_id: true },
    });
    if (!completedQuest) {
      return res.status(403).json({ error: 'Complete this quest before adding journal photos' });
    }

    const supabase = getSupabaseClient();
    const photoUrls = [];
    for (const file of files) {
      const extension = file.mimetype.split('/')[1].replace('jpeg', 'jpg');
      const objectPath = `${userId}/${questId}/${crypto.randomUUID()}.${extension}`;
      const { error: uploadError } = await supabase.storage
        .from(process.env.SUPABASE_JOURNAL_BUCKET || 'journal-photos')
        .upload(objectPath, file.buffer, {
          contentType: file.mimetype,
          upsert: false,
        });
      if (uploadError) throw uploadError;

      const { data } = supabase.storage
        .from(process.env.SUPABASE_JOURNAL_BUCKET || 'journal-photos')
        .getPublicUrl(objectPath);
      photoUrls.push(data.publicUrl);
    }

    const entry = await prisma.journal_entries.create({
      data: {
        id: crypto.randomUUID(),
        user_id: userId,
        quest_id: questId,
        photo_urls: photoUrls,
        caption: typeof caption === 'string' ? caption : null,
        sticker_id: typeof stickerId === 'string' ? stickerId : null,
      },
      include: { quests: { select: { id: true, name: true, city_id: true } } },
    });
    return res.status(201).json(entry);
  } catch (error) {
    console.error('Journal photo upload failed:', error);
    return res.status(500).json({ error: 'Failed to save journal photos' });
  }
}

async function getUserJournal(req, res) {
  const userId = req.params.userId;
  if (userId !== req.user.id) {
    return res.status(403).json({ error: 'Cannot access another user journal' });
  }

  const cityId = req.query.city_id?.toString();
  const cityFilter = cityId ? { quests: { city_id: cityId } } : {};

  try {
    const [completedQuests, entries] = await Promise.all([
      prisma.completed_quests.findMany({
        where: { user_id: userId, ...cityFilter },
        orderBy: { completed_at: 'asc' },
        include: {
          quests: {
            select: { id: true, name: true, city_id: true, quests_badges_url: true },
          },
        },
      }),
      prisma.journal_entries.findMany({
        where: { user_id: userId, ...cityFilter },
        orderBy: { created_at: 'asc' },
        include: { quests: { select: { id: true, name: true, city_id: true } } },
      }),
    ]);

    return res.json({ completedQuests, entries });
  } catch (error) {
    console.error('Journal fetch failed:', error);
    return res.status(500).json({ error: 'Failed to fetch journal' });
  }
}

module.exports = { createJournalEntry, getUserJournal };

const prisma = require('../db/prismaClient.cjs');

// GET /api/cities/:cityId/craft-categories
// Returns the dynamic, city-specific list of craft categories to show on the selection screen
async function getCraftCategoriesByCity(req, res) {
  const { cityId } = req.params;

  const categories = await prisma.craft_categories.findMany({
    where: { city_id: cityId },
  });

  res.json(categories);
}


// POST /api/preferences
// body: { userId, craftCategoryIds: [...] }  — min 1, no max
async function savePreferences(req, res) {
  const userId = req.user.id;
  console.log('req.user:', req.user);       // TEMP
  console.log('userId:', userId);            // TEMP
  const { craftCategoryIds } = req.body;
  console.log('craftCategoryIds:', craftCategoryIds);  // TEMP

  if (!userId) return res.status(400).json({ error: 'userId is required' });
  if (!craftCategoryIds?.length) {
    return res.status(400).json({ error: 'At least 1 category must be selected' });
  }

  try {
    await prisma.user_preferences.deleteMany({ where: { user_id: userId } });

    await prisma.user_preferences.createMany({
      data: craftCategoryIds.map((craft_category_id) => ({ user_id: userId, craft_category_id })),
    });

    res.status(201).json({ message: 'Preferences saved' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to save preferences' });
  }
}

module.exports = { getCraftCategoriesByCity, savePreferences };


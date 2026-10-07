const prisma = require('../db/prismaClient.cjs');

// GET /api/recommendations/:userId
async function getRecommendations(req, res) {
  const { userId } = req.params;
  if (userId !== req.user.id) {
    return res.status(403).json({ error: 'Cannot access another user recommendations' });
  }

  try {
    const preferences = await prisma.user_preferences.findMany({
      where: { user_id: userId },
      select: { craft_category_id: true },
    });

    if (!preferences.length) {
      return res.status(400).json({ error: 'User has not set preferences yet' });
    }

    const categoryIds = preferences.map((p) => p.craft_category_id);

    const sellers = await prisma.sellers.findMany({
      where: { craft_category_id: { in: categoryIds } },
      select: {
        id:true,
        shop_name:true,
        description:true,
        address:true,
        craft_categories:{select:{name:true}}
      },
    });

    res.json(sellers);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch recommendations' });
  }
}

module.exports = { getRecommendations };
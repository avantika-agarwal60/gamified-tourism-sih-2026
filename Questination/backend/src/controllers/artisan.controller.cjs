const prisma = require('../db/prismaClient.cjs');

// GET /api/artisans/city/:cityId
// Returns all verified sellers/craftspeople in a given city — this is the
// "local artists" list shown to a tourist visiting that city
async function getArtisansByCity(req, res) {
  const { cityId } = req.params;

  try {
    const artisans = await prisma.sellers.findMany({
      where: {
        city_id: cityId,
        craft_category_id: { not: null },   
      },
      select: {
        id: true,
        shop_name: true,
        description: true,
        address:true,
        craft_categories: { select: { name: true } },   // include craft name via the relation now
      },
    });

    res.json(artisans);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch artisans' });
  }
}

module.exports = { getArtisansByCity };
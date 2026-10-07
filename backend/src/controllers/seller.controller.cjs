const prisma = require('../db/prismaClient.cjs');
const supabase = require('../db/supabaseClient.cjs');

// POST /api/sellers/register
// Assumes the user already exists in `users` (created via Firebase auth + Person 1's flow)
async function registerSeller(req, res) { const { userId, shop_name, description, tax_bracket_tier, address } = req.body;

  if (!userId || !shop_name) {
    return res.status(400).json({ error: 'userId and shop_name are required' });
  }

  try {
    const seller = await prisma.sellers.create({
      data: { id: userId, shop_name, description, tax_bracket_tier,address },
    });
    res.status(201).json(seller);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to register seller' });
  }
}
async function getCraftCategories(req, res) {
  const { city_id } = req.query;
  if (!city_id) return res.status(400).json({ error: 'city_id is required' });

  try {
    const categories = await prisma.craft_categories.findMany({
      where: { city_id },
      select: { id: true, name: true },
      orderBy: { name: 'asc' },
    });
    res.json(categories);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch craft categories' });
  }
}

// GET /api/sellers/:id
async function getSellerProfile(req, res) {
  const { id } = req.params;
  const seller = await prisma.sellers.findUnique({ where: { id } });
  if (!seller) return res.status(404).json({ error: 'Seller not found' });
  res.json(seller);
}

// PUT /api/sellers/:id
async function updateSellerProfile(req, res) {
  const { id } = req.params;
  const { shop_name, description, tax_bracket_tier, address } = req.body;

  try {
    const updated = await prisma.sellers.update({
      where: { id },
      data: { shop_name, description, tax_bracket_tier, address },
    });
    res.json(updated);
  } catch (err) {
    console.error(err);
    res.status(404).json({ error: 'Seller not found' });
  }
}

// POST /api/sellers/:id/udyam
// multipart/form-data: field "udyam_id" (text), file field "udyam_proof"
async function submitUdyamProof(req, res) {
  const { id } = req.params;
  const { udyam_id } = req.body;
  const file = req.file;

  if (!udyam_id || !file) {
    return res.status(400).json({ error: 'udyam_id and a proof image are required' });
  }

  try {
    const fileName = `${id}/${Date.now()}-${file.originalname}`;

    const { error: uploadError } = await supabase.storage
      .from('seller-documents')
      .upload(fileName, file.buffer, { contentType: file.mimetype });

    if (uploadError) throw uploadError;

    // Private bucket — store the file path, not a public URL.
    // Admin views it later via a signed (temporary) URL, not a permanent public link.
    const updated = await prisma.sellers.update({
      where: { id },
      data: { udyam_id, udyam_proof_url: fileName },
    });

    res.json({ message: 'Udyam proof submitted', seller: updated });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to submit Udyam proof' });
  }
}
// GET /api/sellers/pending
// Returns sellers whose linked user account is still awaiting verification
async function getPendingSellers(req, res) {
  try {
    const PENDING = await prisma.sellers.findMany({
      where: { users: { verificationStatus: 'PENDING' } },
      select: {
        id: true,
        shop_name: true,
        description: true,
        address: true,
        udyam_id: true,
        udyam_proof_url: true,
        craft_category_id: true,
        city_id: true,
        cities: { select: { id: true, name: true } },
        craft_categories: { select: { id: true, name: true } },
        users: { select: { username: true, email: true } },
      },
    });

    res.json(PENDING);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch pending sellers' });
  }
}
async function setVerificationStatus(req, res) {
  const { id } = req.params;
  const { status } = req.body;

  if (!['verified', 'rejected'].includes(status)) {
    return res.status(400).json({ error: "status must be 'verified' or 'rejected'" });
  }

  try {
    const user = await prisma.users.update({
      where: { id },
      data: { verificationStatus: status },
    });
    res.json({ id: user.id, verificationStatus: user.verificationStatus });
  } catch (err) {
    res.status(404).json({ error: 'Seller not found' });
  }
}
async function getCities(req, res) {
  try {
    const cities = await prisma.cities.findMany({
      select: { id: true, name: true },
      orderBy: { name: 'asc' },
    });
    res.json(cities);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch cities' });
  }
}


// PUT /api/sellers/:id/verify-craft
async function verifySellerCraft(req, res) {
  const { id } = req.params;
  const { craftName, city_id } = req.body;

  if (!craftName || !city_id) {
    return res.status(400).json({ error: 'craftName and city_id are required' });
  }

  try {
    // Find or create the craft category for this city — this is what makes
    // the category list grow dynamically as new sellers register
    let craftCategory = await prisma.craft_categories.findUnique({
      where: { name_city_id: { name: craftName, city_id } },
    });

    if (!craftCategory) {
      craftCategory = await prisma.craft_categories.create({
        data: { name: craftName, city_id },
      });
    }

    const updated = await prisma.sellers.update({
      where: { id },
      data: { craft_category_id: craftCategory.id, city_id },
    });

    res.json(updated);
  } catch (err) {
    console.error(err);
    res.status(404).json({ error: 'Seller not found' });
  }
}
// GET /api/sellers/:id/udyam-proof-url
async function getUdyamProofUrl(req, res) {
  const { id } = req.params;

  try {
    const seller = await prisma.sellers.findUnique({ where: { id } });
    if (!seller?.udyam_proof_url) {
      return res.status(404).json({ error: 'No proof uploaded' });
    }

    const { data, error } = await supabase.storage
      .from('seller-documents')
      .createSignedUrl(seller.udyam_proof_url, 60 * 10); // link valid for 10 minutes

    if (error) throw error;

    res.json({ url: data.signedUrl });
  } catch (err) {
    res.status(500).json({ error: 'Failed to generate proof URL' });
  }
}

module.exports = { registerSeller,
  getSellerProfile,updateSellerProfile,verifySellerCraft,getPendingSellers,submitUdyamProof,getUdyamProofUrl,setVerificationStatus, getCities, getCraftCategories  };

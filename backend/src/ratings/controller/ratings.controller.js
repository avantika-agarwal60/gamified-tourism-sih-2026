import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export async function createRating(req, res) {
  const userId = req.user.id;
  const { questId, sellerId, rating, reviewText } = req.body;
  const hasQuest = typeof questId === 'string' && questId.trim().length > 0;
  const hasSeller = typeof sellerId === 'string' && sellerId.trim().length > 0;
  const ratingValue = Number(rating);

  if (!Number.isInteger(ratingValue) || ratingValue < 1 || ratingValue > 5) {
    return res.status(400).json({ message: 'rating must be an integer from 1 to 5' });
  }
  if (hasQuest === hasSeller) {
    return res.status(400).json({ message: 'provide either questId or sellerId' });
  }

  try {
    if (hasQuest) {
      const quest = await prisma.quests.findUnique({ where: { id: questId } });
      if (!quest) return res.status(404).json({ message: 'quest not found' });
    }
    if (hasSeller) {
      const seller = await prisma.sellers.findUnique({ where: { id: sellerId } });
      if (!seller) return res.status(404).json({ message: 'seller not found' });
    }

    const created = await prisma.ratings.create({
      data: {
        user_id: userId,
        quest_id: hasQuest ? questId : null,
        seller_id: hasSeller ? sellerId : null,
        rating: ratingValue,
        review_text: typeof reviewText === 'string' && reviewText.trim()
            ? reviewText.trim()
            : null,
      },
    });
    return res.status(201).json({ message: 'rating submitted successfully', rating: created });
  } catch (error) {
    console.error('Create rating failed:', error);
    return res.status(500).json({ message: 'internal server error' });
  }
}

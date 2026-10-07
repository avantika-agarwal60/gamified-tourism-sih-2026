import QRCode from 'qrcode';
import { PrismaClient } from '@prisma/client';
import crypto from 'crypto';

const prisma = new PrismaClient();

export async function createQuest(req, res) {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ message: 'unauthorized access' });
  }

  const { name, city, qr_code, description, lat, lng, xp } = req.body;
  if (
    typeof name !== 'string' || !name.trim() ||
    typeof city !== 'string' || !city.trim() ||
    typeof qr_code !== 'string' || !qr_code.trim() ||
    typeof description !== 'string' || !description.trim() ||
    typeof lat !== 'number' || !Number.isFinite(lat) || lat < -90 || lat > 90 ||
    typeof lng !== 'number' || !Number.isFinite(lng) || lng < -180 || lng > 180 ||
    !Number.isInteger(xp) || xp < 1
  ) {
    return res.status(400).json({
      message: 'name, city, qr_code, description, valid lat/lng, and positive integer xp are required'
    });
  }

  try {
    const foundCity = await prisma.cities.findUnique({
      where: { name: city.trim() }
    });

    if (!foundCity) {
      return res.status(404).json({ message: 'city not found' });
    }

    const quest = await prisma.quests.create({
      data: {
        id: crypto.randomUUID(),
        city_id: foundCity.id,
        name: name.trim(),
        description: description.trim(),
        lat,
        lng,
        xp,
        qr_code: qr_code.trim(),
        created_by: req.user.id
      }
    });

    return res.status(201).json({ quest });
  } catch (error) {
    if (error.code === 'P2002') {
      return res.status(409).json({ message: 'QR code is already assigned to a quest' });
    }
    console.error('Error creating quest:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
}

export async function createQuestQuestion(req, res) {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ message: 'unauthorized access' });
  }

  const questId = req.params.id;
  const { question, options, correct_option } = req.body;
  if (
    typeof question !== 'string' || !question.trim() ||
    !Array.isArray(options) || options.length < 2 ||
    options.some(option => typeof option !== 'string' || !option.trim()) ||
    typeof correct_option !== 'string' ||
    !options.some(option => option.trim() === correct_option.trim())
  ) {
    return res.status(400).json({
      message: 'question, at least two string options, and a matching correct_option are required'
    });
  }

  try {
    const quest = await prisma.quests.findUnique({
      where: { id: questId },
      select: { id: true }
    });

    if (!quest) {
      return res.status(404).json({ message: 'quest not found' });
    }

    const quizQuestion = await prisma.quiz_questions.create({
      data: {
        id: crypto.randomUUID(),
        quest_id: questId,
        question: question.trim(),
        options: options.map(option => option.trim()),
        correct_option: correct_option.trim()
      }
    });

    return res.status(201).json({ question: quizQuestion });
  } catch (error) {
    console.error('Error creating quest question:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
}

export async function generateQuestQR(req, res) {
  try {
    const questId = req.params.id;

    const quest = await prisma.quests.findUnique({
      where: { id: questId }
    });

    if (!quest) {
      return res.status(404).json({ message: 'quest not found' });
    }

    const qrImage = await QRCode.toBuffer(quest.qr_code, { type: 'png' });
    return res.status(200).type('png').send(qrImage);
  } catch (error) {
    console.error('Error generating QR code:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
}

import express from 'express';
import { authenticateToken } from '../../auth/controller/auth.controller.js';
import { createQuest, createQuestQuestion, generateQuestQR } from '../controllers/qr.controller.js';

const router = express.Router();

router.post('/quest', authenticateToken, createQuest);
router.post('/quest/:id/questions', authenticateToken, createQuestQuestion);
router.get('/quest/:id', generateQuestQR);

export default router;

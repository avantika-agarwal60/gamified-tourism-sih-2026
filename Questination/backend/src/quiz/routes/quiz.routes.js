import { Router } from 'express';
import * as controller from '../controller/quiz.controller.js';
import { authenticateToken } from '../../auth/controller/auth.controller.js';
const quiz_router = Router();
quiz_router.use(authenticateToken);
quiz_router.post('/:questId/start', controller.startQuiz);
quiz_router.post('/:questId/answer', controller.submitAnswer);
quiz_router.get('/:attemptId/finish', controller.finishQuiz);
export default quiz_router;
import { Router } from 'express';
import { authenticateToken } from '../../auth/controller/auth.controller.js';
import { createRating } from '../controller/ratings.controller.js';

const ratingsRouter = Router();
ratingsRouter.use(authenticateToken);
ratingsRouter.post('/', createRating);

export default ratingsRouter;

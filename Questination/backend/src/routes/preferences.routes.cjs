const express = require('express');
const router = express.Router();
const { getCraftCategoriesByCity, savePreferences } = require('../controllers/preferences.controller.cjs');

router.get('/cities/:cityId/craft-categories', getCraftCategoriesByCity);
router.post('/', savePreferences);

module.exports = router;

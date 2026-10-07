const express = require('express');
const router = express.Router();
const { getArtisansByCity } = require('../controllers/artisan.controller.cjs');

router.get('/city/:cityId', getArtisansByCity);

module.exports = router;
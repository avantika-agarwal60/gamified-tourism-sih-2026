const express = require('express');
const router = express.Router();
const { generateCoupon, redeemCoupon } = require('../controllers/coupon.controller.cjs');

router.post('/generate', generateCoupon);
router.post('/redeem', redeemCoupon);

module.exports = router;
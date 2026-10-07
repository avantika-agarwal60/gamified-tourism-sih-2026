const express = require('express');
const router = express.Router();
const {
  getAvatarItems,
  getMyAvatar,
  saveEquippedAvatar,
  purchaseAvatarItem,
} = require('../controllers/avatar.controller.cjs');

router.get('/items', getAvatarItems);
router.get('/me', getMyAvatar);
router.put('/me', saveEquippedAvatar);
router.post('/purchase', purchaseAvatarItem);

module.exports = router;
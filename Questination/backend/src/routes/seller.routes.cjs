const express = require('express');
const multer = require('multer');
const router = express.Router();
const { authenticateToken } = require('../auth/controller/auth.controller.js');
const {
  registerSeller,
  getSellerProfile,
  updateSellerProfile,
  verifySellerCraft,
  getPendingSellers,
  submitUdyamProof,
  getUdyamProofUrl,
  setVerificationStatus, getCities, getCraftCategories 
} = require('../controllers/seller.controller.cjs');

const upload = multer({ storage: multer.memoryStorage() });

router.post('/register', registerSeller);

router.use(authenticateToken);
router.get('/pending', getPendingSellers);
router.get('/meta/cities', getCities);
router.get('/meta/craft-categories', getCraftCategories);

router.get('/:id', getSellerProfile);          // wildcard routes last
router.put('/:id', updateSellerProfile);
router.put('/:id/verify-craft', verifySellerCraft);
router.put('/:id/verification', setVerificationStatus);
router.post('/:id/udyam', upload.single('udyam_proof'), submitUdyamProof);
router.get('/:id/udyam-proof-url', getUdyamProofUrl);

module.exports = router;

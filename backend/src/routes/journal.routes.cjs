const express = require('express');
const multer = require('multer');
const { createJournalEntry, getUserJournal } = require('../controllers/journal.controller.cjs');

const router = express.Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024, files: 4 },
});

router.post('/', upload.array('photos', 4), createJournalEntry);
router.get('/:userId', getUserJournal);

module.exports = router;

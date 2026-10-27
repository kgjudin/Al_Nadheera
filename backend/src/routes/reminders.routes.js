const express = require('express');
const router = express.Router();
const {
  getReminders,
  getReminderById,
  createReminder,
  updateReminder,
  deleteReminder,
} = require('../controllers/reminders.controller');

router.get('/', getReminders);
router.get('/:id', getReminderById);
router.post('/', createReminder);
router.put('/:id', updateReminder);
router.delete('/:id', deleteReminder);

module.exports = router;

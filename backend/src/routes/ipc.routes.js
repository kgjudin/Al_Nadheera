const express = require('express');
const router = express.Router();
const {
  getIpcDocuments,
  getIpcDocumentById,
  createIpcDocument,
  updateIpcDocument,
  deleteIpcDocument,
} = require('../controllers/ipc.controller');

router.get('/', getIpcDocuments);
router.get('/:id', getIpcDocumentById);
router.post('/', createIpcDocument);
router.put('/:id', updateIpcDocument);
router.delete('/:id', deleteIpcDocument);

module.exports = router;

const express = require('express');
const router = express.Router();
const sitesController = require('../controllers/sites.controller');

router.get('/', sitesController.getAllSites);
router.post('/', sitesController.createSite);
router.get('/:id', sitesController.getSiteById);
router.put('/:id', sitesController.updateSite);
router.delete('/:id', sitesController.deleteSite);

const fin = require('../controllers/site_financials.controller');

// Summary
router.get('/:siteId/summary', fin.getSummary);
router.post('/:siteId/summary', fin.createSummary);
router.put('/summary/:id', fin.updateSummary);
router.delete('/summary/:id', fin.deleteSummary);

// Labour
router.get('/:siteId/labour', fin.getLabour);
router.post('/:siteId/labour', fin.createLabour);
router.put('/labour/:id', fin.updateLabour);
router.delete('/labour/:id', fin.deleteLabour);

// Materials
router.get('/:siteId/materials', fin.getMaterials);
router.post('/:siteId/materials', fin.createMaterial);
router.put('/materials/:id', fin.updateMaterial);
router.delete('/materials/:id', fin.deleteMaterial);

// Subcontractors
router.get('/:siteId/subcontractors', fin.getSubcontractors);
router.post('/:siteId/subcontractors', fin.createSubcontractor);
router.put('/subcontractors/:id', fin.updateSubcontractor);
router.delete('/subcontractors/:id', fin.deleteSubcontractor);

// Additional Expenses
router.get('/:siteId/additional-expenses', fin.getAdditionalExpenses);
router.post('/:siteId/additional-expenses', fin.createAdditionalExpense);
router.put('/additional-expenses/:id', fin.updateAdditionalExpense);
router.delete('/additional-expenses/:id', fin.deleteAdditionalExpense);

// Budget
router.get('/:siteId/budget', fin.getBudget);
router.post('/:siteId/budget', fin.createBudget);
router.put('/budget/:id', fin.updateBudget);
router.delete('/budget/:id', fin.deleteBudget);

const tasksController = require('../controllers/tasks.controller');

// Tasks
router.get('/:siteId/tasks', tasksController.getTasksBySite);
router.post('/:siteId/tasks', tasksController.createTask);
router.put('/tasks/:id', tasksController.updateTask);
router.delete('/tasks/:id', tasksController.deleteTask);

module.exports = router;

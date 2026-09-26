const express = require('express');
const router = express.Router();
const employeesController = require('../controllers/employees.controller');

router.get('/', employeesController.getAllEmployees);
router.post('/', employeesController.createEmployee);
router.get('/:id', employeesController.getEmployeeById);
router.put('/:id', employeesController.updateEmployee);
router.delete('/:id', employeesController.deleteEmployee);
router.post('/:id/change-password', employeesController.changePassword);

module.exports = router;

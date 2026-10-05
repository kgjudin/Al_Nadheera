const express = require('express');
const router = express.Router();
const employeesController = require('../controllers/employees.controller');
const rolesController = require('../controllers/roles.controller');

router.get('/', employeesController.getAllEmployees);
router.post('/', employeesController.createEmployee);
router.get('/:id', employeesController.getEmployeeById);
router.put('/:id', employeesController.updateEmployee);
router.put('/:id/custom-permissions', rolesController.updateEmployeeCustomPermissions);
router.delete('/:id', employeesController.deleteEmployee);
router.post('/:id/change-password', employeesController.changePassword);

module.exports = router;


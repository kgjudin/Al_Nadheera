const express = require('express');
const router = express.Router();
const rolesController = require('../controllers/roles.controller');

router.get('/', rolesController.getAllRoles);
router.post('/', rolesController.createRole);
router.get('/user-permissions/:userId', rolesController.getUserEffectivePermissions);
router.get('/:id', rolesController.getRoleById);
router.put('/:id', rolesController.updateRole);
router.delete('/:id', rolesController.deleteRole);

module.exports = router;

const express = require('express');
const router = express.Router();
const productsController = require('../controllers/products.controller');

// Products
router.get('/', productsController.getAllProducts);
router.post('/', productsController.createProduct);

// Product Classes
router.get('/classes', productsController.getAllClasses);
router.post('/classes', productsController.createClass);
router.delete('/classes/:id', productsController.deleteClass);

// Product Sub-Modules
router.get('/submodules', productsController.getAllSubmodules);
router.post('/submodules', productsController.createSubmodule);
router.delete('/submodules/:id', productsController.deleteSubmodule);

// Product Item by ID
router.get('/:id', productsController.getProductById);
router.put('/:id', productsController.updateProduct);
router.delete('/:id', productsController.deleteProduct);

module.exports = router;

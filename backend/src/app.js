const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');

const app = express();

// Middleware
app.use(cors());
app.use(helmet());
app.use(morgan('dev'));
app.use(express.json());

// Basic health check route
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'OK' });
});

// API Routes
app.use('/api/dashboard', require('./routes/dashboard.routes'));
app.use('/api/sites', require('./routes/sites.routes'));
app.use('/api/employees', require('./routes/employees.routes'));
app.use('/api/products', require('./routes/products.routes'));

// Generic error handler
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({
    success: false,
    message: 'Something went wrong!',
  });
});

module.exports = app;

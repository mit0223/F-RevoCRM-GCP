const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version || '1.0.0'
  });
});

// Basic route
app.get('/', (req, res) => {
  res.json({
    message: 'F-RevoCRM is running!',
    environment: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  });
});

app.listen(port, () => {
  console.log(`F-RevoCRM server running on port ${port}`);
});

module.exports = app;

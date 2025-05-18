const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

// Middleware for JSON parsing
app.use(express.json());

// Simple health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', message: 'Amazon Q Command Center API is running' });
});

// Example API endpoint
app.get('/api/info', (req, res) => {
  res.json({
    name: 'Amazon Q Command Center',
    version: '1.0.0',
    timestamp: new Date().toISOString()
  });
});

// New status endpoint
app.get('/api/status', (req, res) => {
  res.json({
    status: 'operational',
    environment: 'production',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
    message: 'This is a new endpoint added via CI/CD pipeline'
  });
});

// Start the server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});

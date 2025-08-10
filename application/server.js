const express = require('express');
const app = express();
const port = 3000;

const nodeName = process.env.NODE_NAME || 'unknown-node';

app.get('/', (req, res) => {
  res.send(`Hello from Kubernetes pod running on node: ${nodeName} - time: ${new Date().toISOString()}`);
});

app.listen(port, () => {
  console.log(`App listening at http://localhost:${port} on node: ${nodeName}`);
});


'use strict';

const { createApp } = require('./app');
const { createProductClient } = require('./productClient');

const PORT = Number(process.env.PORT || 3000);
const PRODUCT_SERVICE_URL = process.env.PRODUCT_SERVICE_URL || 'http://localhost:8000';

const app = createApp({ productClient: createProductClient(PRODUCT_SERVICE_URL) });

const server = app.listen(PORT, () => {
  console.log(`order-service listening on :${PORT} (product-service: ${PRODUCT_SERVICE_URL})`);
});

// Kubernetes gửi SIGTERM khi cập nhật/xoá pod -> đóng kết nối gọn gàng
process.on('SIGTERM', () => server.close(() => process.exit(0)));

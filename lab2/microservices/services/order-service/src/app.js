'use strict';

const express = require('express');
const { version } = require('../package.json');

/**
 * Order service:
 *   GET  /health        kiểm tra sống
 *   GET  /orders        danh sách đơn hàng
 *   GET  /orders/:id    chi tiết đơn hàng
 *   POST /orders        tạo đơn { productId, quantity } – hỏi product-service
 *                       để lấy giá và kiểm tra tồn kho
 */
function createApp({ productClient }) {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '10kb' }));

  const orders = [];

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', service: 'order-service', version, pod: process.env.HOSTNAME || 'local' });
  });

  app.get('/orders', (_req, res) => {
    res.json(orders);
  });

  app.get('/orders/:id', (req, res) => {
    const order = orders.find((o) => o.id === Number(req.params.id));
    if (!order) return res.status(404).json({ error: 'Không tìm thấy đơn hàng' });
    return res.json(order);
  });

  app.post('/orders', async (req, res, next) => {
    try {
      const { productId, quantity } = req.body || {};
      if (!Number.isInteger(productId) || productId <= 0) {
        return res.status(400).json({ error: 'productId phải là số nguyên dương' });
      }
      if (!Number.isInteger(quantity) || quantity <= 0) {
        return res.status(400).json({ error: 'quantity phải là số nguyên dương' });
      }

      const product = await productClient.getProduct(productId);
      if (!product) return res.status(404).json({ error: 'Sản phẩm không tồn tại' });
      if (product.stock < quantity) {
        return res.status(409).json({ error: 'Không đủ hàng trong kho', available: product.stock });
      }

      const order = {
        id: orders.length + 1,
        productId,
        productName: product.name,
        quantity,
        unitPrice: product.price,
        total: product.price * quantity,
        createdAt: new Date().toISOString(),
      };
      orders.push(order);
      return res.status(201).json(order);
    } catch (err) {
      return next(err);
    }
  });

  // eslint-disable-next-line no-unused-vars
  app.use((err, _req, res, _next) => {
    const status = err.status || 500;
    res.status(status).json({ error: status === 500 ? 'Lỗi hệ thống' : err.message });
  });

  return app;
}

module.exports = { createApp };
